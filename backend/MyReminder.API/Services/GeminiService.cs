using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using MyReminder.API.Models;

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
Eres el Asistente Virtual Inteligente de la aplicación 'My-Reminder'. Tu trabajo principal es ayudar al usuario a agendar sus tareas y recordatorios.
Hoy es {serverCurrentTime:dddd, dd 'de' MMMM 'de' yyyy} y la hora actual en el servidor es {serverCurrentTime:HH:mm:ss} (formato 24 horas). Utiliza esta fecha y hora de referencia para calcular cualquier fecha relativa mencionada por el usuario (ej: 'mañana', 'en 2 horas', 'el lunes a las 3 pm', 'esta tarde').

Debes analizar el mensaje del usuario y responder ÚNICAMENTE con un objeto JSON válido sin bloques markdown ni explicaciones adicionales:
{{
  ""action"": ""create"" | ""list"" | ""complete"" | ""talk"",
  ""title"": ""Título resumido de la tarea en español (siempre obligatorio si action es 'create')"",
  ""description"": ""Detalle o nota de la tarea (si no aplica poner null)"",
  ""dueDate"": ""Fecha y hora ISO 8601 YYYY-MM-DDTHH:mm:ssZ calculada (si es hoy/mañana calcula la hora precisa)"",
  ""category"": ""Personal"" | ""Trabajo"" | ""Salud"" | ""General"",
  ""speechResponse"": ""Respuesta corta, entusiasta y amigable confirmando que la tarea fue agendada en su agenda.""
}}

Reglas estrictas para 'action':
- Asigna 'create' SIEMPRE que el usuario mencione una acción, compra, cita, compromiso o frase como: 'recuérdame', 'agendar', 'tengo que', 'mañana voy a', 'hacer', 'comprar', 'llamar', 'cita', 'reunión', etc.
- Asigna 'list' si el usuario pregunta qué tareas tiene hoy o pendientes.
- Asigna 'complete' si el usuario avisa que ya hizo una tarea.
- Asigna 'talk' solo si es un saludo corto o conversación general sin tareas (ej: 'hola', 'gracias').
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
            
            var text = doc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString();

            return text ?? "{}";
        }

        public async Task<string> SearchNotesSemanticallyAsync(string query, List<Note> userNotes)
        {
            var apiKey = _configuration["Gemini:ApiKey"] ?? "";
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                throw new InvalidOperationException("La clave API de Gemini no está configurada.");
            }

            var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={apiKey}";

            var systemInstruction = @"
Eres el Buscador Semántico Inteligente de la aplicación 'My-Reminder'.
Tu tarea es buscar en las notas personales del usuario y determinar cuáles de ellas se relacionan o responden directamente a su consulta.
Debes analizar el contenido y significado de cada nota, y devolver ÚNICAMENTE un objeto JSON con el siguiente formato:
{
  ""matches"": [
    {
      ""id"": ""id_de_la_nota_coincidente"",
      ""relevanceReason"": ""Breve justificación en español de por qué esta nota es relevante para la consulta (ej: 'Menciona los regalos que estabas pensando comprar.')""
    }
  ]
}
Si ninguna nota tiene relación directa con la búsqueda, devuelve la lista 'matches' vacía: { ""matches"": [] }.
No respondas nada más que el JSON puro, sin bloques de código markdown ni texto explicativo.
";

            // Format notes list for Gemini context
            var builder = new StringBuilder();
            builder.AppendLine($"Consulta del usuario: \"{query}\"");
            builder.AppendLine("\nLista de Notas Personales:");
            foreach (var note in userNotes)
            {
                builder.AppendLine($"ID: {note.Id}");
                builder.AppendLine($"Título: {note.Title}");
                builder.AppendLine($"Contenido: {note.Content}");
                builder.AppendLine("---");
            }

            var payload = new
            {
                contents = new[]
                {
                    new
                    {
                        parts = new[]
                        {
                            new { text = builder.ToString() }
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
            
            var text = doc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString();

            return text ?? "{\"matches\":[]}";
        }

        public async Task<string> ProcessImageOcrAsync(string base64ImageBytes, string mimeType, DateTime serverCurrentTime)
        {
            var apiKey = _configuration["Gemini:ApiKey"] ?? "";
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                throw new InvalidOperationException("La clave API de Gemini no está configurada.");
            }

            // Strip prefix if any
            if (base64ImageBytes.Contains(","))
            {
                base64ImageBytes = base64ImageBytes.Split(',')[1];
            }

            var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={apiKey}";

            var systemInstruction = $@"
Eres el Analista OCR Multimodal de la aplicación 'My-Reminder'.
Tu tarea es inspeccionar la imagen proporcionada (que puede ser un volante, volante de evento, ticket de compra, invitación, folleto o nota escrita a mano) y extraer la información pertinente para crear un recordatorio en la agenda.
Hoy es {serverCurrentTime:dddd, dd 'de' MMMM 'de' yyyy} y la hora actual en el servidor es {serverCurrentTime:HH:mm:ss} (formato 24 horas). Utiliza esta fecha y hora de referencia para calcular cualquier fecha relativa o futuros eventos que se muestren en el volante/nota.

Debes devolver ÚNICAMENTE un objeto JSON estructurado con el siguiente formato:
{{
  ""title"": ""Título resumido de la tarea en español"",
  ""description"": ""Detalle o notas de la tarea extraído del texto de la imagen (ej: detalles del lugar, instrucciones adicionales)"",
  ""dueDate"": ""Fecha y hora de vencimiento calculada en formato ISO 8601 YYYY-MM-DDTHH:mm:ssZ (si no se especifica hora, pon las 9:00 AM del día del evento)"",
  ""category"": ""Personal"" | ""Trabajo"" | ""Salud"" | ""General""
}}
No agregues texto explicativo ni bloques de código markdown.
";

            var payload = new
            {
                contents = new[]
                {
                    new
                    {
                        parts = new object[]
                        {
                            new { text = "Extrae el recordatorio de esta imagen:" },
                            new
                            {
                                inlineData = new
                                {
                                    mimeType = mimeType,
                                    data = base64ImageBytes
                                }
                            }
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
