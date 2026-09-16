import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/addresses/address_repository.dart';
import 'package:mobile/client/addresses_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _address({
  int id = 1,
  String label = 'Domicile',
  String addressLine = '12 Rue de la Corniche',
  String? instructions,
  bool isDefault = false,
}) => {
  'id': id,
  'label': label,
  'addressLine': addressLine,
  'instructions': instructions,
  'isDefault': isDefault,
};

Widget _app(AddressRepository repository) {
  return Provider<AddressRepository>.value(
    value: repository,
    child: const MaterialApp(home: AddressesScreen()),
  );
}

void main() {
  testWidgets('edits a saved address and refreshes the list', (tester) async {
    var address = _address();
    var putCalled = false;

    final mock = MockClient((request) async {
      if (request.method == 'PUT') {
        putCalled = true;
        return jsonResponse(address);
      }
      return jsonResponse([address]);
    });

    final repository = AddressRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Domicile'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Modifier l\'adresse'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Libellé'),
      'Bureau',
    );

    // Reflects what the fake PUT response returns once the list reloads.
    address = _address(label: 'Bureau');

    await tester.tap(find.text('MODIFIER'));
    await tester.pumpAndSettle();

    expect(putCalled, isTrue);
    expect(find.text('Bureau'), findsOneWidget);
  });

  testWidgets('deletes a saved address after confirmation', (tester) async {
    var deleted = false;

    final mock = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted = true;
        return http.Response('', 204);
      }
      return jsonResponse(deleted ? [] : [_address()]);
    });

    final repository = AddressRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Domicile'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cette adresse ?'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.text('Domicile'), findsNothing);
    expect(find.text('Aucune adresse enregistrée.'), findsOneWidget);
  });
}
