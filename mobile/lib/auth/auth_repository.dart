import '../core/api_client.dart';
import 'courier.dart';

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

  Future<Courier> me() async {
    final body = await _api.get('/api/auth/me');
    return Courier.fromJson(body as Map<String, dynamic>);
  }
}
