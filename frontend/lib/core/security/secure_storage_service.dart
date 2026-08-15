import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  // General operations
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Helper methods for Session Access JWT Token
  Future<void> saveToken(String token) async {
    await write('auth_token', token);
  }

  Future<String?> getToken() async {
    return await read('auth_token');
  }

  Future<void> deleteToken() async {
    await delete('auth_token');
  }

  // Helper methods for Refresh Token
  Future<void> saveRefreshToken(String refreshToken) async {
    await write('refresh_token', refreshToken);
  }

  Future<String?> getRefreshToken() async {
    return await read('refresh_token');
  }

  Future<void> deleteRefreshToken() async {
    await delete('refresh_token');
  }

  // Helper methods for Username
  Future<void> saveUsername(String username) async {
    await write('username', username);
  }

  Future<String?> getUsername() async {
    return await read('username');
  }
}
