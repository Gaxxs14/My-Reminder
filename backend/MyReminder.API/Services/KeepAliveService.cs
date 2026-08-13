namespace MyReminder.API.Services
{
    /// <summary>
    /// Background service that pings the /health endpoint every 10 minutes
    /// to prevent Render's free tier from spinning down the instance.
    /// </summary>
    public class KeepAliveService : BackgroundService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<KeepAliveService> _logger;

        // Ping every 10 minutes — Render spins down after 15 min of inactivity
        private static readonly TimeSpan PingInterval = TimeSpan.FromMinutes(10);

        public KeepAliveService(
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            ILogger<KeepAliveService> logger)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Only run in Production (Render). Locally we don't need this.
            var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
            if (environment != "Production")
            {
                _logger.LogInformation("KeepAliveService: skipping in {Env} environment.", environment);
                return;
            }

            _logger.LogInformation("KeepAliveService started. Pinging /health every {Interval} minutes.", PingInterval.TotalMinutes);

            // Wait a bit for the app to fully start before first ping
            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var client = _httpClientFactory.CreateClient("KeepAlive");
                    var response = await client.GetAsync("/health", stoppingToken);

                    _logger.LogInformation(
                        "KeepAlive ping sent → HTTP {StatusCode} at {Time}",
                        (int)response.StatusCode,
                        DateTime.UtcNow.ToString("HH:mm:ss UTC"));
                }
                catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
                {
                    _logger.LogWarning("KeepAlive ping failed: {Error}", ex.Message);
                }

                await Task.Delay(PingInterval, stoppingToken);
            }
        }
    }
}
