import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
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
    final extras = product == null ? null : _sameExtras(product, item.extras);
    if (product == null ||
        !product.isAvailable ||
        !optionOk ||
        extras == null) {
      missing.add(item.displayName);
      continue;
    }
    cart.add(
      product,
      restaurantName: order.restaurantName ?? '',
      quantity: item.quantity,
      option: option,
      extras: extras,
    );
    added++;
  }
  return ReorderResult(added: added, missing: missing);
}

/// The extras of a past order line, at the product's current prices; null
/// when one is no longer offered or a group now required is missing, so the
/// line goes to "missing" rather than failing at checkout.
List<PickedExtra>? _sameExtras(Product product, List<PickedExtra> previous) {
  final extras = <PickedExtra>[];
  for (final old in previous) {
    final group = product.extraGroups
        .where((g) => g.name == old.group)
        .firstOrNull;
    final choice = group?.choices.where((c) => c.name == old.name).firstOrNull;
    if (choice == null) return null;
    extras.add(
      PickedExtra(group: old.group, name: old.name, price: choice.price),
    );
  }
  for (final group in product.extraGroups) {
    if (!group.required) continue;
    if (!extras.any((e) => e.group == group.name)) return null;
  }
  return extras;
}
