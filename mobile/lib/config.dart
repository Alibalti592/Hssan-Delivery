import 'package:flutter/foundation.dart';

/// Fails fast if a release build would talk to a plaintext endpoint — every
/// request (bearer token included) would otherwise go out unencrypted. Pure
/// and parameterized on `isRelease` rather than reading [kReleaseMode]
/// directly, so it's unit-testable without actually building in release
/// mode. Debug/profile builds are never checked: they routinely point at a
/// local http:// backend during development, and that's fine.
void checkSecureTransport(String apiBaseUrl, {required bool isRelease}) {
  if (!isRelease) return;

  if (!apiBaseUrl.startsWith('https://')) {
    throw StateError(
      'API_BASE_URL must use https:// in a release build, got: $apiBaseUrl',
    );
  }
}

/// Runtime configuration.
///
/// Override the API host at build/run time, e.g.
///   flutter run --dart-define=API_BASE_URL=https://api.hssan.example
///
/// The default targets a backend on the host machine as seen from the Android
/// emulator (10.0.2.2). Use http://localhost:8000 for iOS simulator / desktop.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Called once at startup (see main.dart) — throws before the app ever
  /// runs if this is a release build pointed at a non-HTTPS API_BASE_URL.
  static void assertSecureTransportInRelease() =>
      checkSecureTransport(apiBaseUrl, isRelease: kReleaseMode);

  /// Photo endpoints (Restaurant/Product/Promotion) return a relative path
  /// like "/uploads/restaurants/xyz.jpg" — resolve it against the API host
  /// before handing it to Image.network, which otherwise treats a relative
  /// path as an invalid URL and fails to load the image.
  static String resolvePhotoUrl(String path) => '$apiBaseUrl$path';

  /// Error tracking (Sentry). Empty by default — the SDK no-ops without a
  /// DSN, so this is inert until one is supplied:
  ///   flutter run --dart-define=SENTRY_DSN=https://...@sentry.io/...
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Push notifications (Firebase Cloud Messaging). All empty by default —
  /// PushNotificationService skips Firebase entirely unless every one of
  /// these is supplied, so this is inert without a real Firebase project:
  ///   flutter run \
  ///     --dart-define=FIREBASE_API_KEY=... \
  ///     --dart-define=FIREBASE_APP_ID=... \
  ///     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  ///     --dart-define=FIREBASE_PROJECT_ID=...
  /// Get these from a Firebase project's app config (Project settings ->
  /// General -> Your apps) at https://console.firebase.google.com/. This
  /// covers sending/receiving pushes only — it does not replace running
  /// `flutterfire configure`, which a real release build still needs for
  /// native Android/iOS integration (google-services.json etc.).
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
