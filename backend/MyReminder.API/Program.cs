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


// Add Database Context
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Host=localhost;Database=my_reminder;Username=postgres;Password=postgres"; // Default fallback
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

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

// Add CORS Policy for mobile/local testing
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Configure JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"] ?? "SUPER_SECRET_KEY_FOR_REMINDER_PROJECT_2026_CHANGE_THIS_IN_PROD";
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

// Apply migrations at startup automatically
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        db.Database.Migrate();
    }
    catch (Exception ex)
    {
        // Log migration error (e.g. if DB is not available yet during testing)
        Console.WriteLine($"Error running migrations: {ex.Message}");
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors("AllowAll");

// Note: HTTPS redirection is handled by Render's load balancer, not the container
// app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Health check endpoint - used by UptimeRobot/cron-job.org to keep Render alive
app.MapGet("/health", () => Results.Ok(new { status = "ok", timestamp = DateTime.UtcNow }));

app.Run();
