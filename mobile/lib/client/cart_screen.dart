import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/add_ons.dart';
import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import '../widgets/dark_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/quantity_stepper.dart';
import 'checkout_screen.dart';
import 'restaurants_screen.dart';

/// The cart's content — list + summary/checkout button — with no Scaffold or
/// header of its own, so it can be reused both as a pushed screen ([CartScreen])
/// and embedded directly as the "Panier" tab in [ClientHomeScreen].
class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    if (cart.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Votre panier est vide',
        detail: 'Choisissez un restaurant ou un magasin pour commencer.',
        actionLabel: 'Voir les restaurants',
        actionIcon: Icons.restaurant_menu,
        primaryAction: true,
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Restaurants')),
              body: const RestaurantsScreen(),
            ),
          ),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppPhoto(
                          line.product.photoUrl,
                          icon: Icons.restaurant_outlined,
                          width: 56,
                          height: 56,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.displayName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (line.extras.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                line.extrasLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: mutedText,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            QuantityStepper(
                              quantity: line.quantity,
                              removesAtOne: true,
                              onDecrement: () => cart.decrement(line.key),
                              onIncrement: () => cart.increment(line.key),
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
              if (cart.restaurantId case final restaurantId?)
                _CompleteOrder(
                  restaurantId: restaurantId,
                  restaurantName: cart.restaurantName ?? '',
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

/// "Complétez votre commande": the restaurant's drinks, sauces and
/// supplements not in the cart yet, one tap to add. Left out when it has
/// none (or they can't be loaded).
class _CompleteOrder extends StatefulWidget {
  const _CompleteOrder({
    required this.restaurantId,
    required this.restaurantName,
  });

  final int restaurantId;
  final String restaurantName;

  @override
  State<_CompleteOrder> createState() => _CompleteOrderState();
}

class _CompleteOrderState extends State<_CompleteOrder> {
  List<(AddOnKind, Product)> _addOns = const [];

  static const _max = 12;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CompleteOrder old) {
    super.didUpdateWidget(old);
    if (old.restaurantId != widget.restaurantId) _load();
  }

  Future<void> _load() async {
    final restaurantId = widget.restaurantId;
    try {
      final catalogue = context.read<CatalogueRepository>();
      final (categories, products) = await (
        catalogue.listCategories(restaurantId),
        catalogue.listProducts(restaurantId),
      ).wait;
      if (!mounted || restaurantId != widget.restaurantId) return;
      final groups = menuAddOns(categories: categories, products: products);
      // Drinks first: the extra most often forgotten.
      const order = [AddOnKind.drink, AddOnKind.sauce, AddOnKind.supplement];
      setState(() {
        _addOns = [
          for (final kind in order)
            for (final group in groups.where((g) => g.kind == kind))
              for (final product in group.products) (kind, product),
        ];
      });
    } catch (_) {
      // Best effort: the cart orders just as well without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final shown = _addOns
        .where((a) => cart.quantityOf(a.$2.id) == 0)
        .take(_max)
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complétez votre commande',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            'Boissons, sauces et suppléments du restaurant',
            style: TextStyle(fontSize: 12.5, color: mutedText),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final (kind, product) = shown[index];
                return _AddOnCard(
                  product: product,
                  kind: kind,
                  onAdd: () => cart.add(
                    product,
                    restaurantName: widget.restaurantName,
                    option: product.options.firstOrNull,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddOnCard extends StatelessWidget {
  const _AddOnCard({
    required this.product,
    required this.kind,
    required this.onAdd,
  });

  final Product product;
  final AddOnKind kind;
  final VoidCallback onAdd;

  IconData get _icon => switch (kind) {
    AddOnKind.drink => Icons.local_drink_outlined,
    AddOnKind.sauce => Icons.water_drop_outlined,
    AddOnKind.supplement => Icons.add_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorderOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 92,
                child: AppPhoto(product.photoUrl, icon: _icon, iconSize: 28),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${addOnPrice(product)} DT',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Ajouter ${product.name}',
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: navy,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
        // DarkHeader pads itself for the status bar.
        top: false,
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
