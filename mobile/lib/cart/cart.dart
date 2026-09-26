import 'package:flutter/foundation.dart';

import '../catalogue/catalogue_models.dart';

class CartLine {
  CartLine({required this.product, required this.quantity, this.option});

  final Product product;

  /// The chosen size/portion, for a product that has options.
  final ProductOption? option;
  int quantity;

  /// Identifies the line: the same pizza in M and in Familiale are two lines.
  String get key => CartController.lineKey(product.id, option?.name);

  String get displayName =>
      option == null ? product.name : '${product.name} (${option!.name})';

  String get unitPrice => option?.price ?? product.price;

  double get lineTotal => (double.tryParse(unitPrice) ?? 0) * quantity;
}

/// A cart can only hold items from one restaurant at a time — the backend's
/// CreateOrderRequest takes a single restaurantId. Adding from a different
/// restaurant replaces the cart; callers should confirm with the user first
/// via [belongsToDifferentRestaurant].
class CartController extends ChangeNotifier {
  /// The backend rejects an order line above this (OrderItemRequest's
  /// Range(max: 100)), so the cart never lets one grow past it.
  static const maxQuantityPerProduct = 100;

  static String lineKey(int productId, String? optionName) =>
      optionName == null ? '$productId' : '$productId|$optionName';

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
  }) {
    if (belongsToDifferentRestaurant(product.restaurantId)) {
      _lines.clear();
    }
    _restaurantId = product.restaurantId;
    _restaurantName = restaurantName;

    final key = lineKey(product.id, option?.name);
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
