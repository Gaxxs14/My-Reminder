using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using MyReminder.API.Data;
using MyReminder.API.Models;

namespace MyReminder.API.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class SyncController : ControllerBase
    {
        private readonly AppDbContext _context;

        public SyncController(AppDbContext context)
        {
            _context = context;
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

        // --- REMINDER SYNC ---
        [HttpPost("reminders")]
        public async Task<IActionResult> SyncReminders([FromBody] List<Reminder> clientReminders)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            foreach (var clientRem in clientReminders)
            {
                clientRem.UserId = userId.Value;
                
                var existing = await _context.Reminders.FirstOrDefaultAsync(r => r.Id == clientRem.Id && r.UserId == userId.Value);
                if (existing == null)
                {
                    _context.Reminders.Add(clientRem);
                }
                else
                {
                    existing.Title = clientRem.Title;
                    existing.Description = clientRem.Description;
                    existing.Category = clientRem.Category;
                    existing.DueDate = clientRem.DueDate;
                    existing.Status = clientRem.Status;
                    existing.CreatedAt = clientRem.CreatedAt;
                }
            }

            await _context.SaveChangesAsync();

            // Return all updated reminders for this user
            var serverReminders = await _context.Reminders
                .Where(r => r.UserId == userId.Value)
                .ToListAsync();

            return Ok(serverReminders);
        }

        // --- RESET DATA ---
        [HttpPost("reset")]
        public async Task<IActionResult> ResetData()
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            var reminders = await _context.Reminders.Where(r => r.UserId == userId.Value).ToListAsync();
            _context.Reminders.RemoveRange(reminders);
            
            await _context.SaveChangesAsync();
            return Ok(new { Message = "Todos tus recordatorios en la nube han sido eliminados." });
        }
    }
}
