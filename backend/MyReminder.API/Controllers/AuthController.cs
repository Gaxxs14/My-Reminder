using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using MyReminder.API.Data;
using MyReminder.API.Models;
using MyReminder.API.Services;

namespace MyReminder.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly TokenService _tokenService;
        private readonly IConfiguration _configuration;

        public AuthController(AppDbContext context, TokenService tokenService, IConfiguration configuration)
        {
            _context = context;
            _tokenService = tokenService;
            _configuration = configuration;
        }

        public class RegisterDto
        {
            public string Username { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
        }

        public class LoginDto
        {
            public string Username { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
        }

        public class RefreshDto
        {
            public string RefreshToken { get; set; } = string.Empty;
        }

        private async Task<object> BuildAuthResponseAsync(User user)
        {
            var accessToken = _tokenService.GenerateAccessToken(user);
            var (refreshToken, refreshTokenHash) = _tokenService.GenerateRefreshToken();

            var refreshTokenDays = _configuration.GetValue<int?>("Jwt:RefreshTokenExpiryDays") ?? 30;

            try
            {
                var tokenEntity = new RefreshToken
                {
                    TokenHash = refreshTokenHash,
                    UserId = user.Id,
                    ExpiresAt = DateTime.UtcNow.AddDays(refreshTokenDays),
                    CreatedAt = DateTime.UtcNow
                };

                _context.RefreshTokens.Add(tokenEntity);
                await _context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Warning: Failed to save refresh token entity: {ex.Message}");
            }

            return new
            {
                Token = accessToken,
                AccessToken = accessToken,
                RefreshToken = refreshToken,
                AccessTokenExpiresIn = _configuration.GetValue<int?>("Jwt:AccessTokenExpiryMinutes") ?? 15,
                UserId = user.Id,
                Username = user.Username
            };
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            {
                return BadRequest("El usuario y la contraseña son obligatorios.");
            }

            if (await _context.Users.AnyAsync(u => u.Username.ToLower() == dto.Username.ToLower()))
            {
                return Conflict("El nombre de usuario ya está registrado.");
            }

            var passwordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password);

            var user = new User
            {
                Username = dto.Username,
                PasswordHash = passwordHash
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return Ok(await BuildAuthResponseAsync(user));
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            {
                return BadRequest("El usuario y la contraseña son obligatorios.");
            }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == dto.Username.ToLower());
            if (user == null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            {
                return Unauthorized("Credenciales inválidas.");
            }

            return Ok(await BuildAuthResponseAsync(user));
        }

        /// <summary>
        /// Renueva el Access Token usando un Refresh Token válido (rotación).
        /// El refresh token antiguo se revoca y se emite uno nuevo.
        /// </summary>
        [HttpPost("refresh")]
        public async Task<IActionResult> Refresh([FromBody] RefreshDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.RefreshToken))
            {
                return BadRequest("El refresh token es obligatorio.");
            }

            var tokenHash = TokenService.HashToken(dto.RefreshToken);

            // Buscar el refresh token junto con su usuario
            var storedToken = await _context.RefreshTokens
                .Include(rt => rt.User)
                .FirstOrDefaultAsync(rt => rt.TokenHash == tokenHash);

            if (storedToken?.User == null || !storedToken.IsActive)
            {
                return Unauthorized("Refresh token inválido o expirado.");
            }

            // Rotación: marcar el token antiguo como revocado
            storedToken.RevokedAt = DateTime.UtcNow;

            // Generar nuevo Access Token y nuevo Refresh Token
            var accessToken = _tokenService.GenerateAccessToken(storedToken.User);
            var (refreshToken, refreshTokenHash) = _tokenService.GenerateRefreshToken();

            var refreshTokenDays = _configuration.GetValue<int?>("Jwt:RefreshTokenExpiryDays") ?? 30;

            var newTokenEntity = new RefreshToken
            {
                TokenHash = refreshTokenHash,
                UserId = storedToken.User.Id,
                ExpiresAt = DateTime.UtcNow.AddDays(refreshTokenDays),
                CreatedAt = DateTime.UtcNow,
                ReplacedByTokenHash = refreshTokenHash
            };

            storedToken.ReplacedByTokenHash = refreshTokenHash;

            _context.RefreshTokens.Add(newTokenEntity);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken,
                AccessTokenExpiresIn = _configuration.GetValue<int?>("Jwt:AccessTokenExpiryMinutes") ?? 15,
                UserId = storedToken.User.Id,
                Username = storedToken.User.Username
            });
        }

        /// <summary>
        /// Revoca un refresh token (logout). Requiere autenticación.
        /// </summary>
        [Authorize]
        [HttpPost("revoke")]
        public async Task<IActionResult> Revoke([FromBody] RefreshDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.RefreshToken))
            {
                return BadRequest("El refresh token es obligatorio.");
            }

            var claim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier) ?? User.FindFirst(System.Security.Claims.ClaimTypes.Name);
            if (claim == null || !Guid.TryParse(claim.Value, out Guid userId))
            {
                return Unauthorized();
            }

            var tokenHash = TokenService.HashToken(dto.RefreshToken);
            var storedToken = await _context.RefreshTokens
                .FirstOrDefaultAsync(rt => rt.TokenHash == tokenHash && rt.UserId == userId);

            if (storedToken == null)
            {
                return NotFound("Refresh token no encontrado.");
            }

            storedToken.RevokedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return Ok(new { message = "Sesión cerrada correctamente." });
        }

        [Authorize]
        [HttpDelete("account")]
        public async Task<IActionResult> DeleteAccount()
        {
            var claim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier) ?? User.FindFirst(System.Security.Claims.ClaimTypes.Name);
            if (claim == null || !Guid.TryParse(claim.Value, out Guid userId))
            {
                return Unauthorized();
            }

            var user = await _context.Users.FindAsync(userId);
            if (user != null)
            {
                var reminders = _context.Reminders.Where(r => r.UserId == userId);
                _context.Reminders.RemoveRange(reminders);

                var notes = _context.Notes.Where(n => n.UserId == userId);
                _context.Notes.RemoveRange(notes);

                var habits = _context.Habits.Where(h => h.UserId == userId);
                _context.Habits.RemoveRange(habits);

                // Los refresh tokens del usuario se eliminan por cascada, pero por claridad:
                var refreshTokens = _context.RefreshTokens.Where(rt => rt.UserId == userId);
                _context.RefreshTokens.RemoveRange(refreshTokens);

                _context.Users.Remove(user);
                await _context.SaveChangesAsync();
            }

            return Ok(new { message = "Cuenta eliminada exitosamente." });
        }
    }
}