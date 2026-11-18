import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/client/home_feed.dart';
import 'package:mobile/orders/order_models.dart';

ClientOrder _order(
  int id, {
  int? restaurantId = 1,
  String status = 'COMPLETED',
  List<int> products = const [],
  String createdAt = '2026-11-10T12:00:00+00:00',
}) => ClientOrder.fromJson({
  'id': id,
  'restaurantId': restaurantId,
  'restaurantName': restaurantId == null ? null : 'Resto $restaurantId',
  'items': [
    for (final p in products)
      {
        'productId': p,
        'productName': 'Plat $p',
        'quantity': 1,
        'unitPrice': '10.000',
      },
  ],
  'deliveryAddress': 'Rue de Rome',
  'deliveryZoneId': 1,
  'deliveryZoneName': 'Centre',
  'deliveryFee': '3.000',
  'totalAmount': '13.000',
  'status': status,
  'deliveryType': restaurantId == null ? 'PARCEL' : 'RESTAURANT',
  'createdAt': createdAt,
});

Restaurant _restaurant(int id, {bool open = true, DateTime? createdAt}) =>
    Restaurant(
      id: id,
      name: 'Resto $id',
      description: null,
      isAvailable: open,
      type: RestaurantType.restaurant,
      photoUrl: null,
      createdAt: createdAt,
    );

Product _product(int id, {int restaurantId = 1, bool available = true}) =>
    Product(
      id: id,
      name: 'Plat $id',
      description: null,
      price: '10.000',
      isAvailable: available,
      photoUrl: null,
      restaurantId: restaurantId,
      categoryId: 1,
    );

void main() {
  group('countOrderedDishes', () {
    test('counts orders, not quantities, most ordered first', () {
      final dishes = countOrderedDishes([
        _order(1, products: [10, 10, 11]),
        _order(2, products: [10]),
        _order(3, products: [12], createdAt: '2026-11-12T12:00:00+00:00'),
      ]);

      expect(dishes.first.productId, 10);
      expect(dishes.first.orderCount, 2);
      // 11 and 12 once each: the more recent first.
      expect(dishes.map((d) => d.productId), [10, 12, 11]);
    });

    test('leaves out cancelled orders and parcels', () {
      final dishes = countOrderedDishes([
        _order(1, status: 'CANCELLED', products: [10]),
        _order(2, restaurantId: null, products: [11]),
      ]);

      expect(dishes, isEmpty);
    });
  });

  group('favouriteDishes', () {
    test('keeps only dishes still orderable today', () {
      final ordered = countOrderedDishes([
        _order(1, products: [10, 11, 12]),
        _order(2, restaurantId: 2, products: [20]),
      ]);

      final favourites = favouriteDishes(
        ordered: ordered,
        restaurants: {1: _restaurant(1), 2: _restaurant(2, open: false)},
        menus: {
          1: [_product(10), _product(11, available: false)],
          2: [_product(20, restaurantId: 2)],
        },
      );

      // 11 sold out, 12 off the menu, 20 from a closed restaurant.
      expect(favourites.map((f) => f.product.id), [10]);
    });
  });

  group('newRestaurants', () {
    final now = DateTime(2026, 11, 18, 10);

    test('the last 30 days, newest first, others left out', () {
      final recent = newRestaurants([
        _restaurant(1, createdAt: now.subtract(const Duration(days: 40))),
        _restaurant(2, createdAt: now.subtract(const Duration(days: 3))),
        _restaurant(3, createdAt: now.subtract(const Duration(days: 1))),
        _restaurant(4),
      ], now: now);

      expect(recent.map((r) => r.id), [3, 2]);
    });

    test('says since when, in French', () {
      expect(addedLabel(now, now), 'Ajouté aujourd’hui');
      expect(
        addedLabel(now.subtract(const Duration(days: 1)), now),
        'Ajouté hier',
      );
      expect(
        addedLabel(now.subtract(const Duration(days: 5)), now),
        'Ajouté il y a 5 jours',
      );
    });
  });

  test('openFirst puts closed restaurants last, order kept', () {
    final sorted = openFirst([
      _restaurant(1, open: false),
      _restaurant(2),
      _restaurant(3),
    ]);
    expect(sorted.map((r) => r.id), [2, 3, 1]);
  });
}
