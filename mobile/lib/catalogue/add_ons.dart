import 'catalogue_models.dart';

/// The extras a restaurant already sells as menu items of their own, in
/// sections like "Supplément sauces", "Suppléments", "BOISSONS" or
/// "Garnitures": offered next to a dish and in the cart, so the customer
/// doesn't have to find them at the bottom of the menu.
enum AddOnKind {
  sauce('Sauces'),
  supplement('Suppléments'),
  drink('Boissons');

  const AddOnKind(this.title);

  final String title;

  /// Which kind a menu section holds, by its name; null for a section of
  /// dishes. Sauces first: "Supplément sauces" is a sauce.
  static AddOnKind? ofSection(String name) {
    final n = _plain(name);
    bool has(List<String> words) => words.any(n.contains);
    if (has(['sauce'])) return sauce;
    if (has(['boisson', 'drink', 'soda', 'jus ', 'مشروبات'])) return drink;
    if (has(['supplement', 'garniture', 'accompagnement', 'extra', 'اضافات'])) {
      return supplement;
    }
    return null;
  }

  /// Lower case, accents off, so "SUPPLÈMENTS" and "Supplément" match.
  static String _plain(String text) {
    const from = 'àâäáãèéêëìíîïòóôöõùúûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final char in '${text.toLowerCase()} '.split('')) {
      final i = from.indexOf(char);
      buffer.write(i < 0 ? char : to[i]);
    }
    return buffer.toString();
  }
}

/// One kind of extra and the items of it, in the menu's order.
class AddOnGroup {
  const AddOnGroup(this.kind, this.products);

  final AddOnKind kind;
  final List<Product> products;
}

/// The restaurant's extras, by kind (sauces, then supplements, then
/// drinks). Only what can be added in one tap: available, with no choice
/// to make (one size at most, no extras of its own). Nothing for a dish
/// that is itself an extra ([forProduct] in one of those sections).
List<AddOnGroup> menuAddOns({
  required List<MenuCategory> categories,
  required List<Product> products,
  Product? forProduct,
}) {
  final kinds = <int, AddOnKind>{
    for (final category in categories)
      category.id: ?AddOnKind.ofSection(category.name),
  };
  if (forProduct != null && kinds.containsKey(forProduct.categoryId)) {
    return const [];
  }

  final byKind = <AddOnKind, List<Product>>{};
  for (final product in products) {
    final kind = kinds[product.categoryId];
    if (kind == null || !isQuickAddOn(product)) continue;
    byKind.putIfAbsent(kind, () => []).add(product);
  }
  return [
    for (final kind in AddOnKind.values)
      if (byKind[kind] case final list? when list.isNotEmpty)
        AddOnGroup(kind, list),
  ];
}

/// Whether [product] can go in the cart with one tap.
bool isQuickAddOn(Product product) =>
    product.isAvailable && !product.hasExtras && product.options.length <= 1;

/// The price an extra is added at: its only size's, else its own.
String addOnPrice(Product product) =>
    product.options.firstOrNull?.price ?? product.price;
