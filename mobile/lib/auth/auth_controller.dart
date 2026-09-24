import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../notifications/push_notification_service.dart';
import 'account.dart';
import 'auth_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required TokenStorage storage,
    PushNotificationService? pushNotifications,
    this.onSessionEnded,
  }) : _repository = repository,
       _storage = storage,
       _pushNotifications = pushNotifications;

  final AuthRepository _repository;
  final TokenStorage _storage;
  final PushNotificationService? _pushNotifications;

  /// Called whenever the session ends, whether from a 401
  /// (onUnauthorized) or a manual signOut(). _Root (main.dart) swapping
  /// what MaterialApp.home renders only replaces the bottom-most route —
  /// anything the user had Navigator.push'ed on top (an order detail
  /// screen, say) stays on top of it, stranding them on a now-broken
  /// screen instead of showing LoginScreen. This callback is the caller's
  /// chance to pop back to that bottom route so the swap is actually
  /// visible; a no-op if there was nothing pushed to pop.
  final VoidCallback? onSessionEnded;

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
    String? stored;
    try {
      stored = await _storage.read();
    } catch (_) {
      // flutter_secure_storage can throw (e.g. a corrupted/reset Android
      // keystore after a device restore). Without this, the exception
      // would escape this unawaited call from main.dart and _status would
      // stay AuthStatus.unknown forever, stranding the user on the splash
      // screen with no way to reach the login screen short of reinstalling.
      _set(AuthStatus.signedOut);
      return;
    }
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
      unawaited(_pushNotifications?.registerForCurrentUser());
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
      unawaited(_pushNotifications?.registerForCurrentUser());
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

  /// Returns an error message on failure, or null on success. Reverts to the
  /// previous value on failure, since the caller's toggle UI updates
  /// optimistically before this resolves.
  Future<String?> setAvailability(bool isAvailable) async {
    try {
      _account = await _repository.setAvailability(isAvailable);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      notifyListeners();
      return e.message;
    } on NetworkException catch (e) {
      notifyListeners();
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
    // Unregister while the (possibly already-invalid, e.g. after a 401)
    // token is still set — the call is a best-effort no-op on failure
    // either way, see PushNotificationService.unregister.
    await _pushNotifications?.unregister();
    await _storage.clear();
    _token = null;
    _account = null;
    _set(AuthStatus.signedOut);
    onSessionEnded?.call();
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
