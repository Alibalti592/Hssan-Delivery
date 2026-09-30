import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';

void main() {
  test('a validation failure shows its first field error', () {
    expect(
      ApiClient.errorMessage(400, {
        'message': 'Validation failed.',
        'errors': [
          {'field': 'phone', 'message': 'Numéro de téléphone invalide.'},
          {'field': 'name', 'message': 'Nom requis.'},
        ],
      }),
      'Numéro de téléphone invalide.',
    );
  });

  test("otherwise the server's own message", () {
    expect(
      ApiClient.errorMessage(409, {
        'message': 'Un compte existe déjà avec ce numéro.',
      }),
      'Un compte existe déjà avec ce numéro.',
    );
  });

  test('server errors and rate limits read as plain words', () {
    expect(
      ApiClient.errorMessage(502, null),
      'Le service est momentanément indisponible. Réessayez dans un instant.',
    );
    expect(
      ApiClient.errorMessage(429, {
        'message':
            'Too many failed login attempts, please try again in 1 minute.',
      }),
      'Trop de tentatives. Réessayez dans une minute.',
    );
    expect(
      ApiClient.errorMessage(404, null),
      'La requête a échoué. Réessayez.',
    );
  });
}
