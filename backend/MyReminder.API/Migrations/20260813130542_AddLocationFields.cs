using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MyReminder.API.Migrations
{
    /// <inheritdoc />
    public partial class AddLocationFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "Latitude",
                table: "Reminders",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LocationName",
                table: "Reminders",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Longitude",
                table: "Reminders",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "RadiusInMeters",
                table: "Reminders",
                type: "double precision",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "Reminders");

            migrationBuilder.DropColumn(
                name: "LocationName",
                table: "Reminders");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "Reminders");

            migrationBuilder.DropColumn(
                name: "RadiusInMeters",
                table: "Reminders");
        }
    }
}
