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
  }) : _secureStorage = secureStorage,
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

  // Guarda los tokens de sesión (access + refresh) tras login/registro
  Future<bool> _saveSession(Map<String, dynamic> data, String username) async {
    final accessToken =
        data['accessToken'] as String? ??
        data['access_token'] as String? ??
        data['token'] as String? ??
        data['Token'] as String?;
    final refreshToken =
        data['refreshToken'] as String? ?? data['refresh_token'] as String? ?? '';

    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    await _secureStorage.saveToken(accessToken);
    if (refreshToken.isNotEmpty) {
      await _secureStorage.saveRefreshToken(refreshToken);
    }
    await _secureStorage.saveUsername(username);
    return true;
  }

  // Renueva el Access Token usando el Refresh Token guardado (rotación)
  Future<AuthResult> refreshSession() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return AuthResult(
        success: false,
        errorMessage: 'Sin refresh token disponible.',
      );
    }

    try {
      final response = await _apiClient.post(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          response.data as Map,
        );
        final username = await _secureStorage.getUsername() ?? '';
        final saved = await _saveSession(data, username);
        // El refresh token emitido reemplaza al anterior en el servidor (rotación)
        if (saved) {
          await _dbHelper.initDatabase();
          return AuthResult(success: true);
        }
      }
      return AuthResult(
        success: false,
        errorMessage: 'No se pudo renovar la sesión.',
      );
    } on DioException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Error renovando sesión: ${e.message ?? e.toString()}',
      );
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Error inesperado: $e');
    }
  }

  // Register user on C# backend and store JWT token
  Future<AuthResult> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/register',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          response.data as Map,
        );
        final saved = await _saveSession(data, username);
        if (saved) {
          await _dbHelper.initDatabase();
          return AuthResult(success: true);
        }
      }
      return AuthResult(
        success: false,
        errorMessage: 'Respuesta inválida del servidor',
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        if (data is String && data.isNotEmpty) {
          return AuthResult(success: false, errorMessage: data);
        }
        if (data is Map && data.containsKey('message')) {
          return AuthResult(
            success: false,
            errorMessage: data['message'].toString(),
          );
        }
        if (e.response?.statusCode == 409) {
          return AuthResult(
            success: false,
            errorMessage: 'El nombre de usuario ya está registrado.',
          );
        }
      }
      return AuthResult(
        success: false,
        errorMessage:
            'Error de red o servidor (Render): ${e.message ?? e.toString()}',
      );
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Error inesperado: $e');
    }
  }

  // Login user on C# backend and store tokens
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          response.data as Map,
        );
        final saved = await _saveSession(data, username);
        if (saved) {
          await _dbHelper.initDatabase();
          return AuthResult(success: true);
        }
      }
      return AuthResult(
        success: false,
        errorMessage: 'Respuesta inválida del servidor',
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        if (data is String && data.isNotEmpty) {
          return AuthResult(success: false, errorMessage: data);
        }
        if (data is Map && data.containsKey('message')) {
          return AuthResult(
            success: false,
            errorMessage: data['message'].toString(),
          );
        }
        if (e.response?.statusCode == 401) {
          return AuthResult(
            success: false,
            errorMessage: 'Usuario o contraseña incorrectos.',
          );
        }
      }
      return AuthResult(
        success: false,
        errorMessage:
            'Error de conexión (Render): ${e.message ?? e.toString()}',
      );
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Error inesperado: $e');
    }
  }

  // Login using FaceID/Fingerprint seamlessly
  // AHORA depende exclusivamente de un token JWT válido almacenado en el
  // almacenamiento seguro del dispositivo. Ya no se usa la contraseña guardada.
  Future<bool> loginWithBiometrics() async {
    final canAuth = await _biometricService.canAuthenticate();
    if (!canAuth) return false;

    final authenticated = await _biometricService.authenticate(
      reason: 'Escanea tu huella dactilar para acceder a My Reminder',
    );
    if (!authenticated) return false;

    // 1. Si existe un token JWT guardado, la sesión es válida: abrir la app.
    final hasToken = await _secureStorage.getToken();
    if (hasToken != null) {
      await _dbHelper.initDatabase();
      return true;
    }

    // 2. Sin token JWT no es posible acceder biométricamente.
    //    El usuario debe iniciar sesión con usuario/contraseña primero para
    //    renovar su sesión. Eliminamos cualquier residuo de credenciales.
    await _secureStorage.delete('saved_password');
    return false;
  }

  // Logout and clear all storage / local db
  Future<void> logout() async {
    // Intentar revocar el refresh token en el servidor (best-effort, no bloquea)
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.post(
          '/api/auth/revoke',
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
      // Si el access token ya expiró, el revoke fallará silenciosamente.
      // La limpieza local es lo importante.
    }

    await _secureStorage.deleteToken();
    await _secureStorage.deleteRefreshToken();
    // Limpieza adicional de credenciales residuales de versiones anteriores
    await _secureStorage.delete('saved_password');
    try {
      await _dbHelper.clearAllData();
      await _dbHelper.closeDatabase();
    } catch (_) {}
  }
}
