import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Database? _database;

  Database get database {
    if (_database == null) {
      throw StateError('La base de datos no ha sido inicializada. Llama a initDatabase() primero.');
    }
    return _database!;
  }

  Future<void> initDatabase() async {
    if (_database != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'my_reminder.db');

    _database = await openDatabase(
      path,
      version: 6, // Bump to version 6 for advanced productivity features
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        registered_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL DEFAULT 'General',
        due_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        location_name TEXT,
        radius_in_meters REAL,
        workspace_id TEXT,
        priority TEXT NOT NULL DEFAULT 'media',
        subtasks TEXT,
        estimated_cost REAL,
        is_alarm INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL DEFAULT 'daily',
        streak INTEGER NOT NULL DEFAULT 0,
        last_completed TEXT,
        points INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mood_logs (
        id TEXT PRIMARY KEY,
        mood TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pomodoro_sessions (
        id TEXT PRIMARY KEY,
        duration_minutes INTEGER NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE quests (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        reward_xp INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL
      )
    ''');

    await db.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-1', 'Trabajo', '#38BDF8', 'work')");
    await db.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-2', 'Personal', '#0D9488', 'person')");
    await db.rawInsert("INSERT INTO categories (id, name, color, icon) VALUES ('cat-3', 'Salud', '#EF4444', 'favorite')");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS habits (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          frequency TEXT NOT NULL DEFAULT 'daily',
          streak INTEGER NOT NULL DEFAULT 0,
          last_completed TEXT,
          points INTEGER NOT NULL DEFAULT 0,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE reminders ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE reminders ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE reminders ADD COLUMN location_name TEXT');
      await db.execute('ALTER TABLE reminders ADD COLUMN radius_in_meters REAL');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE reminders ADD COLUMN workspace_id TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workspaces (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          owner_id TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE reminders ADD COLUMN priority TEXT NOT NULL DEFAULT 'media'");
      await db.execute("ALTER TABLE reminders ADD COLUMN subtasks TEXT");
      await db.execute("ALTER TABLE reminders ADD COLUMN estimated_cost REAL");
      await db.execute("ALTER TABLE reminders ADD COLUMN is_alarm INTEGER NOT NULL DEFAULT 0");

      await db.execute('''
        CREATE TABLE IF NOT EXISTS mood_logs (
          id TEXT PRIMARY KEY,
          mood TEXT NOT NULL,
          note TEXT,
          date TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pomodoro_sessions (
          id TEXT PRIMARY KEY,
          duration_minutes INTEGER NOT NULL,
          completed_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quests (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          reward_xp INTEGER NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          date TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> clearAllData() async {
    if (_database == null) return;
    await _database!.delete('reminders');
    await _database!.delete('users');
    await _database!.delete('categories');
    await _database!.delete('habits');
    await _database!.delete('notes');
    await _database!.delete('workspaces');
    await _database!.delete('mood_logs');
    await _database!.delete('pomodoro_sessions');
    await _database!.delete('quests');
    
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
