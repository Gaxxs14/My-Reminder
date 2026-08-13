using System;
using System.Text.Json.Serialization;

namespace MyReminder.API.Models
{
    public class Reminder
    {
        // Using string for Id to support client-generated offline UUIDs seamlessly
        public required string Id { get; set; }
        
        public Guid UserId { get; set; }
        public required string Title { get; set; }
        public string? Description { get; set; }
        public string Category { get; set; } = "General";
        public DateTime DueDate { get; set; }
        public string Status { get; set; } = "pending"; // "pending", "completed"
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Geo-reminders optional fields
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string? LocationName { get; set; }
        public double? RadiusInMeters { get; set; } = 150.0; // Default 150 meters

        // Workspace collaboration optional field
        public string? WorkspaceId { get; set; }

        [JsonIgnore]
        public virtual User? User { get; set; }
    }
}
