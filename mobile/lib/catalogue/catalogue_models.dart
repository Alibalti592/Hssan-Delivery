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

/// What a restaurant serves, for browsing: "Pizza", "Sucré", "Cuisine
/// Tunisienne"... The client filters the restaurant list by one, and a
/// restaurant can have several. Managed from the admin dashboard — not to
/// be confused with [MenuCategory], a section of one restaurant's menu.
class RestaurantCategory {
  const RestaurantCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.imageUrl,
  });

  final int id;
  final String name;

  /// Which icon to draw for it (see CategoryIcon), when it has no image.
  final String icon;

  /// The admin's own image for it, shown instead of the icon.
  final String? imageUrl;

  factory RestaurantCategory.fromJson(Map<String, dynamic> json) {
    return RestaurantCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
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
    this.categories = const [],
  });

  final int id;
  final String name;
  final String? description;
  final bool isAvailable;
  final RestaurantType type;
  final String? photoUrl;

  /// What it serves, in the admin's order; empty when it has none (or the
  /// server is older than this app).
  final List<RestaurantCategory> categories;

  bool hasCategory(int categoryId) => categories.any((c) => c.id == categoryId);

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? false,
      type: RestaurantType.fromWire(json['type'] as String? ?? 'RESTAURANT'),
      photoUrl: json['photoUrl'] as String?,
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((e) => RestaurantCategory.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
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

/// One thing the customer can add to a product: "Harissa", "Fromage",
/// "Coca-Cola"... and what it adds to the price ("0.000" when free).
class ProductExtraChoice {
  const ProductExtraChoice({required this.name, required this.price});

  final String name;
  final String price;

  bool get isFree => (double.tryParse(price) ?? 0) == 0;

  factory ProductExtraChoice.fromJson(Map<String, dynamic> json) {
    return ProductExtraChoice(
      name: json['name'] as String? ?? '',
      price: json['price'] as String? ?? '0.000',
    );
  }
}

/// Things the customer can add to a product when ordering: "Sauces",
/// "Suppléments", "Boisson"... Either one pick or several ([multiple]), and
/// optional or not ([required]).
class ProductExtraGroup {
  const ProductExtraGroup({
    required this.name,
    required this.required,
    required this.multiple,
    required this.choices,
  });

  final String name;
  final bool required;
  final bool multiple;
  final List<ProductExtraChoice> choices;

  factory ProductExtraGroup.fromJson(Map<String, dynamic> json) {
    return ProductExtraGroup(
      name: json['name'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      multiple: json['multiple'] as bool? ?? true,
      choices: (json['choices'] as List<dynamic>? ?? const [])
          .map((c) => ProductExtraChoice.fromJson(c as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// An extra the customer picked, as it goes in the cart and the order:
/// "Harissa" from "Sauces", with its price at the time.
class PickedExtra {
  const PickedExtra({
    required this.group,
    required this.name,
    required this.price,
  });

  final String group;
  final String name;
  final String price;

  factory PickedExtra.fromJson(Map<String, dynamic> json) {
    return PickedExtra(
      group: json['group'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: json['price'] as String? ?? '0.000',
    );
  }

  /// Read from an order or a delivery: an older server has no `extras`.
  static List<PickedExtra> listFrom(Object? json) =>
      (json as List<dynamic>? ?? const [])
          .map((e) => PickedExtra.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

  /// "Sauces : Harissa, Mayonnaise · Boisson : Coca-Cola", group by group
  /// in the order they come; empty for none.
  static String describe(List<PickedExtra> extras) {
    final groups = <String, List<String>>{};
    for (final extra in extras) {
      groups.putIfAbsent(extra.group, () => []).add(extra.name);
    }
    return groups.entries
        .map((g) => '${g.key} : ${g.value.join(', ')}')
        .join(' · ');
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
    this.extraGroups = const [],
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

  /// What the customer can add when ordering (sauces, extras, a drink...).
  final List<ProductExtraGroup> extraGroups;

  bool get hasExtras => extraGroups.isNotEmpty;

  /// Added from its own screen, where a size or extras are picked, rather
  /// than straight from the menu.
  bool get needsChoosing => hasOptions || hasExtras;

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
      extraGroups: (json['extraGroups'] as List<dynamic>? ?? const [])
          .map((g) => ProductExtraGroup.fromJson(g as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// A dish found by search, with the place that sells it.
class DishResult {
  const DishResult({required this.product, required this.restaurant});

  final Product product;
  final Restaurant restaurant;

  factory DishResult.fromJson(Map<String, dynamic> json) {
    return DishResult(
      product: Product.fromJson(json),
      restaurant: Restaurant.fromJson(
        json['restaurant'] as Map<String, dynamic>,
      ),
    );
  }
}

/// What "Rechercher un plat, un restaurant" found.
class SearchResults {
  const SearchResults({required this.restaurants, required this.dishes});

  static const empty = SearchResults(restaurants: [], dishes: []);

  final List<Restaurant> restaurants;
  final List<DishResult> dishes;

  bool get isEmpty => restaurants.isEmpty && dishes.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      restaurants: (json['restaurants'] as List<dynamic>? ?? const [])
          .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      dishes: (json['products'] as List<dynamic>? ?? const [])
          .map((e) => DishResult.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
