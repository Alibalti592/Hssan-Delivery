import '../catalogue/catalogue_models.dart';
import '../orders/order_models.dart';

/// What the home feed works out from data the app already has: no number
/// here is made up. "Vos plus commandés" counts the customer's own recent
/// orders, and "Nouveautés" reads each restaurant's creation date.

/// A dish the customer ordered, with how many of their orders had it.
class OrderedDish {
  const OrderedDish({
    required this.restaurantId,
    required this.productId,
    required this.orderCount,
    required this.lastOrderedAt,
  });

  final int restaurantId;
  final int productId;

  /// How many orders it was in (two burgers in one order count once).
  final int orderCount;
  final DateTime? lastOrderedAt;
}

/// The dishes in [orders], most ordered first, then most recent. Parcels,
/// bills and cancelled orders don't count.
List<OrderedDish> countOrderedDishes(Iterable<ClientOrder> orders) {
  final counts = <(int, int), int>{};
  final latest = <(int, int), DateTime?>{};

  for (final order in orders) {
    final restaurantId = order.restaurantId;
    if (restaurantId == null || order.status == OrderStatus.cancelled) {
      continue;
    }
    final seen = <int>{};
    for (final item in order.items) {
      if (item.productId <= 0 || !seen.add(item.productId)) continue;
      final key = (restaurantId, item.productId);
      counts[key] = (counts[key] ?? 0) + 1;
      final when = order.createdAt;
      final previous = latest[key];
      if (previous == null || (when != null && when.isAfter(previous))) {
        latest[key] = when;
      }
    }
  }

  final dishes = [
    for (final entry in counts.entries)
      OrderedDish(
        restaurantId: entry.key.$1,
        productId: entry.key.$2,
        orderCount: entry.value,
        lastOrderedAt: latest[entry.key],
      ),
  ];
  dishes.sort((a, b) {
    final byCount = b.orderCount.compareTo(a.orderCount);
    if (byCount != 0) return byCount;
    final at = a.lastOrderedAt, bt = b.lastOrderedAt;
    if (at == null || bt == null) return 0;
    return bt.compareTo(at);
  });
  return dishes;
}

/// A dish of "Vos plus commandés", ready to show and to open.
class FavouriteDish {
  const FavouriteDish({
    required this.product,
    required this.restaurant,
    required this.orderCount,
  });

  final Product product;
  final Restaurant restaurant;
  final int orderCount;
}

/// [ordered] matched to today's menus: a dish no longer on the menu, sold
/// out, or from a closed restaurant is left out, so every card can be
/// ordered right away.
List<FavouriteDish> favouriteDishes({
  required List<OrderedDish> ordered,
  required Map<int, Restaurant> restaurants,
  required Map<int, List<Product>> menus,
  int max = 8,
}) {
  final result = <FavouriteDish>[];
  for (final dish in ordered) {
    final restaurant = restaurants[dish.restaurantId];
    if (restaurant == null || !restaurant.isAvailable) continue;
    final product = menus[dish.restaurantId]
        ?.where((p) => p.id == dish.productId && p.isAvailable)
        .firstOrNull;
    if (product == null) continue;
    result.add(
      FavouriteDish(
        product: product,
        restaurant: restaurant,
        orderCount: dish.orderCount,
      ),
    );
    if (result.length == max) break;
  }
  return result;
}

/// The restaurants that joined in the last [window], newest first.
List<Restaurant> newRestaurants(
  Iterable<Restaurant> restaurants, {
  required DateTime now,
  Duration window = const Duration(days: 30),
  int max = 6,
}) {
  final recent = restaurants.where((r) {
    final createdAt = r.createdAt;
    return createdAt != null && now.difference(createdAt) <= window;
  }).toList()..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  return recent.take(max).toList(growable: false);
}

/// "Ajouté aujourd’hui", "Ajouté hier", "Ajouté il y a 5 jours".
String addedLabel(DateTime createdAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final local = createdAt.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'Ajouté aujourd’hui';
  if (days == 1) return 'Ajouté hier';
  return 'Ajouté il y a $days jours';
}

/// Open restaurants first, each group in the order the server sent.
List<Restaurant> openFirst(Iterable<Restaurant> restaurants) {
  final list = restaurants.toList();
  return [
    ...list.where((r) => r.isAvailable),
    ...list.where((r) => !r.isAvailable),
  ];
}
