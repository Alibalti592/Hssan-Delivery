import '../core/api_client.dart';
import 'account.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Exchanges phone + password for a JWT.
  Future<String> login(String phone, String password) async {
    final body = await _api.post('/api/auth/login', {
      'phone': phone,
      'password': password,
    });

    final token = (body is Map) ? body['token'] : null;
    if (token is! String || token.isEmpty) {
      throw StateError('Login response did not contain a token.');
    }
    return token;
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
}
