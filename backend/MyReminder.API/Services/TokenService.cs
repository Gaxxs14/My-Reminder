using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using MyReminder.API.Models;

namespace MyReminder.API.Services
{
    public class TokenService
    {
        private readonly IConfiguration _configuration;

        public TokenService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        /// <summary>
        /// Genera un Access Token JWT de corta duración (15 minutos por defecto,
        /// configurable mediante Jwt:AccessTokenExpiryMinutes).
        /// </summary>
        public string GenerateAccessToken(User user)
        {
            var keySection = _configuration["Jwt:Key"];
            if (string.IsNullOrWhiteSpace(keySection) || keySection.Length < 32)
            {
                keySection = "MyReminder_SuperSecretKey2026_UltraSecureJwtTokenAuthKey_987654321!";
            }

            var issuer = _configuration["Jwt:Issuer"] ?? "MyReminderAPI";
            var audience = _configuration["Jwt:Audience"] ?? "MyReminderClients";
            var expiresInMinutes = _configuration.GetValue<int?>("Jwt:AccessTokenExpiryMinutes") ?? 15;

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keySection));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(expiresInMinutes),
                signingCredentials: credentials);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        /// <summary>
        /// Método de compatibilidad para el código existente que llamaba GenerateToken.
        /// Ahora genera un Access Token de corta duración.
        /// </summary>
        public string GenerateToken(User user) => GenerateAccessToken(user);

        /// <summary>
        /// Genera un Refresh Token aleatorio de 512 bits (64 bytes) y su hash SHA-256.
        /// Solo el hash se almacena en la base de datos; el token en claro se devuelve
        /// una única vez al cliente.
        /// </summary>
        public (string Token, string TokenHash) GenerateRefreshToken()
        {
            var randomBytes = RandomNumberGenerator.GetBytes(64);
            var token = Convert.ToBase64String(randomBytes);
            return (token, HashToken(token));
        }

        /// <summary>
        /// Calcula el hash SHA-256 en formato hexadecimal de un refresh token.
        /// </summary>
        public static string HashToken(string token)
        {
            using var sha256 = SHA256.Create();
            var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(token));
            return Convert.ToHexString(bytes);
        }
    }
}