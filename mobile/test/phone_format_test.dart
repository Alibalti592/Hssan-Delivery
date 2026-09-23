import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/phone_format.dart';

void main() {
  group('validatePhone', () {
    test('rejects an empty value', () {
      expect(validatePhone(''), 'Numéro requis');
      expect(validatePhone(null), 'Numéro requis');
      expect(validatePhone('   '), 'Numéro requis');
    });

    test('rejects a malformed value', () {
      expect(validatePhone('abcdefgh'), 'Numéro de téléphone invalide');
      expect(validatePhone('1234567'), 'Numéro de téléphone invalide');
      expect(validatePhone('02233445'), 'Numéro de téléphone invalide');
    });

    test('accepts a bare 8-digit number', () {
      expect(validatePhone('22334455'), isNull);
    });

    test('accepts a number formatted with the +216 hint', () {
      expect(validatePhone('+216 22 334 455'), isNull);
    });
  });
}
