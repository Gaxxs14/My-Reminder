using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

namespace MyReminder.API.Services
{
    public class GeminiService
    {
        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;

        public GeminiService(HttpClient httpClient, IConfiguration configuration)
        {
            _httpClient = httpClient;
            _configuration = configuration;
        }

        public async Task<string> ProcessVoiceTextAsync(string voiceText, DateTime serverCurrentTime)
        {
            var apiKey = _configuration["Gemini:ApiKey"] ?? "";
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                throw new InvalidOperationException("La clave API de Gemini no está configurada. Agrégala en appsettings.json o como variable de entorno.");
            }

            var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={apiKey}";

            var systemInstruction = $@"
Eres el Asistente Virtual Inteligente de la aplicación 'My-Reminder'. Tu trabajo es ayudar al usuario a gestionar su agenda de compromisos y recordatorios de manera amigable.
Hoy es {serverCurrentTime:dddd, dd 'de' MMMM 'de' yyyy} y la hora actual en el servidor es {serverCurrentTime:HH:mm:ss} (formato 24 horas). Utiliza esta fecha y hora de referencia para calcular cualquier fecha relativa mencionada por el usuario (ej: 'mañana', 'en 2 horas', 'el lunes a las 3 pm', 'esta tarde').

Debes analizar el mensaje del usuario y responder ÚNICAMENTE con un objeto JSON válido. No agregues texto explicativo ni bloques de código markdown. El JSON debe tener exactamente la siguiente estructura:
{{
  ""action"": ""create"" | ""list"" | ""complete"" | ""talk"",
  ""title"": ""Título resumido de la tarea en español (solo si action es 'create')"",
  ""description"": ""Detalle o nota de la tarea (si aplica, si no null)"",
  ""dueDate"": ""Fecha y hora de vencimiento calculada en formato ISO 8601 YYYY-MM-DDTHH:mm:ssZ (solo si action es 'create')"",
  ""category"": ""Personal"" | ""Trabajo"" | ""Salud"" | ""General"",
  ""speechResponse"": ""Respuesta corta, clara y muy amigable en español para leérsela al usuario por voz confirmando la acción (ej: '¡Entendido! He agendado comprar pan para mañana a las 5:00 de la tarde.')""
}}

Instrucciones para 'action':
- 'create': Si el usuario expresa claramente la intención de programar, agendar o recordar algo a una hora o momento específico.
- 'list': Si el usuario pregunta qué tareas tiene (ej: '¿qué tengo que hacer hoy?').
- 'complete': Si el usuario dice que ya hizo algo (ej: 'marca como completada la tarea de comprar leche').
- 'talk': Si el usuario solo está conversando o te hace una pregunta general que no requiere una acción de agenda.
";

            var payload = new
            {
                contents = new[]
                {
                    new
                    {
                        parts = new[]
                        {
                            new { text = voiceText }
                        }
                    }
                },
                systemInstruction = new
                {
                    parts = new[]
                    {
                        new { text = systemInstruction }
                    }
                },
                generationConfig = new
                {
                    responseMimeType = "application/json"
                }
            };

            var jsonPayload = JsonSerializer.Serialize(payload);
            var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content);
            response.EnsureSuccessStatusCode();

            var responseBody = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(responseBody);
            
            // Extract the generated text from Gemini's response structure
            var text = doc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString();

            return text ?? "{}";
        }
    }
}
