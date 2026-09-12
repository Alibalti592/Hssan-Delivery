import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks whether the onboarding carousel has already been shown, so it only
/// appears once per install.
class OnboardingStorage {
  OnboardingStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'onboarding_seen';

  final FlutterSecureStorage _storage;

  Future<bool> hasSeenOnboarding() async {
    return (await _storage.read(key: _key)) == 'true';
  }

  Future<void> markSeen() => _storage.write(key: _key, value: 'true');
}
