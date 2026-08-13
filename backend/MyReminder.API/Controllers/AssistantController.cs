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

                using var doc = JsonDocument.Parse(geminiJsonResult);
                var root = doc.RootElement;

                var action = root.GetProperty("action").GetString();
                var speechResponse = root.GetProperty("speechResponse").GetString() ?? "Entendido.";

                Reminder? createdReminder = null;

                if (action == "create")
                {
                    var title = root.GetProperty("title").GetString() ?? "Sin título";
                    
                    string? description = null;
                    if (root.TryGetProperty("description", out var descNode) && descNode.ValueKind != JsonValueKind.Null)
                    {
                        description = descNode.GetString();
                    }

                    var category = "General";
                    if (root.TryGetProperty("category", out var catNode))
                    {
                        category = catNode.GetString() ?? "General";
                    }

                    var dueDateStr = root.GetProperty("dueDate").GetString();
                    var dueDate = DateTime.TryParse(dueDateStr, out var parsedDate) ? parsedDate : DateTime.Now.AddHours(1);

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

                using var doc = JsonDocument.Parse(geminiJson);
                var root = doc.RootElement;

                var title = root.GetProperty("title").GetString() ?? "Sin título (OCR)";

                string? description = null;
                if (root.TryGetProperty("description", out var descNode) && descNode.ValueKind != JsonValueKind.Null)
                {
                    description = descNode.GetString();
                }

                var category = "General";
                if (root.TryGetProperty("category", out var catNode))
                {
                    category = catNode.GetString() ?? "General";
                }

                var dueDateStr = root.GetProperty("dueDate").GetString();
                var dueDate = DateTime.TryParse(dueDateStr, out var parsedDate) ? parsedDate : DateTime.Now.AddDays(1);

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
