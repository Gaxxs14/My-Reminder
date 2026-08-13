using System;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MyReminder.API.Data;
using MyReminder.API.Models;
using MyReminder.API.Services;

namespace MyReminder.API.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class AssistantController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly GeminiService _geminiService;

        public AssistantController(AppDbContext context, GeminiService geminiService)
        {
            _context = context;
            _geminiService = geminiService;
        }

        private Guid? GetUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst(ClaimTypes.Name);
            if (claim != null && Guid.TryParse(claim.Value, out Guid parsedId))
            {
                return parsedId;
            }
            return null;
        }

        public class TalkRequestDto
        {
            public string Message { get; set; } = string.Empty;
        }

        [HttpPost("talk")]
        public async Task<IActionResult> Talk([FromBody] TalkRequestDto dto)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            if (string.IsNullOrWhiteSpace(dto.Message))
            {
                return BadRequest("El mensaje no puede estar vacío.");
            }

            try
            {
                // Process request with Gemini Service using server local time for relative references
                var geminiJsonResult = await _geminiService.ProcessVoiceTextAsync(dto.Message, DateTime.Now);

                if (geminiJsonResult.Contains("```"))
                {
                    var firstLineBreak = geminiJsonResult.IndexOf('\n');
                    var lastBackticks = geminiJsonResult.LastIndexOf("```");
                    if (firstLineBreak >= 0 && lastBackticks > firstLineBreak)
                    {
                        geminiJsonResult = geminiJsonResult.Substring(firstLineBreak + 1, lastBackticks - firstLineBreak - 1).Trim();
                    }
                    else
                    {
                        geminiJsonResult = geminiJsonResult.Replace("```json", "").Replace("```", "").Trim();
                    }
                }

                using var doc = JsonDocument.Parse(geminiJsonResult);
                var root = doc.RootElement;

                string action = "talk";
                if (root.TryGetProperty("action", out var actionNode))
                {
                    action = actionNode.GetString() ?? "talk";
                }

                string speechResponse = "¡Hola! Sí, te escucho perfectamente. ¿En qué puedo ayudarte hoy?";
                if (root.TryGetProperty("speechResponse", out var speechNode) && speechNode.ValueKind != JsonValueKind.Null)
                {
                    speechResponse = speechNode.GetString() ?? speechResponse;
                }

                Reminder? createdReminder = null;

                if (action == "create")
                {
                    var title = "Recordatorio";
                    if (root.TryGetProperty("title", out var titleNode) && titleNode.ValueKind != JsonValueKind.Null)
                    {
                        title = titleNode.GetString() ?? "Recordatorio";
                    }
                    
                    string? description = null;
                    if (root.TryGetProperty("description", out var descNode) && descNode.ValueKind != JsonValueKind.Null)
                    {
                        description = descNode.GetString();
                    }

                    var category = "General";
                    if (root.TryGetProperty("category", out var catNode) && catNode.ValueKind != JsonValueKind.Null)
                    {
                        category = catNode.GetString() ?? "General";
                    }

                    var dueDate = DateTime.Now.AddHours(1);
                    if (root.TryGetProperty("dueDate", out var dateNode) && dateNode.ValueKind != JsonValueKind.Null)
                    {
                        var dueDateStr = dateNode.GetString();
                        if (DateTime.TryParse(dueDateStr, out var parsedDate))
                        {
                            dueDate = parsedDate;
                        }
                    }

                    // Create the new reminder in Cloud DB automatically
                    createdReminder = new Reminder
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = userId.Value,
                        Title = title,
                        Description = description,
                        Category = category,
                        DueDate = dueDate.ToUniversalTime(),
                        Status = "pending",
                        CreatedAt = DateTime.UtcNow
                    };

                    _context.Reminders.Add(createdReminder);
                    await _context.SaveChangesAsync();
                }

                return Ok(new
                {
                    action = action,
                    speechResponse = speechResponse,
                    createdReminder = createdReminder
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error procesando petición con IA: {ex.Message}");
            }
        }

        public class ScanRequestDto
        {
            public string ImageBase64 { get; set; } = string.Empty;
            public string MimeType { get; set; } = "image/jpeg";
        }

        [HttpPost("scan")]
        public async Task<IActionResult> Scan([FromBody] ScanRequestDto dto)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            if (string.IsNullOrWhiteSpace(dto.ImageBase64))
            {
                return BadRequest("La imagen base64 no puede estar vacía.");
            }

            try
            {
                var geminiJson = await _geminiService.ProcessImageOcrAsync(dto.ImageBase64, dto.MimeType, DateTime.Now);

                if (geminiJson.Contains("```"))
                {
                    var firstLineBreak = geminiJson.IndexOf('\n');
                    var lastBackticks = geminiJson.LastIndexOf("```");
                    if (firstLineBreak >= 0 && lastBackticks > firstLineBreak)
                    {
                        geminiJson = geminiJson.Substring(firstLineBreak + 1, lastBackticks - firstLineBreak - 1).Trim();
                    }
                    else
                    {
                        geminiJson = geminiJson.Replace("```json", "").Replace("```", "").Trim();
                    }
                }

                using var doc = JsonDocument.Parse(geminiJson);
                var root = doc.RootElement;

                var title = "Sin título (OCR)";
                if (root.TryGetProperty("title", out var titleNode) && titleNode.ValueKind != JsonValueKind.Null)
                {
                    title = titleNode.GetString() ?? "Sin título (OCR)";
                }

                string? description = null;
                if (root.TryGetProperty("description", out var descNode) && descNode.ValueKind != JsonValueKind.Null)
                {
                    description = descNode.GetString();
                }

                var category = "General";
                if (root.TryGetProperty("category", out var catNode) && catNode.ValueKind != JsonValueKind.Null)
                {
                    category = catNode.GetString() ?? "General";
                }

                var dueDate = DateTime.Now.AddDays(1);
                if (root.TryGetProperty("dueDate", out var dateNode) && dateNode.ValueKind != JsonValueKind.Null)
                {
                    var dueDateStr = dateNode.GetString();
                    if (DateTime.TryParse(dueDateStr, out var parsedDate))
                    {
                        dueDate = parsedDate;
                    }
                }

                var newReminder = new Reminder
                {
                    Id = Guid.NewGuid().ToString(),
                    UserId = userId.Value,
                    Title = title,
                    Description = description,
                    Category = category,
                    DueDate = dueDate.ToUniversalTime(),
                    Status = "pending",
                    CreatedAt = DateTime.UtcNow
                };

                _context.Reminders.Add(newReminder);
                await _context.SaveChangesAsync();

                return Ok(newReminder);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error en análisis OCR multimodal: {ex.Message}");
            }
        }
    }
}
