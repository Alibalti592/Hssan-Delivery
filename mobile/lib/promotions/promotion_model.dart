import '../catalogue/catalogue_models.dart';

class Promotion {
  Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.photoUrl,
    required this.discountType,
    required this.discountValue,
    required this.promoCode,
    required this.restaurantId,
    required this.restaurantName,
    this.items = const [],
    this.productId,
  });

  final int id;
  final String title;
  final String? description;
  final String? photoUrl;
  final String discountType;
  final String discountValue;
  final String? promoCode;
  final int? restaurantId;
  final String? restaurantName;

  /// FIXED_PRICE offers only: what the offer includes, one line per item.
  final List<String> items;

  /// FIXED_PRICE offers only: the product the offer is ordered as.
  final int? productId;

  /// A bundle sold at a set price ("2 sandwiches + frites — 11 DT") that
  /// the customer can order straight away, rather than a discount banner.
  bool get isOffer =>
      discountType == 'FIXED_PRICE' &&
      productId != null &&
      restaurantId != null;

  /// A "-10%" / "-5 DT" promotion that takes money off an order (as
  /// opposed to an offer, which is a product of its own).
  bool get isDiscount => discountType != 'FIXED_PRICE';

  /// Whether it takes money off an order from this restaurant: its own,
  /// or every restaurant's when it has none.
  bool appliesTo(int restaurantId) =>
      isDiscount &&
      (this.restaurantId == null || this.restaurantId == restaurantId);

  bool get hasCode => promoCode != null && promoCode!.isNotEmpty;

  /// "-10 % sur votre commande", "-5 DT sur votre commande".
  String get discountSentence => '$discountLabel sur votre commande';

  /// For an offer, its price. Otherwise the short "-10%" / "-5 DT" label,
  /// matching the discount types the backend supports (see
  /// App\Enum\DiscountType).
  String get discountLabel => switch (discountType) {
    // The API sends "10.000"; a percentage reads as "-10%" / "-12.5%".
    'PERCENTAGE' => '-${_trimZeros(discountValue)}%',
    'FIXED_PRICE' => '$discountValue DT',
    _ => '-$discountValue DT',
  };

  static String _trimZeros(String value) =>
      value.contains('.') ? value.replaceFirst(RegExp(r'\.?0+$'), '') : value;

  /// The offer as the catalogue product it's ordered through, for the cart.
  /// Only meaningful when [isOffer].
  Product toProduct() => Product(
    id: productId!,
    name: title,
    description: items.isNotEmpty ? items.join(' • ') : description,
    price: discountValue,
    isAvailable: true,
    photoUrl: photoUrl,
    restaurantId: restaurantId!,
    // Menu grouping only; nothing in the cart or order reads it.
    categoryId: 0,
  );

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      photoUrl: json['photoUrl'] as String?,
      discountType: json['discountType'] as String? ?? 'PERCENTAGE',
      discountValue: json['discountValue'] as String? ?? '0',
      promoCode: json['promoCode'] as String?,
      restaurantId: json['restaurantId'] as int?,
      restaurantName: json['restaurantName'] as String?,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      productId: json['productId'] as int?,
    );
  }
}
