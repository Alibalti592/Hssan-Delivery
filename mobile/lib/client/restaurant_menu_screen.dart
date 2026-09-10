import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import 'cart_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  const RestaurantMenuScreen({required this.restaurant, super.key});

  final Restaurant restaurant;

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  late Future<(List<MenuCategory>, List<Product>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<MenuCategory>, List<Product>)> _load() async {
    final repository = context.read<CatalogueRepository>();
    final categories = await repository.listCategories(widget.restaurant.id);
    final products = await repository.listProducts(widget.restaurant.id);
    return (categories, products);
  }

  Future<void> _addToCart(Product product) async {
    final cart = context.read<CartController>();
    final messenger = ScaffoldMessenger.of(context);

    if (cart.belongsToDifferentRestaurant(product.restaurantId)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer le panier ?'),
          content: Text(
            'Votre panier contient des articles de ${cart.restaurantName}. '
            'L\'ajouter videra ce panier pour commencer une commande chez '
            '${widget.restaurant.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    cart.add(product, restaurantName: widget.restaurant.name);
    messenger.showSnackBar(
      SnackBar(content: Text('${product.name} ajouté au panier')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.name),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
              if (!cart.isEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<(List<MenuCategory>, List<Product>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Impossible de charger le menu.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          final (categories, products) = snapshot.data!;
          if (products.isEmpty) {
            return const Center(child: Text('Aucun produit disponible.'));
          }

          final byCategory = <int, List<Product>>{};
          for (final product in products) {
            byCategory.putIfAbsent(product.categoryId, () => []).add(product);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final category in categories)
                if (byCategory[category.id]?.isNotEmpty ?? false) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    child: Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final product in byCategory[category.id]!)
                    _ProductTile(
                      product: product,
                      quantity: cart.quantityOf(product.id),
                      onAdd: () => _addToCart(product),
                      onIncrement: () => cart.increment(product.id),
                      onDecrement: () => cart.decrement(product.id),
                    ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                  child: Text(
                    'Voir le panier (${cart.itemCount}) · '
                    '${cart.subtotal.toStringAsFixed(3)} DT',
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${product.price} DT',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            quantity == 0
                ? OutlinedButton(
                    onPressed: onAdd,
                    // The app-wide OutlinedButtonTheme sets minimumSize to
                    // Size.fromHeight, i.e. an infinite width — fine for a
                    // full-width Column button, but this one sits beside an
                    // Expanded sibling in a Row, so it needs its own compact
                    // bound or it swallows the row and starves the sibling.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Ajouter'),
                  )
                : Row(
                    children: [
                      IconButton(
                        onPressed: onDecrement,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: onIncrement,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
