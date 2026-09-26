/// Which of the client home screen's services a Restaurant row belongs to
/// — a grocery store reuses the exact same Category/Product/Order flow as a
/// restaurant, just under a different label (see mobile HomeScreen's
/// "Courses" service and backend App\Enum\RestaurantType).
enum RestaurantType {
  restaurant('RESTAURANT'),
  grocery('GROCERY');

  const RestaurantType(this.wire);

  final String wire;

  static RestaurantType fromWire(String value) {
    return RestaurantType.values.firstWhere(
      (t) => t.wire == value,
      orElse: () => RestaurantType.restaurant,
    );
  }
}

class Restaurant {
  Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.isAvailable,
    required this.type,
    required this.photoUrl,
  });

  final int id;
  final String name;
  final String? description;
  final bool isAvailable;
  final RestaurantType type;
  final String? photoUrl;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? false,
      type: RestaurantType.fromWire(json['type'] as String? ?? 'RESTAURANT'),
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class MenuCategory {
  MenuCategory({
    required this.id,
    required this.name,
    required this.restaurantId,
  });

  final int id;
  final String name;
  final int restaurantId;

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      restaurantId: json['restaurantId'] as int,
    );
  }
}

/// A size/portion of a product ("M", "Familiale", "12 pièces"...) with its
/// own price.
class ProductOption {
  const ProductOption({required this.name, required this.price});

  final String name;
  final String price;

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      name: json['name'] as String? ?? '',
      price: json['price'] as String? ?? '0.000',
    );
  }
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.isAvailable,
    required this.photoUrl,
    required this.restaurantId,
    required this.categoryId,
    this.options = const [],
  });

  final int id;
  final String name;
  final String? description;
  final String price;
  final bool isAvailable;
  final String? photoUrl;
  final int restaurantId;
  final int categoryId;

  /// When non-empty, the customer must choose one and pays its price;
  /// [price] is then the cheapest option ("à partir de").
  final List<ProductOption> options;

  bool get hasOptions => options.isNotEmpty;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: json['price'] as String? ?? '0.000',
      isAvailable: json['isAvailable'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      restaurantId: json['restaurantId'] as int,
      categoryId: json['categoryId'] as int,
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((o) => ProductOption.fromJson(o as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
