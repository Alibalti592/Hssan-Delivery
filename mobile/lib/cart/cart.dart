import 'package:flutter/foundation.dart';

import '../catalogue/catalogue_models.dart';

class CartLine {
  CartLine({
    required this.product,
    required this.quantity,
    this.option,
    this.extras = const [],
  });

  final Product product;

  /// The chosen size/portion, for a product that has options.
  final ProductOption? option;

  /// What the customer added (sauces, extras, a drink...).
  final List<PickedExtra> extras;
  int quantity;

  /// Identifies the line: the same pizza in M and in Familiale, or the same
  /// sandwich with and without harissa, are two lines.
  String get key => CartController.lineKey(product.id, option?.name, extras);

  String get displayName =>
      option == null ? product.name : '${product.name} (${option!.name})';

  /// "Sauces : Harissa · Boisson : Coca-Cola", or empty.
  String get extrasLabel => PickedExtra.describe(extras);

  /// The product's (or its size's) price, plus its extras'.
  double get unitAmount =>
      (double.tryParse(option?.price ?? product.price) ?? 0) +
      extras.fold(0.0, (sum, e) => sum + (double.tryParse(e.price) ?? 0));

  String get unitPrice => unitAmount.toStringAsFixed(3);

  double get lineTotal => unitAmount * quantity;
}

/// A cart can only hold items from one restaurant at a time — the backend's
/// CreateOrderRequest takes a single restaurantId. Adding from a different
/// restaurant replaces the cart; callers should confirm with the user first
/// via [belongsToDifferentRestaurant].
class CartController extends ChangeNotifier {
  /// The backend rejects an order line above this (OrderItemRequest's
  /// Range(max: 100)), so the cart never lets one grow past it.
  static const maxQuantityPerProduct = 100;

  static String lineKey(
    int productId,
    String? optionName, [
    List<PickedExtra> extras = const [],
  ]) {
    final key = optionName == null ? '$productId' : '$productId|$optionName';
    if (extras.isEmpty) return key;
    final picked = extras.map((e) => '${e.group}:${e.name}').toList()..sort();
    return '$key|${picked.join(',')}';
  }

  int? _restaurantId;
  String? _restaurantName;
  final Map<String, CartLine> _lines = {};

  int? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  List<CartLine> get lines => _lines.values.toList(growable: false);
  bool get isEmpty => _lines.isEmpty;
  int get itemCount => _lines.values.fold(0, (sum, l) => sum + l.quantity);

  double get subtotal => _lines.values.fold(0, (sum, l) => sum + l.lineTotal);

  bool belongsToDifferentRestaurant(int restaurantId) =>
      _restaurantId != null && _restaurantId != restaurantId;

  void add(
    Product product, {
    required String restaurantName,
    int quantity = 1,
    ProductOption? option,
    List<PickedExtra> extras = const [],
  }) {
    if (belongsToDifferentRestaurant(product.restaurantId)) {
      _lines.clear();
    }
    _restaurantId = product.restaurantId;
    _restaurantName = restaurantName;

    final key = lineKey(product.id, option?.name, extras);
    final existing = _lines[key];
    if (existing != null) {
      existing.quantity = (existing.quantity + quantity).clamp(
        1,
        maxQuantityPerProduct,
      );
    } else {
      _lines[key] = CartLine(
        product: product,
        option: option,
        extras: extras,
        quantity: quantity.clamp(1, maxQuantityPerProduct),
      );
    }
    notifyListeners();
  }

  void increment(String key) {
    final line = _lines[key];
    if (line == null || line.quantity >= maxQuantityPerProduct) return;
    line.quantity++;
    notifyListeners();
  }

  void decrement(String key) {
    final line = _lines[key];
    if (line == null) return;

    if (line.quantity <= 1) {
      _lines.remove(key);
    } else {
      line.quantity--;
    }

    if (_lines.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
    }
    notifyListeners();
  }

  /// Total quantity of a product in the cart, across all its options.
  int quantityOf(int productId) => _lines.values
      .where((l) => l.product.id == productId)
      .fold(0, (sum, l) => sum + l.quantity);

  void clear() {
    _lines.clear();
    _restaurantId = null;
    _restaurantName = null;
    notifyListeners();
  }
}
