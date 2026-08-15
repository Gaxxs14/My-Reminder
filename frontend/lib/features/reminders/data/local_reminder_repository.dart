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
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
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

  // Clean local data and write server reminders (used for RESET, not regular sync)
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

  // DELTA SYNC: Hace merge inteligente con la lista del servidor sin borrar todo.
  // - Nuevos del servidor → se insertan
  // - Locales sin sincronizar (dirty) confirmados → se marcan como sincronizados
  // - Locales limpios → se sobrescriben con la versión del servidor (fuente de verdad)
  // - Locales limpios ausentes del servidor → se eliminan (borrados en otro dispositivo)
  Future<List<ReminderModel>> mergeWithServer(
    List<ReminderModel> serverReminders,
  ) async {
    final db = _dbHelper.database;
    final local = await getReminders();
    final localById = {for (final r in local) r.id: r};
    final serverById = {for (final r in serverReminders) r.id: r};

    await db.transaction((txn) async {
      // 1. Insertar / actualizar según estado local
      for (final server in serverReminders) {
        final existing = localById[server.id];
        if (existing == null) {
          // Llegó desde otro dispositivo → insertar
          await txn.insert(
            'reminders',
            server.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else if (!existing.isSynced) {
          // Local con cambios sin subir → el servidor ya lo upsertió,
          // solo confirmar como sincronizado.
          await txn.update(
            'reminders',
            existing.copyWith(isSynced: true).toMap(),
            where: 'id = ?',
            whereArgs: [server.id],
          );
        } else {
          // Local limpio → el servidor es la fuente de verdad → actualizar
          await txn.update(
            'reminders',
            server.toMap(),
            where: 'id = ?',
            whereArgs: [server.id],
          );
        }
      }

      // 2. Eliminar locales limpios que ya no existen en el servidor
      //    (fueron borrados en la nube o desde otro dispositivo).
      for (final localRem in local) {
        if (localRem.isSynced && !serverById.containsKey(localRem.id)) {
          await txn.delete(
            'reminders',
            where: 'id = ?',
            whereArgs: [localRem.id],
          );
        }
      }
    });

    return getReminders();
  }
}
