import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/promotions/promotion_model.dart';

Promotion _promotion(String type, String value) => Promotion.fromJson({
  'id': 1,
  'title': 'Promo',
  'discountType': type,
  'discountValue': value,
});

void main() {
  test('a percentage label drops the API\'s trailing zeros', () {
    expect(_promotion('PERCENTAGE', '10.000').discountLabel, '-10%');
    expect(_promotion('PERCENTAGE', '12.500').discountLabel, '-12.5%');
    expect(_promotion('PERCENTAGE', '100.000').discountLabel, '-100%');
    expect(_promotion('PERCENTAGE', '10').discountLabel, '-10%');
  });

  test('amounts in DT keep their millimes', () {
    expect(_promotion('FIXED_AMOUNT', '5.000').discountLabel, '-5.000 DT');
    expect(_promotion('FIXED_PRICE', '11.000').discountLabel, '11.000 DT');
  });

  test('an offer is orderable only with its product and restaurant', () {
    final offer = Promotion.fromJson({
      'id': 7,
      'title': '2 Sandwiches Chawarma',
      'discountType': 'FIXED_PRICE',
      'discountValue': '11.000',
      'restaurantId': 4,
      'productId': 30,
      'items': ['Frites'],
    });

    expect(offer.isOffer, isTrue);
    expect(offer.toProduct().id, 30);
    expect(offer.toProduct().price, '11.000');
    expect(_promotion('FIXED_PRICE', '11.000').isOffer, isFalse);
  });
}
