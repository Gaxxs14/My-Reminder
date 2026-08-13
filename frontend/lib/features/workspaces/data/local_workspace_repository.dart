import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import 'workspace_model.dart';

class LocalWorkspaceRepository {
  final DbHelper _dbHelper;

  LocalWorkspaceRepository(this._dbHelper);

  // Insert workspace locally
  Future<void> insertWorkspace(WorkspaceModel workspace) async {
    final db = _dbHelper.database;
    await db.insert(
      'workspaces',
      workspace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all local workspaces
  Future<List<WorkspaceModel>> getWorkspaces() async {
    final db = _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workspaces',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => WorkspaceModel.fromMap(maps[i]));
  }

  // Delete a workspace locally
  Future<void> deleteWorkspace(String id) async {
    final db = _dbHelper.database;
    await db.delete(
      'workspaces',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clear and replace workspaces with cloud data
  Future<void> clearAndReplace(List<WorkspaceModel> serverWorkspaces) async {
    final db = _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('workspaces');
      for (final workspace in serverWorkspaces) {
        await txn.insert(
          'workspaces',
          workspace.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
