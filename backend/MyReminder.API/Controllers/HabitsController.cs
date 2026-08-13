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
    public class HabitsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public HabitsController(AppDbContext context)
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

        // 1. GET: api/habits
        [HttpGet]
        public async Task<IActionResult> GetHabits()
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            var habits = await _context.Habits
                .Where(h => h.UserId == userId.Value)
                .OrderBy(h => h.CreatedAt)
                .ToListAsync();

            return Ok(habits);
        }

        // 2. POST: api/habits
        [HttpPost]
        public async Task<IActionResult> CreateHabit([FromBody] Habit habit)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            habit.UserId = userId.Value;
            
            // Check if already exists
            var existing = await _context.Habits.FindAsync(habit.Id);
            if (existing != null)
            {
                existing.Name = habit.Name;
                existing.Frequency = habit.Frequency;
                _context.Habits.Update(existing);
            }
            else
            {
                habit.CreatedAt = DateTime.UtcNow;
                _context.Habits.Add(habit);
            }

            await _context.SaveChangesAsync();
            return Ok(habit);
        }

        // 3. POST: api/habits/{id}/complete
        [HttpPost("{id}/complete")]
        public async Task<IActionResult> CompleteHabit(string id)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            var habit = await _context.Habits
                .FirstOrDefaultAsync(h => h.Id == id && h.UserId == userId.Value);

            if (habit == null) return NotFound("Hábito no encontrado.");

            var utcNow = DateTime.UtcNow;
            var todayUtcDate = utcNow.Date;

            if (habit.LastCompleted.HasValue)
            {
                var lastCompletedDate = habit.LastCompleted.Value.Date;
                var daysDifference = (todayUtcDate - lastCompletedDate).TotalDays;

                if (daysDifference < 1)
                {
                    // Already completed today, ignore or return existing state
                    return Ok(new { habit = habit, pointsEarned = 0, message = "Ya completaste este hábito hoy." });
                }
                else if (daysDifference == 1)
                {
                    // Consecutive day completion, increment streak
                    habit.Streak += 1;
                }
                else
                {
                    // Broken streak, reset to 1
                    habit.Streak = 1;
                }
            }
            else
            {
                // First completion
                habit.Streak = 1;
            }

            habit.LastCompleted = utcNow;
            
            // 10 XP points standard, plus 5 points streak bonus every 5 consecutive days
            int pointsEarned = 10;
            if (habit.Streak % 5 == 0)
            {
                pointsEarned += 5; 
            }

            habit.Points += pointsEarned;
            _context.Habits.Update(habit);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                habit = habit,
                pointsEarned = pointsEarned,
                message = "¡Hábito marcado! Puntos agregados."
            });
        }

        // 4. DELETE: api/habits/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteHabit(string id)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            var habit = await _context.Habits
                .FirstOrDefaultAsync(h => h.Id == id && h.UserId == userId.Value);

            if (habit == null) return NotFound();

            _context.Habits.Remove(habit);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Hábito eliminado correctamente." });
        }

        // 5. POST: api/habits/sync
        [HttpPost("sync")]
        public async Task<IActionResult> SyncHabits([FromBody] List<Habit> clientHabits)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            // 1. Process client habits
            foreach (var clientHab in clientHabits)
            {
                clientHab.UserId = userId.Value;
                var existing = await _context.Habits.FindAsync(clientHab.Id);
                
                if (existing != null)
                {
                    // Merge: Keep the one with the latest completion date
                    if (clientHab.LastCompleted.HasValue && 
                        (!existing.LastCompleted.HasValue || clientHab.LastCompleted.Value > existing.LastCompleted.Value))
                    {
                        existing.Name = clientHab.Name;
                        existing.Frequency = clientHab.Frequency;
                        existing.Streak = clientHab.Streak;
                        existing.LastCompleted = clientHab.LastCompleted;
                        existing.Points = clientHab.Points;
                        _context.Habits.Update(existing);
                    }
                }
                else
                {
                    _context.Habits.Add(clientHab);
                }
            }

            await _context.SaveChangesAsync();

            // 2. Return the consolidated list
            var consolidated = await _context.Habits
                .Where(h => h.UserId == userId.Value)
                .OrderBy(h => h.CreatedAt)
                .ToListAsync();

            return Ok(consolidated);
        }
    }
}
