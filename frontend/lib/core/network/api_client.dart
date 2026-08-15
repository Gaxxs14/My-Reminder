import 'package:dio/dio.dart';
import '../security/secure_storage_service.dart';

class ApiClient {
  final Dio _dio;
  final SecureStorageService _secureStorage;

  // Callback invocado cuando el refresh token también falla (fuerza logout).
  // Es mutable para poder configurarse en runtime desde el notifier de auth
  // sin crear ciclos de dependencia entre providers de Riverpod.
  Future<void> Function()? onUnauthorized;

  // Flag para evitar múltiples llamadas de refresh concurrentes
  bool _isRefreshing = false;

  ApiClient({
    required String baseUrl,
    required SecureStorageService secureStorage,
  }) : _secureStorage = secureStorage,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(
             seconds: 60,
           ), // Render free tier cold start can take ~50s
           receiveTimeout: const Duration(seconds: 60),
           headers: {
             'Content-Type': 'application/json',
             'Accept': 'application/json',
           },
         ),
       ) {
    _initializeInterceptors();
  }

  Dio get dio => _dio;

  void _initializeInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Retrieve the access JWT token from Secure Storage
          final token = await _secureStorage.getToken();

          if (token != null) {
            // Add Authorization header
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Solo manejamos 401 de endpoints normales (no del propio refresh)
          if (e.response?.statusCode == 401 &&
              !e.requestOptions.path.contains('/api/auth/')) {
            final refreshed = await _tryRefreshToken();

            if (refreshed) {
              // Reintentar la solicitud original con el nuevo access token
              try {
                final newToken = await _secureStorage.getToken();
                e.requestOptions.headers['Authorization'] = 'Bearer $newToken';

                // Crear una copia de la solicitud con las mismas opciones
                final retryResponse = await _dio.fetch(
                  e.requestOptions..path = e.requestOptions.path,
                );
                return handler.resolve(retryResponse);
              } catch (retryError) {
                // Si el reintento falla, se propaga el error original
              }
            } else {
              // El refresh falló: forzar logout (limpiar credenciales locales)
              await _secureStorage.deleteToken();
              await _secureStorage.deleteRefreshToken();
              if (onUnauthorized != null) {
                await onUnauthorized!();
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Intenta renovar el Access Token usando el Refresh Token guardado
  Future<bool> _tryRefreshToken() async {
    // Evitar múltiples refrescos concurrentes
    if (_isRefreshing) return false;

    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    _isRefreshing = true;
    try {
      final response = await _dio.post(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken =
            data['accessToken'] as String? ?? data['access_token'] as String?;
        final newRefreshToken =
            data['refreshToken'] as String? ?? data['refresh_token'] as String?;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _secureStorage.saveToken(newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _secureStorage.saveRefreshToken(newRefreshToken);
          }
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // GET Request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // POST Request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } catch (e) {
      rethrow;
    }
  }

  // PUT Request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // DELETE Request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } catch (e) {
      rethrow;
    }
  }
}
