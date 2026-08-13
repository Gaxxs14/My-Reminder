using System;
using System.Text.Json.Serialization;

namespace MyReminder.API.Models
{
    public class Habit
    {
        // Unique ID generated as a string UUID on the client
        public required string Id { get; set; }
        
        public Guid UserId { get; set; }
        public required string Name { get; set; }
        public string Frequency { get; set; } = "daily"; // "daily", "weekly"
        public int Streak { get; set; } = 0;
        public DateTime? LastCompleted { get; set; }
        public int Points { get; set; } = 0;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [JsonIgnore]
        public virtual User? User { get; set; }
    }
}
