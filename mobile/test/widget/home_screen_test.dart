import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/home_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/promotions/promotions_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _promotion(int id, String title) => {
  'id': id,
  'title': title,
  'description': null,
  'photoUrl': null,
  'discountType': 'PERCENTAGE',
  'discountValue': '10.000',
  'promoCode': null,
  'restaurantId': null,
  'restaurantName': null,
};

Widget _wrap(PromotionsRepository repository) {
  return Provider<PromotionsRepository>.value(
    value: repository,
    child: const MaterialApp(home: Scaffold(body: HomeScreen())),
  );
}

void main() {
  testWidgets('shows exactly the four service cards, Restaurants first', (
    tester,
  ) async {
    final repository = PromotionsRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: MockClient((request) async => jsonResponse([])),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('Factures'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('Pressing'), findsNothing);
  });

  testWidgets('tapping a coming-soon service shows the placeholder dialog', (
    tester,
  ) async {
    final repository = PromotionsRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: MockClient((request) async => jsonResponse([])),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Factures'));
    await tester.pumpAndSettle();

    expect(find.text('Service bientôt disponible'), findsOneWidget);
  });

  testWidgets(
    'shows the promotions carousel when the backend has active promos',
    (tester) async {
      final repository = PromotionsRepository(
        ApiClient(
          tokenProvider: () => 'jwt-123',
          onUnauthorized: () {},
          httpClient: MockClient(
            (request) async => jsonResponse([
              _promotion(1, 'Summer Discount'),
              _promotion(2, 'Weekend Special'),
            ]),
          ),
        ),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.text('Summer Discount'), findsOneWidget);
      expect(find.text('Weekend Special'), findsOneWidget);
    },
  );

  testWidgets('shows nothing extra when there are no active promotions', (
    tester,
  ) async {
    final repository = PromotionsRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: MockClient((request) async => jsonResponse([])),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Impossible de charger les promotions.'), findsNothing);
  });

  testWidgets('tapping Courses opens grocery stores filtered by type', (
    tester,
  ) async {
    String? requestedUrl;

    final catalogueRepository = CatalogueRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: MockClient((request) async {
          requestedUrl = request.url.toString();
          return jsonResponse(pagedBody([]));
        }),
      ),
    );
    final promotionsRepository = PromotionsRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: MockClient((request) async => jsonResponse([])),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PromotionsRepository>.value(value: promotionsRepository),
          Provider<CatalogueRepository>.value(value: catalogueRepository),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();

    expect(requestedUrl, contains('type=GROCERY'));
    expect(find.text('Service bientôt disponible'), findsNothing);
    expect(
      find.text('Aucun magasin disponible pour le moment.'),
      findsOneWidget,
    );
  });
}
