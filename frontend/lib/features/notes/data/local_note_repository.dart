import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import 'note_model.dart';

class LocalNoteRepository {
  final DbHelper _dbHelper;

  LocalNoteRepository(this._dbHelper);

  // Insert a new note locally
  Future<void> insertNote(NoteModel note) async {
    final db = _dbHelper.database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all local notes
  Future<List<NoteModel>> getNotes() async {
    final db = _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => NoteModel.fromMap(maps[i]));
  }

  // Update an existing note
  Future<void> updateNote(NoteModel note) async {
    final db = _dbHelper.database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // Delete a note by ID
  Future<void> deleteNote(String id) async {
    final db = _dbHelper.database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get notes that haven't been synchronized with the cloud
  Future<List<NoteModel>> getUnsyncedNotes() async {
    final db = _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'is_synced = 0',
    );
    return List.generate(maps.length, (i) => NoteModel.fromMap(maps[i]));
  }

  // Replace all local notes with cloud consolidated list
  Future<void> clearAndReplace(List<NoteModel> serverNotes) async {
    final db = _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('notes');
      for (final note in serverNotes) {
        await txn.insert(
          'notes',
          note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
