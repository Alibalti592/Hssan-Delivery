import '../cart/cart.dart';
import '../catalogue/catalogue_repository.dart';
import 'order_models.dart';

/// What "Recommander" managed to put back in the cart.
class ReorderResult {
  const ReorderResult({required this.added, required this.missing});

  /// Lines put back in the cart.
  final int added;

  /// Items no longer on the menu (removed, unavailable, or a size that's
  /// gone), by name.
  final List<String> missing;
}

/// Refills [cart] with [order]'s items, at today's menu prices — the cart
/// is emptied first, since it holds one restaurant at a time anyway.
Future<ReorderResult> reorder(
  ClientOrder order, {
  required CatalogueRepository catalogue,
  required CartController cart,
}) async {
  final restaurantId = order.restaurantId;
  if (restaurantId == null) {
    return const ReorderResult(added: 0, missing: []);
  }

  final products = {
    for (final p in await catalogue.listProducts(restaurantId)) p.id: p,
  };

  cart.clear();
  var added = 0;
  final missing = <String>[];
  for (final item in order.items) {
    final product = products[item.productId];
    final option = product == null || item.option == null
        ? null
        : product.options.where((o) => o.name == item.option).firstOrNull;
    final optionOk =
        product != null && (product.hasOptions == (option != null));
    if (product == null || !product.isAvailable || !optionOk) {
      missing.add(item.displayName);
      continue;
    }
    cart.add(
      product,
      restaurantName: order.restaurantName ?? '',
      quantity: item.quantity,
      option: option,
    );
    added++;
  }
  return ReorderResult(added: added, missing: missing);
}
