import 'package:dio/dio.dart';
import '../database/db_helper.dart';
import '../network/api_client.dart';
import 'biometric_service.dart';
import 'secure_storage_service.dart';

class AuthService {
  final SecureStorageService _secureStorage;
  final BiometricService _biometricService;
  final DbHelper _dbHelper;
  final ApiClient _apiClient;

  AuthService({
    required SecureStorageService secureStorage,
    required BiometricService biometricService,
    required DbHelper dbHelper,
    required ApiClient apiClient,
  })  : _secureStorage = secureStorage,
        _biometricService = biometricService,
        _dbHelper = dbHelper,
        _apiClient = apiClient;

  // Check if the user has an active session token saved
  Future<bool> checkSession() async {
    final token = await _secureStorage.getToken();
    if (token != null) {
      try {
        // Initialize local database on startup
        await _dbHelper.initDatabase();
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  // Register user on C# backend and store JWT token
  Future<bool> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/register',
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);
        final token = (data['token'] ?? data['Token']) as String?;
        if (token != null && token.isNotEmpty) {
          await _secureStorage.saveToken(token);
          await _secureStorage.saveUsername(username);
          
          // Initialize local DB on success
          await _dbHelper.initDatabase();
          return true;
        }
      }
      return false;
    } on DioException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Login user on C# backend and store JWT token
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);
        final token = (data['token'] ?? data['Token']) as String?;
        if (token != null && token.isNotEmpty) {
          await _secureStorage.saveToken(token);
          await _secureStorage.saveUsername(username);
          
          // Initialize local DB on success
          await _dbHelper.initDatabase();
          return true;
        }
      }
      return false;
    } on DioException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Login using FaceID/Fingerprint if there's a stored session
  Future<bool> loginWithBiometrics() async {
    final hasToken = await _secureStorage.getToken();
    if (hasToken == null) return false;

    final canAuth = await _biometricService.canAuthenticate();
    if (!canAuth) return false;

    final authenticated = await _biometricService.authenticate();
    if (authenticated) {
      await _dbHelper.initDatabase();
      return true;
    }
    return false;
  }

  // Logout and clear all storage / local db
  Future<void> logout() async {
    await _secureStorage.deleteToken();
    try {
      await _dbHelper.clearAllData();
      await _dbHelper.closeDatabase();
    } catch (_) {}
  }
}
