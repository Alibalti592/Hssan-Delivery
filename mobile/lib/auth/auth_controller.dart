import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/token_storage.dart';
import 'auth_repository.dart';
import 'courier.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required TokenStorage storage,
  }) : _repository = repository,
       _storage = storage;

  final AuthRepository _repository;
  final TokenStorage _storage;

  AuthStatus _status = AuthStatus.unknown;
  Courier? _courier;
  String? _token;
  bool _busy = false;

  AuthStatus get status => _status;
  Courier? get courier => _courier;
  String? get token => _token;
  bool get busy => _busy;

  /// Restores a session from stored credentials on app start.
  Future<void> bootstrap() async {
    final stored = await _storage.read();
    if (stored == null) {
      _set(AuthStatus.signedOut);
      return;
    }

    _token = stored;
    try {
      final courier = await _repository.me();
      if (!courier.isCourier) {
        await _discard();
        return;
      }
      _courier = courier;
      _set(AuthStatus.signedIn);
    } on ApiException {
      await _discard();
    } on NetworkException {
      // Keep the token; let the user retry once back online.
      _set(AuthStatus.signedOut);
    }
  }

  /// Returns an error message on failure, or null on success.
  Future<String?> signIn(String phone, String password) async {
    _busy = true;
    notifyListeners();
    try {
      final token = await _repository.login(phone.trim(), password);
      _token = token;

      final courier = await _repository.me();
      if (!courier.isCourier) {
        _token = null;
        return 'This account is not a courier account.';
      }

      await _storage.write(token);
      _courier = courier;
      _set(AuthStatus.signedIn);
      return null;
    } on ApiException catch (e) {
      _token = null;
      return e.statusCode == 401
          ? 'Wrong phone number or password.'
          : e.message;
    } on NetworkException catch (e) {
      _token = null;
      return e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _discard();

  /// Called by the API client when any request comes back 401.
  void onUnauthorized() {
    if (_status == AuthStatus.signedIn) {
      _discard();
    }
  }

  Future<void> _discard() async {
    await _storage.clear();
    _token = null;
    _courier = null;
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
