import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../network/api_client.dart';
import '../security/auth_service.dart';
import '../security/biometric_service.dart';
import '../security/secure_storage_service.dart';
import '../services/notification_service.dart';
import '../network/sync_service.dart';
import '../../features/reminders/data/local_reminder_repository.dart';
import '../../features/habits/data/local_habit_repository.dart';
import '../../features/notes/data/local_note_repository.dart';
import '../../features/workspaces/data/local_workspace_repository.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final biometricProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final localReminderRepositoryProvider = Provider<LocalReminderRepository>((ref) {
  return LocalReminderRepository(ref.watch(dbHelperProvider));
});

final localHabitRepositoryProvider = Provider<LocalHabitRepository>((ref) {
  return LocalHabitRepository(ref.watch(dbHelperProvider));
});

final localNoteRepositoryProvider = Provider<LocalNoteRepository>((ref) {
  return LocalNoteRepository(ref.watch(dbHelperProvider));
});

final localWorkspaceRepositoryProvider = Provider<LocalWorkspaceRepository>((ref) {
  return LocalWorkspaceRepository(ref.watch(dbHelperProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    apiClient: ref.watch(apiClientProvider),
    repository: ref.watch(localReminderRepositoryProvider),
  );
});

final dbHelperProvider = Provider<DbHelper>((ref) {
  return DbHelper();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  // Use http://10.0.2.2:8080 for Android Emulator, or http://localhost:8080 for iOS/Desktop
  const String localUrl = 'http://10.0.2.2:8080'; 
  return ApiClient(
    baseUrl: localUrl,
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final usernameProvider = FutureProvider<String>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return await storage.getUsername() ?? 'Usuario';
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    secureStorage: ref.watch(secureStorageProvider),
    biometricService: ref.watch(biometricProvider),
    dbHelper: ref.watch(dbHelperProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

// A state notifier provider to track authentication state (logged in = true, logged out = false)
final authStateProvider = StateNotifierProvider<AuthStateNotifier, bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService);
});

class AuthStateNotifier extends StateNotifier<bool> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(false) {
    checkSession();
  }

  Future<void> checkSession() async {
    final hasSession = await _authService.checkSession();
    state = hasSession;
  }

  Future<bool> register({
    required String username,
    required String password,
  }) async {
    final success = await _authService.register(username: username, password: password);
    if (success) {
      state = true;
    }
    return success;
  }

  Future<bool> loginWithPassword({
    required String username,
    required String password,
  }) async {
    final success = await _authService.login(username: username, password: password);
    if (success) {
      state = true;
    }
    return success;
  }

  Future<bool> loginWithBiometrics() async {
    final success = await _authService.loginWithBiometrics();
    if (success) {
      state = true;
    }
    return success;
  }

  Future<void> logout() async {
    await _authService.logout();
    state = false;
  }
}
