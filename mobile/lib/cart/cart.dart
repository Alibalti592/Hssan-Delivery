import 'package:flutter/foundation.dart';

import '../catalogue/catalogue_models.dart';

class CartLine {
  CartLine({required this.product, required this.quantity});

  final Product product;
  int quantity;

  double get lineTotal => (double.tryParse(product.price) ?? 0) * quantity;
}

/// A cart can only hold items from one restaurant at a time — the backend's
/// CreateOrderRequest takes a single restaurantId. Adding from a different
/// restaurant replaces the cart; callers should confirm with the user first
/// via [belongsToDifferentRestaurant].
class CartController extends ChangeNotifier {
  int? _restaurantId;
  String? _restaurantName;
  final Map<int, CartLine> _lines = {};

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
  }) {
    if (belongsToDifferentRestaurant(product.restaurantId)) {
      _lines.clear();
    }
    _restaurantId = product.restaurantId;
    _restaurantName = restaurantName;

    final existing = _lines[product.id];
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _lines[product.id] = CartLine(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void increment(int productId) {
    _lines[productId]?.quantity++;
    notifyListeners();
  }

  void decrement(int productId) {
    final line = _lines[productId];
    if (line == null) return;

    if (line.quantity <= 1) {
      _lines.remove(productId);
    } else {
      line.quantity--;
    }

    if (_lines.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
    }
    notifyListeners();
  }

  int quantityOf(int productId) => _lines[productId]?.quantity ?? 0;

  void clear() {
    _lines.clear();
    _restaurantId = null;
    _restaurantName = null;
    notifyListeners();
  }
}
