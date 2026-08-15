import 'package:dio/dio.dart';
import '../../features/reminders/data/local_reminder_repository.dart';
import '../../features/reminders/data/reminder_model.dart';
import '../security/secure_storage_service.dart';
import 'api_client.dart';

class SyncService {
  final ApiClient _apiClient;
  final LocalReminderRepository _repository;
  final SecureStorageService _secureStorage;

  // Clave para almacenar la fecha de la última sincronización en SecureStorage
  static const String lastSyncKey = 'last_sync_at';

  SyncService({
    required ApiClient apiClient,
    required LocalReminderRepository repository,
    required SecureStorageService secureStorage,
  }) : _apiClient = apiClient,
       _repository = repository,
       _secureStorage = secureStorage;

  // Run bidirectional Delta Sync:
  // 1. Envía SOLO los recordatorios locales modificados (is_synced = false)
  // 2. Recibe la lista consolidada del servidor
  // 3. Hace MERGE inteligente local (sin borrar todo como antes)
  // 4. Guarda last_sync_at y marca todo como sincronizado
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
        final serverReminders = data.map((json) {
          return ReminderModel.fromJson(Map<String, dynamic>.from(json as Map));
        }).toList();

        // 5. DELTA SYNC: Merge inteligente local (NO borra todo)
        final merged = await _repository.mergeWithServer(serverReminders);

        // 6. Guardar timestamp de última sincronización
        await _secureStorage.write(
          lastSyncKey,
          DateTime.now().toIso8601String(),
        );

        return merged;
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

  // Devuelve la fecha de la última sincronización exitosa (null si nunca)
  Future<DateTime?> getLastSyncTime() async {
    final stored = await _secureStorage.read(lastSyncKey);
    if (stored == null || stored.isEmpty) return null;
    try {
      return DateTime.parse(stored);
    } catch (_) {
      return null;
    }
  }

  // Clear data in C# Cloud and reset local SQLite database
  Future<void> resetAll() async {
    try {
      await _apiClient.post('/api/sync/reset');
      await _repository.clearAndReplace([]);
      await _secureStorage.write(lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      rethrow;
    }
  }
}
