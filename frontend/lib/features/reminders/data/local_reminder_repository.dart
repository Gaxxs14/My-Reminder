import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import 'reminder_model.dart';

class LocalReminderRepository {
  final DbHelper _dbHelper;

  LocalReminderRepository(this._dbHelper);

  // Create a new reminder locally
  Future<void> insertReminder(ReminderModel reminder) async {
    final db = _dbHelper.database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Read all reminders from SQLite
  Future<List<ReminderModel>> getReminders() async {
    final db = _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      orderBy: 'due_date ASC',
    );
    return List.generate(maps.length, (i) => ReminderModel.fromMap(maps[i]));
  }

  // Update an existing reminder
  Future<void> updateReminder(ReminderModel reminder) async {
    final db = _dbHelper.database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  // Delete a reminder by ID
  Future<void> deleteReminder(String id) async {
    final db = _dbHelper.database;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get reminders that have not been uploaded to the cloud
  Future<List<ReminderModel>> getUnsyncedReminders() async {
    final db = _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'is_synced = 0',
    );
    return List.generate(maps.length, (i) => ReminderModel.fromMap(maps[i]));
  }

  // Clean local data and write server reminders (Sync synchronization)
  Future<void> clearAndReplace(List<ReminderModel> serverReminders) async {
    final db = _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('reminders');
      for (final rem in serverReminders) {
        await txn.insert(
          'reminders',
          rem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
