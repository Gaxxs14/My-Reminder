using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using MyReminder.API.Data;

// Fix inotify crash on Render free tier:
// Render's kernel limits inotify instances to 128. ASP.NET Core's default
// CreateBuilder watches config files with FileSystemWatcher which consumes
// inotify instances. We build configuration manually with reloadOnChange=false.
Environment.SetEnvironmentVariable("DOTNET_USE_POLLING_FILE_WATCHER", "1");

var builder = WebApplication.CreateBuilder(args);

// Disable reload-on-change on every JSON config source that was auto-added
foreach (var source in builder.Configuration.Sources
    .OfType<Microsoft.Extensions.Configuration.FileConfigurationSource>()
    .ToList())
{
    source.ReloadOnChange = false;
}


// Add Database Context with connection string parser for Render DATABASE_URL format
var rawConnectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? builder.Configuration["DATABASE_URL"]
    ?? builder.Configuration["DefaultConnection"]
    ?? "Host=localhost;Database=my_reminder;Username=postgres;Password=postgres";

if (!string.IsNullOrEmpty(rawConnectionString) && (rawConnectionString.StartsWith("postgres://") || rawConnectionString.StartsWith("postgresql://")))
{
    try
    {
        var uri = new Uri(rawConnectionString);
        var userInfo = uri.UserInfo.Split(':');
        var user = userInfo[0];
        var password = userInfo.Length > 1 ? userInfo[1] : "";
        var port = uri.Port > 0 ? uri.Port : 5432;
        var database = uri.AbsolutePath.TrimStart('/');
        rawConnectionString = $"Host={uri.Host};Port={port};Database={database};Username={user};Password={password};SSL Mode=Require;Trust Server Certificate=true;";
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error converting DATABASE_URL format: {ex.Message}");
    }
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(rawConnectionString));

// Add TokenService, GeminiService, HttpClient, Controllers and Swagger/OpenAPI support
builder.Services.AddHttpClient();

// Named HttpClient for KeepAliveService self-ping (points to this same Render instance)
builder.Services.AddHttpClient("KeepAlive", client =>
{
    client.BaseAddress = new Uri("https://my-reminder-zu31.onrender.com");
    client.Timeout = TimeSpan.FromSeconds(20);
});

builder.Services.AddScoped<MyReminder.API.Services.TokenService>();
builder.Services.AddScoped<MyReminder.API.Services.GeminiService>();
builder.Services.AddControllers();

// Register KeepAlive background service to prevent Render free tier spin-down
builder.Services.AddHostedService<MyReminder.API.Services.KeepAliveService>();

// Add CORS Policy
var allowedCorsOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? new[] { "http://localhost:5173", "http://localhost:8080" };

builder.Services.AddCors(options =>
{
    options.AddPolicy("AppCors", policy =>
    {
        policy.WithOrigins(allowedCorsOrigins)
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Configure JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey.Length < 32)
{
    jwtKey = "MyReminder_SuperSecretKey2026_UltraSecureJwtTokenAuthKey_987654321!";
}

var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "MyReminderAPI";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "MyReminderClients";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtIssuer,
        ValidAudience = jwtAudience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddOpenApi();

var app = builder.Build();

// Apply migrations & ensure RefreshTokens table exists at startup automatically
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        db.Database.Migrate();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error running migrations: {ex.Message}");
    }

    try
    {
        db.Database.ExecuteSqlRaw(@"
            CREATE TABLE IF NOT EXISTS ""RefreshTokens"" (
                ""Id"" text NOT NULL CONSTRAINT ""PK_RefreshTokens"" PRIMARY KEY,
                ""TokenHash"" text NOT NULL,
                ""UserId"" uuid NOT NULL CONSTRAINT ""FK_RefreshTokens_Users_UserId"" REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
                ""ExpiresAt"" timestamp with time zone NOT NULL,
                ""CreatedAt"" timestamp with time zone NOT NULL,
                ""RevokedAt"" timestamp with time zone NULL,
                ""ReplacedByTokenHash"" text NULL
            );
            CREATE UNIQUE INDEX IF NOT EXISTS ""IX_RefreshTokens_TokenHash"" ON ""RefreshTokens"" (""TokenHash"");
            CREATE INDEX IF NOT EXISTS ""IX_RefreshTokens_UserId"" ON ""RefreshTokens"" (""UserId"");
            CREATE INDEX IF NOT EXISTS ""IX_RefreshTokens_ExpiresAt"" ON ""RefreshTokens"" (""ExpiresAt"");
        ");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error ensuring RefreshTokens table: {ex.Message}");
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors("AppCors");

// Note: HTTPS redirection is handled by Render's load balancer, not the container
// app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Health check endpoint - used by UptimeRobot/cron-job.org to keep Render alive
app.MapGet("/health", () => Results.Ok(new { status = "ok", timestamp = DateTime.UtcNow }));

app.Run();
