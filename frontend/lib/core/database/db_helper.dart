import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Database? _database;

  // Get active database. Throws exception if not initialized.
  Database get database {
    if (_database == null) {
      throw StateError('La base de datos no ha sido inicializada. Llama a initDatabase() primero.');
    }
    return _database!;
  }

  // Initialize SQLite database
  Future<void> initDatabase() async {
    if (_database != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'my_reminder.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        registered_at TEXT NOT NULL
      )
    ''');

    // Reminders table
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL DEFAULT 'General',
        due_date TEXT NOT NULL, -- ISO 8601 String
        status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'completed'
        is_synced INTEGER NOT NULL DEFAULT 0, -- 0 = Local pending, 1 = Synced with cloud
        created_at TEXT NOT NULL
      )
    ''');

    // Categories table (custom workspaces / spaces)
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL, -- Hex code string, e.g. '#38BDF8'
        icon TEXT NOT NULL -- Icon string identifier, e.g. 'work'
      )
    ''');

    // Insert default categories
    await db.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-1', 'Trabajo', '#38BDF8', 'work')");
    await db.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-2', 'Personal', '#0D9488', 'person')");
    await db.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-3', 'Salud', '#EF4444', 'favorite')");
  }

  // Clear all local tables (used on logout/reset)
  Future<void> clearAllData() async {
    if (_database == null) return;
    await _database!.delete('reminders');
    await _database!.delete('users');
    await _database!.delete('categories');
    // Re-insert defaults
    await _database!.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-1', 'Trabajo', '#38BDF8', 'work')");
    await _database!.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-2', 'Personal', '#0D9488', 'person')");
    await _database!.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-3', 'Salud', '#EF4444', 'favorite')");
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
