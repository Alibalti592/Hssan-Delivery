import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/config.dart';

void main() {
  group('AppConfig.resolvePhotoUrl', () {
    test('prefixes a relative photo path with the API host', () {
      expect(
        AppConfig.resolvePhotoUrl('/uploads/restaurants/abc123.jpg'),
        '${AppConfig.apiBaseUrl}/uploads/restaurants/abc123.jpg',
      );
    });
  });

  group('checkSecureTransport', () {
    test('allows a plaintext URL outside a release build', () {
      expect(
        () => checkSecureTransport('http://10.0.2.2:8000', isRelease: false),
        returnsNormally,
      );
    });

    test('allows an https URL in a release build', () {
      expect(
        () =>
            checkSecureTransport('https://api.hssan.example', isRelease: true),
        returnsNormally,
      );
    });

    test('throws for a plaintext URL in a release build', () {
      expect(
        () => checkSecureTransport('http://10.0.2.2:8000', isRelease: true),
        throwsStateError,
      );
    });
  });
}
