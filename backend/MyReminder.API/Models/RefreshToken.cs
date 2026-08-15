using System;
using System.Text.Json.Serialization;

namespace MyReminder.API.Models
{
    public class RefreshToken
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        // Token hash (se almacena el hash SHA-256, nunca el token en claro)
        public required string TokenHash { get; set; }

        public Guid UserId { get; set; }

        public DateTime ExpiresAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Si no es null, el token fue revocado (logout / rotación)
        public DateTime? RevokedAt { get; set; }

        // Opcional: guarda el token hash que reemplazó a este (rotación de refresh tokens)
        public string? ReplacedByTokenHash { get; set; }

        [JsonIgnore]
        public virtual User? User { get; set; }

        // Un refresh token es válido si no está revocado y no ha expirado
        [JsonIgnore]
        public bool IsActive => !RevokedAt.HasValue && ExpiresAt > DateTime.UtcNow;
    }
}