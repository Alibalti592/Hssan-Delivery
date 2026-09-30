import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session in the platform keystore/keychain: the JWT, and
/// the refresh token that renews it once it expires (see
/// AuthController.refreshSession).
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'jwt';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> writeRefreshToken(String? token) => token == null
      ? _storage.delete(key: _refreshKey)
      : _storage.write(key: _refreshKey, value: token);

  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _refreshKey);
  }
}
