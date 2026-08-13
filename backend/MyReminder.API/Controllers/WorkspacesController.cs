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
    public class WorkspacesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public WorkspacesController(AppDbContext context)
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

        // 1. GET: api/workspaces
        // Get all workspaces the logged-in user is a member of
        [HttpGet]
        public async Task<IActionResult> GetMyWorkspaces()
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            var workspaces = await _context.WorkspaceMembers
                .Where(wm => wm.UserId == userId.Value)
                .Select(wm => wm.Workspace)
                .Where(w => w != null)
                .OrderByDescending(w => w!.CreatedAt)
                .ToListAsync();

            return Ok(workspaces);
        }

        // 2. POST: api/workspaces
        // Create a new collaborative space
        [HttpPost]
        public async Task<IActionResult> CreateWorkspace([FromBody] Workspace workspace)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            workspace.Id = Guid.NewGuid();
            workspace.OwnerId = userId.Value;
            workspace.CreatedAt = DateTime.UtcNow;

            _context.Workspaces.Add(workspace);

            // Add owner as the first member of the workspace
            var member = new WorkspaceMember
            {
                WorkspaceId = workspace.Id,
                UserId = userId.Value,
                JoinedAt = DateTime.UtcNow
            };
            _context.WorkspaceMembers.Add(member);

            await _context.SaveChangesAsync();

            return Ok(workspace);
        }

        // 3. POST: api/workspaces/{id}/invite?username=john
        // Invite a member by username
        [HttpPost("{id}/invite")]
        public async Task<IActionResult> InviteMember(Guid id, [FromQuery] string username)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            // Verify workspace exists and user is a member
            var isMember = await _context.WorkspaceMembers
                .AnyAsync(wm => wm.WorkspaceId == id && wm.UserId == userId.Value);

            if (!isMember)
            {
                return Forbid("No tienes permisos para invitar miembros a este espacio.");
            }

            // Find target user by username
            var targetUser = await _context.Users
                .FirstOrDefaultAsync(u => u.Username.ToLower() == username.ToLower());

            if (targetUser == null)
            {
                return NotFound("Usuario no encontrado.");
            }

            // Check if already a member
            var alreadyMember = await _context.WorkspaceMembers
                .AnyAsync(wm => wm.WorkspaceId == id && wm.UserId == targetUser.Id);

            if (alreadyMember)
            {
                return BadRequest("El usuario ya es miembro de este espacio.");
            }

            // Associate user to workspace
            var newMember = new WorkspaceMember
            {
                WorkspaceId = id,
                UserId = targetUser.Id,
                JoinedAt = DateTime.UtcNow
            };

            _context.WorkspaceMembers.Add(newMember);
            await _context.SaveChangesAsync();

            return Ok(new { message = $"Usuario '{targetUser.Username}' invitado con éxito.", userId = targetUser.Id });
        }

        // 4. GET: api/workspaces/{id}/members
        // Get all members in workspace
        [HttpGet("{id}/members")]
        public async Task<IActionResult> GetWorkspaceMembers(Guid id)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            // Check membership
            var isMember = await _context.WorkspaceMembers
                .AnyAsync(wm => wm.WorkspaceId == id && wm.UserId == userId.Value);

            if (!isMember) return Forbid();

            var members = await _context.WorkspaceMembers
                .Where(wm => wm.WorkspaceId == id)
                .Select(wm => wm.User)
                .Where(u => u != null)
                .Select(u => new { u!.Id, u.Username, u.CreatedAt })
                .ToListAsync();

            return Ok(members);
        }

        // 5. POST: api/workspaces/{id}/sync
        // Sync shared reminders inside workspace
        [HttpPost("{id}/sync")]
        public async Task<IActionResult> SyncWorkspaceReminders(string id, [FromBody] List<Reminder> clientReminders)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            if (!Guid.TryParse(id, out Guid workspaceGuid))
            {
                return BadRequest("ID de espacio inválido.");
            }

            // Verify membership
            var isMember = await _context.WorkspaceMembers
                .AnyAsync(wm => wm.WorkspaceId == workspaceGuid && wm.UserId == userId.Value);

            if (!isMember) return Forbid("No eres miembro de este espacio.");

            // Process incoming workspace reminders
            foreach (var clientReminder in clientReminders)
            {
                clientReminder.WorkspaceId = id;
                // If it is in a workspace, UserId represents the creator of the reminder
                var existing = await _context.Reminders.FindAsync(clientReminder.Id);

                if (existing != null)
                {
                    existing.Title = clientReminder.Title;
                    existing.Description = clientReminder.Description;
                    existing.Category = clientReminder.Category;
                    existing.DueDate = clientReminder.DueDate;
                    existing.Status = clientReminder.Status;
                    existing.Latitude = clientReminder.Latitude;
                    existing.Longitude = clientReminder.Longitude;
                    existing.LocationName = clientReminder.LocationName;
                    existing.RadiusInMeters = clientReminder.RadiusInMeters;
                    _context.Reminders.Update(existing);
                }
                else
                {
                    _context.Reminders.Add(clientReminder);
                }
            }

            await _context.SaveChangesAsync();

            // Get consolidated active workspace reminders
            var consolidated = await _context.Reminders
                .Where(r => r.WorkspaceId == id)
                .OrderBy(r => r.DueDate)
                .ToListAsync();

            return Ok(consolidated);
        }
    }
}
