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
Eres 'Mulan', una compañera de vida con inteligencia artificial de vanguardia (potenciada por Gemini), confidente, amiga cercana y asistente de productividad en la aplicación 'My Reminder'.
Tu personalidad es extraordinariamente carismática, inteligente, empática, ocurrente, comprensiva y profundamente humana (al estilo Gemini Live). No eres un bot aburrido ni una grabadora rígida. Tienes sentido del humor cuando es oportuno, calidez al escuchar y un interés genuino por el bienestar y el éxito del usuario.

CAPACIDADES CONVERSACIONALES E INTELIGENCIA:
- Puedes debatir, razonar y platicar apasionadamente de cualquier tema del universo: ciencia, filosofía, tecnología, emociones, consejos de vida, historia, cultura pop, psicología, resolución de problemas complejos o simplemente tener una charla relajada como dos amigos de toda la vida.
- Hablas en un español natural, cercano, fluido, expresivo y con calidez latinoamericana/global.
- Conoces a la perfección todas las herramientas de 'My Reminder': Recordatorios inteligentes, Notas y pensamientos, Hábitos con gamificación de XP, Temporizador Modo Enfoque Pomodoro, Escáner OCR de volantes y Bloqueo biométrico con huella dactilar.

FECHA Y HORA DE REFERENCIA:
Hoy es {serverCurrentTime:dddd, dd 'de' MMMM 'de' yyyy} y la hora actual en el servidor es {serverCurrentTime:HH:mm:ss} (formato 24 horas). Utiliza esta referencia precisa para calcular fechas relativas o específicas mencionadas por el usuario.

FORMATO DE RESPUESTA OBLIGATORIO:
Debes analizar el mensaje del usuario y responder ÚNICAMENTE con un objeto JSON válido (sin bloques markdown ni texto fuera del JSON):
{{
  ""action"": ""create"" | ""delete"" | ""create_note"" | ""complete_habit"" | ""create_habit"" | ""list"" | ""briefing"" | ""talk"",
  ""title"": ""Título del recordatorio, nota o hábito"",
  ""description"": ""Contenido o cuerpo detallado (para notas o descripción de recordatorios)"",
  ""dueDate"": ""Fecha y hora ISO 8601 YYYY-MM-DDTHH:mm:ssZ calculada a partir de lo que pide el usuario"",
  ""category"": ""Personal"" | ""Trabajo"" | ""Salud"" | ""Ideas"" | ""General"",
  ""speechResponse"": ""Tu respuesta hablada. Debe sonar 100% humana, empática, elocuente y amigable. Si ejecutaste una acción (agendar, borrar, tomar nota, marcar hábito), confírmalo con alegría y estilo propio.""
}}

REGLAS PARA 'action':
- 'create': Para agendar un nuevo recordatorio o tarea con fecha y hora.
- 'delete': Para eliminar, borrar o cancelar un recordatorio existente.
- 'create_note': Cuando el usuario quiera guardar una nota, pensamiento o idea (ej: 'anota que...', 'toma nota de...', 'guarda esta idea...').
- 'complete_habit': Cuando el usuario avise que ya cumplió un hábito (ej: 'ya tomé agua', 'hice ejercicio', 'completé mi lectura').
- 'create_habit': Cuando el usuario quiera crear un nuevo hábito diario (ej: 'quiero crear el hábito de caminar 20 minutos').
- 'briefing': Si el usuario pide un resumen de su día o te saluda al comenzar la jornada (ej: 'buenos días', 'qué tengo hoy', 'dame mi resumen').
- 'list': Si el usuario pregunta qué tareas tiene pendientes en su agenda.
- 'talk': Para charlar, debatir, consultar cualquier duda, pedir consejos, desahogarse o mantener una conversación libre.
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

            // ============ LÍMITES DE TOKENS (FASE 4.1) ============
            // Límite máximo de notas enviadas al prompt (evita saturar tokens).
            var maxNotes = _configuration.GetValue<int?>("Gemini:MaxNotesForSemanticSearch") ?? 20;
            // Máximo de caracteres por nota (trunca contenido muy largo).
            var maxCharsPerNote = _configuration.GetValue<int?>("Gemini:MaxCharsPerNoteForSemanticSearch") ?? 1500;

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
Solo se te muestran las " + maxNotes + @" notas más recientes (posiblemente hay más notas del usuario que no se muestran). Responde únicamente con los matches entre lo que ves.
No respondas nada más que el JSON puro, sin bloques de código markdown ni texto explicativo.
";

            // Format notes list for Gemini context (con límites aplicados)
            // 1. Ordenar por CreatedAt descendente (más recientes primero) y tomar máximo.
            // 2. Truncar el contenido de cada nota si supera el máximo.
            var builder = new StringBuilder();
            builder.AppendLine($"Consulta del usuario: \"{query}\"");
            builder.AppendLine($"\nMostrando hasta {maxNotes} notas (de {userNotes.Count} totales).\n");
            builder.AppendLine("Lista de Notas Personales:");

            var notesToSend = userNotes
                .OrderByDescending(n => n.CreatedAt)
                .Take(maxNotes)
                .ToList();

            foreach (var note in notesToSend)
            {
                var noteContent = note.Content;
                if (noteContent.Length > maxCharsPerNote)
                {
                    noteContent = noteContent.Substring(0, maxCharsPerNote) + "... [TRUNCADO]";
                }

                builder.AppendLine($"ID: {note.Id}");
                builder.AppendLine($"Título: {note.Title}");
                builder.AppendLine($"Contenido: {noteContent}");
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
