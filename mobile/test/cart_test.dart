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
    cart.increment('1');
    cart.increment('1');
    expect(cart.quantityOf(1), CartController.maxQuantityPerProduct);

    cart.add(_product(), restaurantName: 'R', quantity: 5);
    expect(cart.quantityOf(1), CartController.maxQuantityPerProduct);
  });

  test('each size of a product is its own line, priced by that size', () {
    final pizza = Product(
      id: 2,
      name: 'Pizza',
      description: null,
      price: '12.000',
      isAvailable: true,
      photoUrl: null,
      restaurantId: 7,
      categoryId: 3,
      options: const [
        ProductOption(name: 'M', price: '12.000'),
        ProductOption(name: 'Familiale', price: '22.000'),
      ],
    );
    final cart = CartController();

    cart.add(pizza, restaurantName: 'R', option: pizza.options[1], quantity: 2);
    cart.add(pizza, restaurantName: 'R', option: pizza.options[0]);

    expect(cart.lines.map((l) => l.displayName), [
      'Pizza (Familiale)',
      'Pizza (M)',
    ]);
    expect(cart.quantityOf(2), 3);
    expect(cart.subtotal, 56.0);

    cart.decrement(CartController.lineKey(2, 'M'));
    expect(cart.lines.single.displayName, 'Pizza (Familiale)');
  });
}
