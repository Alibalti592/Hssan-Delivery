import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/catalogue/category_widgets.dart';
import 'package:mobile/client/restaurants_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _category(int id, String name, [String icon = 'pizza']) =>
    {'id': id, 'name': name, 'icon': icon, 'imageUrl': null, 'position': id};

Map<String, dynamic> _restaurant(
  int id,
  String name, [
  List<Map<String, dynamic>> categories = const [],
]) => {
  'id': id,
  'name': name,
  'description': null,
  'isAvailable': true,
  'photoUrl': null,
  'categories': categories,
};

final _pizza = _category(1, 'Pizza');
final _sweet = _category(2, 'Sucré', 'cake');
final _drinks = _category(3, 'Boissons', 'drink');

/// A screen over three restaurants: two pizzerias (one also sweet) and a
/// pastry shop. [categories] is what GET /api/restaurant-categories answers;
/// null makes it fail.
Widget _screen({
  List<Map<String, dynamic>>? categories,
  int? initialCategoryId,
  List<Uri>? requests,
}) {
  final mock = MockClient((request) async {
    requests?.add(request.url);
    if (request.url.path == '/api/restaurant-categories') {
      return categories == null
          ? jsonResponse({'message': 'Erreur'}, 500)
          : jsonResponse(categories);
    }
    return jsonResponse(
      pagedBody([
        _restaurant(1, 'Napoli Express', [_pizza]),
        _restaurant(2, 'Chez Salem', [_pizza, _sweet]),
        _restaurant(3, 'Douceurs du Lac', [_sweet]),
      ]),
    );
  });

  return Provider<CatalogueRepository>.value(
    value: CatalogueRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    ),
    child: MaterialApp(
      home: Scaffold(
        body: RestaurantsScreen(initialCategoryId: initialCategoryId),
      ),
    ),
  );
}

/// Tall enough that all 3 cards (each with a 16:9 image) render without
/// scrolling — off-screen list items aren't built, so find.text() would
/// otherwise miss them.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A tile of the category row (the same names also label the cards).
Finder _tile(String name) => find.descendant(
  of: find.byType(CategorySelector),
  matching: find.text(name),
);

void main() {
  testWidgets('filters the restaurant list as the user types', (tester) async {
    _useTallViewport(tester);

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

  testWidgets('a category filters the list, and "Tout" brings it all back', (
    tester,
  ) async {
    _useTallViewport(tester);
    final requests = <Uri>[];
    await tester.pumpWidget(
      _screen(categories: [_pizza, _sweet], requests: requests),
    );
    await tester.pumpAndSettle();

    // The categories of restaurants (not grocery stores) were asked for.
    expect(
      requests
          .where((u) => u.path == '/api/restaurant-categories')
          .single
          .query,
      'type=RESTAURANT',
    );

    // "Tout" first, then the categories in the server's order.
    expect(_tile('Tout'), findsOneWidget);
    expect(
      tester.getCenter(_tile('Pizza')).dx,
      lessThan(tester.getCenter(_tile('Sucré')).dx),
    );
    expect(find.text('Napoli Express'), findsOneWidget);
    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Douceurs du Lac'), findsOneWidget);

    await tester.tap(_tile('Sucré'));
    await tester.pumpAndSettle();

    expect(find.text('Napoli Express'), findsNothing);
    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Douceurs du Lac'), findsOneWidget);

    await tester.tap(_tile('Pizza'));
    await tester.pumpAndSettle();

    expect(find.text('Napoli Express'), findsOneWidget);
    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Douceurs du Lac'), findsNothing);

    await tester.tap(_tile('Tout'));
    await tester.pumpAndSettle();

    expect(find.text('Napoli Express'), findsOneWidget);
    expect(find.text('Douceurs du Lac'), findsOneWidget);

    // A second tap on the selected category also clears it.
    await tester.tap(_tile('Pizza'));
    await tester.pumpAndSettle();
    expect(find.text('Douceurs du Lac'), findsNothing);
    await tester.tap(_tile('Pizza'));
    await tester.pumpAndSettle();
    expect(find.text('Douceurs du Lac'), findsOneWidget);
  });

  testWidgets('the search and the category work together', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_screen(categories: [_pizza, _sweet]));
    await tester.pumpAndSettle();

    await tester.tap(_tile('Pizza'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'salem');
    await tester.pumpAndSettle();

    // A pizzeria whose name matches: only that one.
    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Napoli Express'), findsNothing);

    // The search stays when the category changes...
    await tester.tap(_tile('Sucré'));
    await tester.pumpAndSettle();
    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Douceurs du Lac'), findsNothing);

    // ...and nothing has both "napoli" and Sucré.
    await tester.enterText(find.byType(TextField), 'napoli');
    await tester.pumpAndSettle();
    expect(
      find.text('Aucun restaurant ne correspond à votre recherche.'),
      findsOneWidget,
    );

    await tester.tap(_tile('Tout'));
    await tester.pumpAndSettle();
    expect(find.text('Napoli Express'), findsOneWidget);
  });

  testWidgets('typing a category name finds the restaurants that have it', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_screen(categories: [_pizza, _sweet]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sucr');
    await tester.pumpAndSettle();

    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Douceurs du Lac'), findsOneWidget);
    expect(find.text('Napoli Express'), findsNothing);
  });

  testWidgets('opens on the category tapped on the home screen', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(
      _screen(categories: [_pizza, _sweet], initialCategoryId: 2),
    );
    await tester.pumpAndSettle();

    expect(find.text('Douceurs du Lac'), findsOneWidget);
    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Napoli Express'), findsNothing);
  });

  testWidgets('each card says what the restaurant serves', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_screen(categories: [_pizza, _sweet]));
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Chez Salem'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: card, matching: find.text('Pizza')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Sucré')),
      findsOneWidget,
    );
  });

  testWidgets('a category nobody has says so', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_screen(categories: [_pizza, _sweet, _drinks]));
    await tester.pumpAndSettle();

    await tester.tap(_tile('Boissons'));
    await tester.pumpAndSettle();

    expect(
      find.text('Aucun restaurant dans cette catégorie pour le moment.'),
      findsOneWidget,
    );
  });

  testWidgets('without the categories, the whole list and no row', (
    tester,
  ) async {
    _useTallViewport(tester);
    // The categories fail to load, even though one was asked for: a filter
    // with no row to undo it would hide restaurants for good.
    await tester.pumpWidget(_screen(initialCategoryId: 2));
    await tester.pumpAndSettle();

    expect(find.byType(CategorySelector), findsNothing);
    expect(find.text('Napoli Express'), findsOneWidget);
    expect(find.text('Chez Salem'), findsOneWidget);
    expect(find.text('Douceurs du Lac'), findsOneWidget);
  });
}
