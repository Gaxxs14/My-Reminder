using System;
using System.Text.Json.Serialization;

namespace MyReminder.API.Models
{
    public class Note
    {
        // Unique ID generated as a string UUID on the client
        public required string Id { get; set; }
        
        public Guid UserId { get; set; }
        public required string Title { get; set; }
        public required string Content { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [JsonIgnore]
        public virtual User? User { get; set; }
    }
}
