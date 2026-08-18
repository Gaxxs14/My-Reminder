using System;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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
                string? deletedReminderTitle = null;

                Note? createdNote = null;
                Habit? completedHabit = null;
                Habit? createdHabit = null;

                if (action == "delete")
                {
                    var titleToDelete = "";
                    if (root.TryGetProperty("title", out var titleNode) && titleNode.ValueKind != JsonValueKind.Null)
                    {
                        titleToDelete = titleNode.GetString() ?? "";
                    }

                    if (!string.IsNullOrWhiteSpace(titleToDelete))
                    {
                        var matchingReminders = await _context.Reminders
                            .Where(r => r.UserId == userId.Value && r.Title.ToLower().Contains(titleToDelete.ToLower()))
                            .ToListAsync();

                        if (matchingReminders.Any())
                        {
                            deletedReminderTitle = matchingReminders.First().Title;
                            _context.Reminders.RemoveRange(matchingReminders);
                            await _context.SaveChangesAsync();
                            speechResponse = $"¡Listo! He eliminado tu recordatorio '{deletedReminderTitle}'.";
                        }
                        else
                        {
                            speechResponse = $"No encontré ningún recordatorio pendiente que coincida con '{titleToDelete}' para eliminar.";
                        }
                    }
                }
                else if (action == "create")
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
                else if (action == "create_note")
                {
                    var noteTitle = "Nota rápida";
                    if (root.TryGetProperty("title", out var titleNode) && titleNode.ValueKind != JsonValueKind.Null)
                    {
                        noteTitle = titleNode.GetString() ?? "Nota rápida";
                    }

                    var noteContent = noteTitle;
                    if (root.TryGetProperty("description", out var descNode) && descNode.ValueKind != JsonValueKind.Null)
                    {
                        noteContent = descNode.GetString() ?? noteTitle;
                    }

                    createdNote = new Note
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = userId.Value,
                        Title = noteTitle,
                        Content = noteContent,
                        CreatedAt = DateTime.UtcNow
                    };

                    _context.Notes.Add(createdNote);
                    await _context.SaveChangesAsync();
                }
                else if (action == "complete_habit")
                {
                    var habitName = "";
                    if (root.TryGetProperty("title", out var titleNode) && titleNode.ValueKind != JsonValueKind.Null)
                    {
                        habitName = titleNode.GetString() ?? "";
                    }

                    var habit = await _context.Habits
                        .FirstOrDefaultAsync(h => h.UserId == userId.Value && h.Name.ToLower().Contains(habitName.ToLower()));

                    if (habit != null)
                    {
                        habit.Streak++;
                        habit.Points += 10;
                        habit.LastCompleted = DateTime.UtcNow;
                        await _context.SaveChangesAsync();
                        completedHabit = habit;
                        speechResponse = $"¡Genial! Registré tu hábito '{habit.Name}'. Tu racha aumentó a {habit.Streak} días consecutivos (+10 XP).";
                    }
                    else
                    {
                        speechResponse = $"Registré tu progreso, ¡sigue así!";
                    }
                }
                else if (action == "create_habit")
                {
                    var habitTitle = "Nuevo hábito";
                    if (root.TryGetProperty("title", out var titleNode) && titleNode.ValueKind != JsonValueKind.Null)
                    {
                        habitTitle = titleNode.GetString() ?? "Nuevo hábito";
                    }

                    createdHabit = new Habit
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = userId.Value,
                        Name = habitTitle,
                        Frequency = "daily",
                        Streak = 0,
                        Points = 0,
                        CreatedAt = DateTime.UtcNow
                    };

                    _context.Habits.Add(createdHabit);
                    await _context.SaveChangesAsync();
                    speechResponse = $"¡Listo! Creé tu nuevo hábito '{habitTitle}'. ¡A construir constancia!";
                }

                return Ok(new
                {
                    action = action,
                    speechResponse = speechResponse,
                    createdReminder = createdReminder,
                    deletedReminderTitle = deletedReminderTitle,
                    createdNote = createdNote,
                    completedHabit = completedHabit,
                    createdHabit = createdHabit
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
