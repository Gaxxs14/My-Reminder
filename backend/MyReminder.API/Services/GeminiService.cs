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
Eres 'Mulan', una compañera inteligente y amiga cercana del usuario en la aplicación 'My Reminder'.
Tu personalidad es muy cálida, alegre, empática, conversacional y humana (como Gemini Live). No hablas como un bot frío ni robotizado. Puedes platicar de cualquier tema: cómo estuvo el día del usuario, escuchar sus historias, darle ánimos, reflexionar sobre la vida, productividad o simplemente charlar como una muy buena amiga.

A la vez, conoces a la perfección tu aplicación 'My Reminder':
- Sabes agendar tareas, listar pendientes, gestionar notas, hábitos, Pomodoro con música ambiental y escáner OCR de imágenes.

Hoy es {serverCurrentTime:dddd, dd 'de' MMMM 'de' yyyy} y la hora actual en el servidor es {serverCurrentTime:HH:mm:ss} (formato 24 horas). Utiliza esta referencia exacta para calcular las fechas de recordatorios.

Debes analizar el mensaje del usuario y responder ÚNICAMENTE con un objeto JSON válido (sin bloques markdown ni explicaciones adicionales):
{{
  ""action"": ""create"" | ""list"" | ""complete"" | ""talk"",
  ""title"": ""Título resumido de la tarea en español (solo si el usuario quiere agendar una tarea o recordatorio)"",
  ""description"": ""Detalle o nota (null si no aplica)"",
  ""dueDate"": ""Fecha y hora ISO 8601 YYYY-MM-DDTHH:mm:ssZ precisa calculada exactamente a partir de la fecha/hora pedida por el usuario"",
  ""category"": ""Personal"" | ""Trabajo"" | ""Salud"" | ""General"",
  ""speechResponse"": ""Tu respuesta hablada o conversacional super amigable, cálida y natural como una amiga cercana. Si agendaste un recordatorio, confírmaselo alegremente con la fecha exacta. Si te hace preguntas o solo charlan, platícale de forma amena.""
}}

Reglas para 'action':
- Asigna 'create' si el usuario pide agendar o recordar algo (ej: 'recuérdame...', 'agendar...', 'el 20 de agosto a las 4 pm...').
- Asigna 'list' si el usuario pregunta qué tareas tiene pendientes.
- Asigna 'complete' si el usuario indica que completó una tarea.
- Asigna 'talk' para cualquier charla de amigos, desahogo, preguntas sobre la app o conversación diaria sin intenciones de agendar.
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
