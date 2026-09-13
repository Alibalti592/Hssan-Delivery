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
}
