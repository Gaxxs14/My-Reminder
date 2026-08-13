import 'package:dio/dio.dart';
import '../../features/reminders/data/local_reminder_repository.dart';
import '../../features/reminders/data/reminder_model.dart';
import 'api_client.dart';

class SyncService {
  final ApiClient _apiClient;
  final LocalReminderRepository _repository;

  SyncService({
    required ApiClient apiClient,
    required LocalReminderRepository repository,
  })  : _apiClient = apiClient,
        _repository = repository;

  // Run bidirectional synchronization
  Future<List<ReminderModel>> syncReminders() async {
    try {
      // 1. Get unsynced local changes (created or updated offline)
      final unsynced = await _repository.getUnsyncedReminders();
      
      // 2. Map to JSON format for C# API
      final body = unsynced.map((r) => r.toJson()).toList();

      // 3. Send to C# Web API (which merges with Neon Postgres database)
      final response = await _apiClient.post('/api/sync/reminders', data: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        
        // 4. Parse the returned consolidated list
        final List<ReminderModel> serverReminders = data.map((json) {
          return ReminderModel.fromJson(Map<String, dynamic>.from(json as Map));
        }).toList();

        // 5. Replace local SQLite cache with the consolidated data from cloud
        await _repository.clearAndReplace(serverReminders);

        return serverReminders;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Clear data in C# Cloud and reset local SQLite database
  Future<void> resetAll() async {
    try {
      await _apiClient.post('/api/sync/reset');
      await _repository.clearAndReplace([]);
    } catch (e) {
      rethrow;
    }
  }
}
