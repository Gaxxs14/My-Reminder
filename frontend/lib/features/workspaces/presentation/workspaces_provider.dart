import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../reminders/presentation/reminders_provider.dart';
import '../../reminders/data/reminder_model.dart';
import '../data/workspace_model.dart';
import '../data/local_workspace_repository.dart';

final workspacesProvider = StateNotifierProvider<WorkspacesNotifier, List<WorkspaceModel>>((ref) {
  final repo = ref.watch(localWorkspaceRepositoryProvider);
  return WorkspacesNotifier(repo, ref);
});

class WorkspaceMemberModel {
  final String id;
  final String username;
  final DateTime createdAt;

  WorkspaceMemberModel({required this.id, required this.username, required this.createdAt});

  factory WorkspaceMemberModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceMemberModel(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class WorkspacesNotifier extends StateNotifier<List<WorkspaceModel>> {
  final LocalWorkspaceRepository _repository;
  final Ref _ref;

  WorkspacesNotifier(this._repository, this._ref) : super([]) {
    loadWorkspaces();
  }

  // Load workspaces from local Cache SQLite
  Future<void> loadWorkspaces() async {
    try {
      final list = await _repository.getWorkspaces();
      state = list;
    } catch (_) {
      state = [];
    }
  }

  // Create workspace in Cloud DB and save locally
  Future<void> createWorkspace(String name) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.post('/api/workspaces', data: {'name': name});

      if (response.statusCode == 200) {
        final workspace = WorkspaceModel.fromJson(Map<String, dynamic>.from(response.data as Map));
        await _repository.insertWorkspace(workspace);
        state = [workspace, ...state];
      }
    } catch (_) {
      rethrow;
    }
  }

  // Sync workspaces from server to SQLite local cache
  Future<void> syncWithCloud() async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.get('/api/workspaces');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final serverList = data.map((json) {
          return WorkspaceModel.fromJson(Map<String, dynamic>.from(json as Map));
        }).toList();

        await _repository.clearAndReplace(serverList);
        state = serverList;

        // Automatically sync reminders of each workspace as well!
        for (final ws in serverList) {
          await syncWorkspaceReminders(ws.id);
        }
      }
    } catch (_) {
      rethrow;
    }
  }

  // Invite user to a workspace by username
  Future<Map<String, dynamic>> inviteMember(String workspaceId, String username) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/workspaces/$workspaceId/invite',
        queryParameters: {'username': username},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message'] as String};
      }
      return {'success': false, 'message': 'Error desconocido al invitar.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fetch all members of a workspace
  Future<List<WorkspaceMemberModel>> getMembers(String workspaceId) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.get('/api/workspaces/$workspaceId/members');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        return data.map((json) {
          return WorkspaceMemberModel.fromJson(Map<String, dynamic>.from(json as Map));
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Sync shared reminders inside workspace
  Future<void> syncWorkspaceReminders(String workspaceId) async {
    try {
      // 1. Get local reminders of this workspace
      final remindersRepo = _ref.read(localReminderRepositoryProvider);
      final allReminders = await remindersRepo.getReminders();
      final wsReminders = allReminders.where((r) => r.workspaceId == workspaceId).toList();

      // 2. Upload them to sync with server
      final body = wsReminders.map((r) => r.toJson()).toList();
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.post('/api/workspaces/$workspaceId/sync', data: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final serverList = data.map((json) {
          return ReminderModel.fromJson(Map<String, dynamic>.from(json as Map));
        }).toList();

        // 3. Upsert them locally in SQLite
        for (final r in serverList) {
          await remindersRepo.insertReminder(r);
        }

        // 4. Refresh global reminders provider state
        await _ref.read(remindersProvider.notifier).loadReminders();
      }
    } catch (_) {
      // Suppress offline errors during background sync
    }
  }
}
