import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import 'notifications_repository.dart';

/// Wraps Firebase Cloud Messaging for push notifications. Entirely inert
/// unless every FIREBASE_* --dart-define is supplied (see
/// AppConfig.firebaseConfigured) — the app works exactly the same without a
/// Firebase project, this just never sends/receives anything until one is
/// configured, matching how Sentry error tracking is wired in main.dart.
///
/// Errors anywhere in this class are swallowed rather than rethrown: a
/// broken or unreachable push setup must never block sign-in, sign-out, or
/// any other app flow that happens to touch it.
class PushNotificationService {
  PushNotificationService(this._repository);

  final NotificationsRepository _repository;

  /// Attach to MaterialApp(scaffoldMessengerKey: ...) so a foreground push
  /// can surface as a SnackBar regardless of which screen is on top.
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _initialized = false;
  String? _registeredToken;

  Future<void> initialize() async {
    if (!AppConfig.firebaseConfigured) return;

    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseMessagingSenderId,
          projectId: AppConfig.firebaseProjectId,
        ),
      );
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);
      _initialized = true;
    } catch (_) {
      // Bad/incomplete config, unsupported platform, missing native setup
      // (google-services.json etc. — see config.dart) — the app works the
      // same either way, it just won't receive pushes this session.
      _initialized = false;
    }
  }

  /// Call once signed in (fresh sign-in or a restored session) so the
  /// backend knows this device belongs to the current account.
  Future<void> registerForCurrentUser() async {
    if (!_initialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _repository.registerDeviceToken(
        token,
        platform: defaultTargetPlatform.name,
      );
      _registeredToken = token;
    } catch (_) {
      // Sign-in must succeed regardless of whether this did.
    }
  }

  /// Call before clearing the session on sign-out, so a shared/reset device
  /// stops receiving pushes for an account no longer signed in on it.
  Future<void> unregister() async {
    final token = _registeredToken;
    if (!_initialized || token == null) return;

    _registeredToken = null;

    try {
      await _repository.unregisterDeviceToken(token);
    } catch (_) {
      // Sign-out must proceed either way.
    }
  }

  void _showForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    final text = [
      title,
      body,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' — ');

    if (text.isEmpty) return;

    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
  }
}
