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

  /// Error tracking (Sentry). Empty by default — the SDK no-ops without a
  /// DSN, so this is inert until one is supplied:
  ///   flutter run --dart-define=SENTRY_DSN=https://...@sentry.io/...
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
