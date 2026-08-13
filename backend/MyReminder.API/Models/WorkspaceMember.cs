using System;
using System.Text.Json.Serialization;

namespace MyReminder.API.Models
{
    public class WorkspaceMember
    {
        public Guid WorkspaceId { get; set; }
        public Guid UserId { get; set; }
        public DateTime JoinedAt { get; set; } = DateTime.UtcNow;

        [JsonIgnore]
        public virtual Workspace? Workspace { get; set; }

        [JsonIgnore]
        public virtual User? User { get; set; }
    }
}
