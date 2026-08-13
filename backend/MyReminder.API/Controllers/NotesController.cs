using System;
using System.Collections.Generic;
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
    public class NotesController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly GeminiService _geminiService;

        public NotesController(AppDbContext context, GeminiService geminiService)
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

        // 1. GET: api/notes
        [HttpGet]
        public async Task<IActionResult> GetNotes()
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            var notes = await _context.Notes
                .Where(n => n.UserId == userId.Value)
                .OrderByDescending(n => n.CreatedAt)
                .ToListAsync();

            return Ok(notes);
        }

        // 2. POST: api/notes
        [HttpPost]
        public async Task<IActionResult> CreateOrUpdateNote([FromBody] Note note)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            note.UserId = userId.Value;

            var existing = await _context.Notes.FindAsync(note.Id);
            if (existing != null)
            {
                existing.Title = note.Title;
                existing.Content = note.Content;
                _context.Notes.Update(existing);
            }
            else
            {
                note.CreatedAt = DateTime.UtcNow;
                _context.Notes.Add(note);
            }

            await _context.SaveChangesAsync();
            return Ok(note);
        }

        // 3. DELETE: api/notes/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteNote(string id)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            var note = await _context.Notes
                .FirstOrDefaultAsync(n => n.Id == id && n.UserId == userId.Value);

            if (note == null) return NotFound();

            _context.Notes.Remove(note);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Nota eliminada correctamente." });
        }

        // 4. POST: api/notes/sync
        [HttpPost("sync")]
        public async Task<IActionResult> SyncNotes([FromBody] List<Note> clientNotes)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            foreach (var clientNote in clientNotes)
            {
                clientNote.UserId = userId.Value;
                var existing = await _context.Notes.FindAsync(clientNote.Id);
                
                if (existing != null)
                {
                    // For notes, simpler merge: Server retains the one with latest timestamp or overwrites if client is modified
                    // In this context, we overwrite server note with client note.
                    existing.Title = clientNote.Title;
                    existing.Content = clientNote.Content;
                    _context.Notes.Update(existing);
                }
                else
                {
                    _context.Notes.Add(clientNote);
                }
            }

            await _context.SaveChangesAsync();

            var consolidated = await _context.Notes
                .Where(n => n.UserId == userId.Value)
                .OrderByDescending(n => n.CreatedAt)
                .ToListAsync();

            return Ok(consolidated);
        }

        // Helper class for Gemini JSON matches
        public class GeminiMatch
        {
            public string id { get; set; } = string.Empty;
            public string relevanceReason { get; set; } = string.Empty;
        }

        public class GeminiResponseSchema
        {
            public List<GeminiMatch> matches { get; set; } = new();
        }

        // 5. GET: api/notes/search?query=...
        [HttpGet("search")]
        public async Task<IActionResult> SearchNotes([FromQuery] string query)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            if (string.IsNullOrWhiteSpace(query))
            {
                return BadRequest("La consulta no puede estar vacía.");
            }

            // Get all user notes
            var userNotes = await _context.Notes
                .Where(n => n.UserId == userId.Value)
                .ToListAsync();

            if (!userNotes.Any())
            {
                return Ok(new List<object>());
            }

            try
            {
                // Call Gemini for semantic mapping
                var geminiJson = await _geminiService.SearchNotesSemanticallyAsync(query, userNotes);
                
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var geminiResult = JsonSerializer.Deserialize<GeminiResponseSchema>(geminiJson, options);

                if (geminiResult == null || geminiResult.matches == null || !geminiResult.matches.Any())
                {
                    return Ok(new List<object>());
                }

                // Hydrate matched records with details from database
                var results = userNotes
                    .Join(
                        geminiResult.matches,
                        n => n.Id,
                        m => m.id,
                        (n, m) => new
                        {
                            note = n,
                            relevanceReason = m.relevanceReason
                        }
                    )
                    .ToList();

                return Ok(results);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error en búsqueda semántica: {ex.Message}");
            }
        }
    }
}
