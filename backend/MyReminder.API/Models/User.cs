using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace MyReminder.API.Models
{
    public class User
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public required string Username { get; set; }
        public required string PasswordHash { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [JsonIgnore]
        public virtual ICollection<Reminder> Reminders { get; set; } = new List<Reminder>();
    }
}
