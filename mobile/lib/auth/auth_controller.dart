import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/token_storage.dart';
import 'account.dart';
import 'auth_repository.dart';

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
  Account? _account;
  String? _token;
  bool _busy = false;

  AuthStatus get status => _status;
  Account? get account => _account;
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
      final account = await _repository.me();
      if (!account.isClient && !account.isCourier) {
        await _discard();
        return;
      }
      _account = account;
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

      final account = await _repository.me();
      if (!account.isClient && !account.isCourier) {
        _token = null;
        return "Ce compte n'est ni un compte client, ni un compte livreur.";
      }

      await _storage.write(token);
      _account = account;
      _set(AuthStatus.signedIn);
      return null;
    } on ApiException catch (e) {
      _token = null;
      return e.statusCode == 401
          ? 'Numéro ou mot de passe incorrect.'
          : e.message;
    } on NetworkException catch (e) {
      _token = null;
      return e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Creates a ROLE_CLIENT account, then signs in with the same credentials.
  /// Returns an error message on failure, or null on success.
  Future<String?> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await _repository.register(name: name, phone: phone, password: password);
    } on ApiException catch (e) {
      _busy = false;
      notifyListeners();
      return e.statusCode == 409
          ? 'Un compte existe déjà avec ce numéro.'
          : e.message;
    } on NetworkException catch (e) {
      _busy = false;
      notifyListeners();
      return e.message;
    }

    _busy = false;
    notifyListeners();
    return signIn(phone, password);
  }

  /// Returns an error message on failure, or null on success. Does not
  /// affect the current session — the existing token stays valid.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } on NetworkException catch (e) {
      return e.message;
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
    _account = null;
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
