import 'package:dio/dio.dart';
import '../database/db_helper.dart';
import '../network/api_client.dart';
import 'biometric_service.dart';
import 'secure_storage_service.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  AuthResult({required this.success, this.errorMessage});
}

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
  Future<AuthResult> register({
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
          await _secureStorage.write('saved_password', password);
          
          await _dbHelper.initDatabase();
          return AuthResult(success: true);
        }
      }
      return AuthResult(success: false, errorMessage: 'Respuesta inválida del servidor');
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        if (data is String && data.isNotEmpty) {
          return AuthResult(success: false, errorMessage: data);
        }
        if (data is Map && data.containsKey('message')) {
          return AuthResult(success: false, errorMessage: data['message'].toString());
        }
        if (e.response?.statusCode == 409) {
          return AuthResult(success: false, errorMessage: 'El nombre de usuario ya está registrado.');
        }
      }
      return AuthResult(success: false, errorMessage: 'Error de red o servidor (Render): ${e.message ?? e.toString()}');
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Error inesperado: $e');
    }
  }

  // Login user on C# backend and store JWT token
  Future<AuthResult> login({
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
          await _secureStorage.write('saved_password', password);
          
          await _dbHelper.initDatabase();
          return AuthResult(success: true);
        }
      }
      return AuthResult(success: false, errorMessage: 'Respuesta inválida del servidor');
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        if (data is String && data.isNotEmpty) {
          return AuthResult(success: false, errorMessage: data);
        }
        if (data is Map && data.containsKey('message')) {
          return AuthResult(success: false, errorMessage: data['message'].toString());
        }
        if (e.response?.statusCode == 401) {
          return AuthResult(success: false, errorMessage: 'Usuario o contraseña incorrectos.');
        }
      }
      return AuthResult(success: false, errorMessage: 'Error de conexión (Render): ${e.message ?? e.toString()}');
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Error inesperado: $e');
    }
  }

  // Login using FaceID/Fingerprint seamlessly
  Future<bool> loginWithBiometrics() async {
    final canAuth = await _biometricService.canAuthenticate();
    if (!canAuth) return false;

    final authenticated = await _biometricService.authenticate(
      reason: 'Escanea tu huella dactilar para acceder a My Reminder',
    );
    if (!authenticated) return false;

    final hasToken = await _secureStorage.getToken();
    if (hasToken != null) {
      await _dbHelper.initDatabase();
      return true;
    }

    final savedUsername = await _secureStorage.getUsername();
    final savedPassword = await _secureStorage.read('saved_password');

    if (savedUsername != null && savedPassword != null) {
      final result = await login(username: savedUsername, password: savedPassword);
      return result.success;
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
