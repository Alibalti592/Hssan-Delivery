import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../theme.dart';
import '../widgets/dark_header.dart';
import 'checkout_screen.dart';

/// The cart's content — list + summary/checkout button — with no Scaffold or
/// header of its own, so it can be reused both as a pushed screen ([CartScreen])
/// and embedded directly as the "Panier" tab in [ClientHomeScreen].
class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text('Votre panier est vide'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final line in cart.lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: cardBorder)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: fieldFill,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.product.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _QtyButton(
                                  icon: Icons.remove,
                                  onTap: () => cart.decrement(line.product.id),
                                ),
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${line.quantity}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                _QtyButton(
                                  icon: Icons.add,
                                  onTap: () => cart.increment(line.product.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${line.lineTotal.toStringAsFixed(3)} DT',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TotalRow(label: 'Sous-total', value: cart.subtotal),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                  ),
                  child: const Text('COMMANDER'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fieldFill,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF4A5462)),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          '${value.toStringAsFixed(3)} DT',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// Pushed variant of the cart, with a dark header + back button — reached
/// from [RestaurantMenuScreen]'s "Voir le panier" bar while browsing.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: 'Mon panier',
              subtitle: cart.restaurantName,
              onBack: () => Navigator.of(context).pop(),
            ),
            const Expanded(child: CartView()),
          ],
        ),
      ),
    );
  }
}
