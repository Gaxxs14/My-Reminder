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

// Add CORS Policy - Restringida a orígenes conocidos.
// Nota: Las apps móviles nativas (Android/iOS) no envían cabecera Origin y no se
// ven afectadas por CORS. Esta política aplica principalmente al frontend web (Flutter Web).
// En producción, configura los orígenes con variables de entorno: Cors__AllowedOrigins__0, __1, ...
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
// SEGURIDAD: No se permite fallback. La clave JWT debe estar configurada
// en variables de entorno (Render) o en appsettings.json.
var jwtKey = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException(
        "Jwt:Key no está configurada. Configúrala en variables de entorno de Render o en appsettings.json. " +
        "La clave debe tener al menos 32 caracteres (256 bits) para HMAC-SHA256.");

if (jwtKey.Length < 32)
{
    throw new InvalidOperationException(
        "Jwt:Key demasiado corta. Debe tener al menos 32 caracteres (256 bits) para HMAC-SHA256.");
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

app.UseCors("AppCors");

// Note: HTTPS redirection is handled by Render's load balancer, not the container
// app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Health check endpoint - used by UptimeRobot/cron-job.org to keep Render alive
app.MapGet("/health", () => Results.Ok(new { status = "ok", timestamp = DateTime.UtcNow }));

app.Run();
