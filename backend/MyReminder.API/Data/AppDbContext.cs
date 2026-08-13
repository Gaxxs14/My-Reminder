using Microsoft.EntityFrameworkCore;
using MyReminder.API.Models;

namespace MyReminder.API.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Reminder> Reminders { get; set; }
        public DbSet<Habit> Habits { get; set; }
        public DbSet<Note> Notes { get; set; }
        public DbSet<Workspace> Workspaces { get; set; }
        public DbSet<WorkspaceMember> WorkspaceMembers { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Composite Key for Workspace members
            modelBuilder.Entity<WorkspaceMember>()
                .HasKey(wm => new { wm.WorkspaceId, wm.UserId });

            // Configure relationships
            modelBuilder.Entity<Reminder>()
                .HasOne(r => r.User)
                .WithMany(u => u.Reminders)
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Habit>()
                .HasOne(h => h.User)
                .WithMany()
                .HasForeignKey(h => h.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Note>()
                .HasOne(n => n.User)
                .WithMany()
                .HasForeignKey(n => n.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<WorkspaceMember>()
                .HasOne(wm => wm.Workspace)
                .WithMany()
                .HasForeignKey(wm => wm.WorkspaceId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<WorkspaceMember>()
                .HasOne(wm => wm.User)
                .WithMany()
                .HasForeignKey(wm => wm.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Workspace>()
                .HasOne(w => w.Owner)
                .WithMany()
                .HasForeignKey(w => w.OwnerId)
                .OnDelete(DeleteBehavior.Cascade);

            // Indexing for faster lookups
            modelBuilder.Entity<User>()
                .HasIndex(u => u.Username)
                .IsUnique();

            modelBuilder.Entity<Reminder>()
                .HasIndex(r => r.UserId);

            modelBuilder.Entity<Reminder>()
                .HasIndex(r => r.WorkspaceId);

            modelBuilder.Entity<Habit>()
                .HasIndex(h => h.UserId);

            modelBuilder.Entity<Note>()
                .HasIndex(n => n.UserId);
        }
    }
}
