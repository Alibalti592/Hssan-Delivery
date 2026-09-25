import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_models.dart';

Product _product() => Product(
  id: 1,
  name: 'Burger',
  description: null,
  price: '12.500',
  isAvailable: true,
  photoUrl: null,
  restaurantId: 7,
  categoryId: 3,
);

void main() {
  test('a line never exceeds the backend per-product limit', () {
    final cart = CartController();
    cart.add(_product(), restaurantName: 'R', quantity: 99);
    cart.increment(1);
    cart.increment(1);
    expect(cart.quantityOf(1), CartController.maxQuantityPerProduct);

    cart.add(_product(), restaurantName: 'R', quantity: 5);
    expect(cart.quantityOf(1), CartController.maxQuantityPerProduct);
  });
}
