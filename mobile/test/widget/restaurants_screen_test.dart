import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/restaurants_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _restaurant(int id, String name) => {
  'id': id,
  'name': name,
  'description': null,
  'isAvailable': true,
  'photoUrl': null,
};

void main() {
  testWidgets('filters the restaurant list as the user types', (tester) async {
    // Tall enough that all 3 cards (each with a 16:9 image) render without
    // scrolling — off-screen list items aren't built, so find.text() would
    // otherwise miss them.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mock = MockClient(
      (request) async => jsonResponse(
        pagedBody([
          _restaurant(1, 'Pizza Palace'),
          _restaurant(2, 'Sushi House'),
          _restaurant(3, 'Pizza Corner'),
        ]),
      ),
    );

    final repository = CatalogueRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(
      Provider<CatalogueRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: RestaurantsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pizza Palace'), findsOneWidget);
    expect(find.text('Sushi House'), findsOneWidget);
    expect(find.text('Pizza Corner'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pumpAndSettle();

    expect(find.text('Pizza Palace'), findsOneWidget);
    expect(find.text('Pizza Corner'), findsOneWidget);
    expect(find.text('Sushi House'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();

    expect(
      find.text('Aucun restaurant ne correspond à votre recherche.'),
      findsOneWidget,
    );
  });
}
