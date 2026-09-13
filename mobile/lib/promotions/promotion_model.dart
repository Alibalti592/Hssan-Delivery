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

  /// A short "-10%" / "-5 DT" label for the promotion card, matching the
  /// two discount types the backend supports (see App\Enum\DiscountType).
  String get discountLabel =>
      discountType == 'PERCENTAGE' ? '-$discountValue%' : '-$discountValue DT';

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
    );
  }
}
