import '../core/api_client.dart';
import 'account.dart';

/// A signed-in session: the JWT, and the refresh token that renews it.
class SessionTokens {
  const SessionTokens(this.token, this.refreshToken);

  final String token;

  /// Null only from an older server that doesn't hand them out.
  final String? refreshToken;

  factory SessionTokens.fromJson(Object? body) {
    final token = (body is Map) ? body['token'] : null;
    if (token is! String || token.isEmpty) {
      throw StateError('Response did not contain a token.');
    }
    final refresh = (body as Map)['refreshToken'];
    return SessionTokens(token, refresh is String ? refresh : null);
  }
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Exchanges phone + password for a session.
  Future<SessionTokens> login(String phone, String password) async {
    final body = await _api.post('/api/auth/login', {
      'phone': phone,
      'password': password,
    });
    return SessionTokens.fromJson(body);
  }

  /// Trades a refresh token for a new session. Sent without the expired
  /// JWT, which the server would reject.
  Future<SessionTokens> refresh(String refreshToken) async {
    final body = await _api.post('/api/auth/refresh', {
      'refreshToken': refreshToken,
    }, false);
    return SessionTokens.fromJson(body);
  }

  /// Ends this device's session on the server, so its refresh token stops
  /// working.
  Future<void> logout(String refreshToken) async {
    await _api.post('/api/auth/logout', {'refreshToken': refreshToken}, false);
  }

  /// Creates a ROLE_CLIENT account. Does not sign in — callers should
  /// follow up with [login].
  Future<void> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    await _api.post('/api/auth/register', {
      'name': name,
      'phone': phone,
      'password': password,
    });
  }

  Future<Account> me() async {
    final body = await _api.get('/api/auth/me');
    return Account.fromJson(body as Map<String, dynamic>);
  }

  /// Self-service courier availability toggle. See AuthController::availability.
  Future<Account> setAvailability(bool isAvailable) async {
    final body = await _api.patch('/api/auth/availability', {
      'isAvailable': isAvailable,
    });
    return Account.fromJson(body as Map<String, dynamic>);
  }

  /// Self-service password change. Requires the caller's current password.
  /// Deletes the signed-in account (its past orders stay, anonymous).
  Future<void> deleteAccount(String password) async {
    await _api.delete('/api/auth/me', {'password': password});
  }

  /// Other devices are signed out; this one stays signed in by sending its
  /// own [refreshToken].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? refreshToken,
  }) async {
    await _api.post('/api/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'refreshToken': ?refreshToken,
    });
  }
}
