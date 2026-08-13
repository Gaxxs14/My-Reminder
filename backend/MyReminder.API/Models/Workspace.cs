using System;
using System.Text.Json.Serialization;

namespace MyReminder.API.Models
{
    public class Workspace
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        public required string Name { get; set; }
        public Guid OwnerId { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [JsonIgnore]
        public virtual User? Owner { get; set; }
    }
}
