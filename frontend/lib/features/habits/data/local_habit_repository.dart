import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import 'habit_model.dart';

class LocalHabitRepository {
  final DbHelper _dbHelper;

  LocalHabitRepository(this._dbHelper);

  // Insert a new habit locally
  Future<void> insertHabit(HabitModel habit) async {
    final db = _dbHelper.database;
    await db.insert(
      'habits',
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all local habits
  Future<List<HabitModel>> getHabits() async {
    final db = _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'habits',
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => HabitModel.fromMap(maps[i]));
  }

  // Update an existing habit
  Future<void> updateHabit(HabitModel habit) async {
    final db = _dbHelper.database;
    await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  // Delete a habit by ID
  Future<void> deleteHabit(String id) async {
    final db = _dbHelper.database;
    await db.delete(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get habits that haven't been synchronized with the cloud
  Future<List<HabitModel>> getUnsyncedHabits() async {
    final db = _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'habits',
      where: 'is_synced = 0',
    );
    return List.generate(maps.length, (i) => HabitModel.fromMap(maps[i]));
  }

  // Replace all local habits with cloud consolidated list
  Future<void> clearAndReplace(List<HabitModel> serverHabits) async {
    final db = _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('habits');
      for (final hab in serverHabits) {
        await txn.insert(
          'habits',
          hab.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
