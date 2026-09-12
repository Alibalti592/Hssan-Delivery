import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import '../theme.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  const RestaurantMenuScreen({required this.restaurant, super.key});

  final Restaurant restaurant;

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  late Future<(List<MenuCategory>, List<Product>)> _future;
  int? _selectedCategoryId;

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
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
              if (!cart.isEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: dangerText,
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
          final activeCategories = categories
              .where((c) => byCategory[c.id]?.isNotEmpty ?? false)
              .toList(growable: false);

          final visibleCategories = _selectedCategoryId == null
              ? activeCategories
              : activeCategories.where((c) => c.id == _selectedCategoryId);

          return Column(
            children: [
              if (activeCategories.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        selected: _selectedCategoryId == null,
                        onTap: () => setState(() => _selectedCategoryId = null),
                      ),
                      for (final category in activeCategories)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _FilterChip(
                            label: category.name,
                            selected: _selectedCategoryId == category.id,
                            onTap: () => setState(
                              () => _selectedCategoryId = category.id,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    for (final category in visibleCategories) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 8),
                        child: Text(
                          category.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                        ),
                      ),
                      for (final product in byCategory[category.id]!)
                        _ProductRow(
                          product: product,
                          quantity: cart.quantityOf(product.id),
                          onAdd: () => _addToCart(product),
                          onIncrement: () => cart.increment(product.id),
                          onDecrement: () => cart.decrement(product.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                product: product,
                                restaurantName: widget.restaurant.name,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
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
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                  child: Text(
                    'VOIR LE PANIER · ${cart.itemCount} ARTICLE(S) · '
                    '${cart.subtotal.toStringAsFixed(3)} DT',
                  ),
                ),
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? navy : fieldFill,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6B7787),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    required this.onTap,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: product.photoUrl != null
                  ? Image.network(
                      product.photoUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      color: fieldFill,
                      child: const Icon(
                        Icons.restaurant_outlined,
                        size: 18,
                        color: Color(0xFF9FB0C4),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                  const SizedBox(height: 4),
                  Text(
                    '${product.price} DT',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            quantity == 0
                ? OutlinedButton(
                    onPressed: onAdd,
                    // The app-wide OutlinedButtonTheme sets minimumSize to
                    // Size.fromHeight, i.e. an infinite width — fine for a
                    // full-width Column button, but this one sits beside an
                    // Expanded sibling in a Row, so it needs its own compact
                    // bound or it swallows the row and starves the sibling.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('AJOUTER'),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QtyButton(icon: Icons.remove, onTap: onDecrement),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$quantity',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _QtyButton(icon: Icons.add, onTap: onIncrement),
                    ],
                  ),
          ],
        ),
      ),
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
