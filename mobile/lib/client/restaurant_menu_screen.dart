import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import '../promotions/menu_promotions.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import '../widgets/empty_state.dart';
import '../widgets/quantity_stepper.dart';
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

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          restaurantName: widget.restaurant.name,
        ),
      ),
    );
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
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Impossible de charger le menu',
              detail: 'Vérifiez votre connexion internet.',
              actionLabel: 'Réessayer',
              onAction: () => setState(() {
                _future = _load();
              }),
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
              MenuPromotions(restaurantId: widget.restaurant.id),
              if (activeCategories.length > 1)
                SizedBox(
                  // Room for the chip's own height: at 44 the labels were
                  // cut off at the bottom.
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
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
                          // A product with sizes or extras is added from its
                          // detail screen, where they're chosen.
                          onAdd: product.needsChoosing
                              ? () => _openProduct(product)
                              : () => _addToCart(product),
                          onIncrement: () => cart.increment(
                            CartController.lineKey(product.id, null),
                          ),
                          onDecrement: () => cart.decrement(
                            CartController.lineKey(product.id, null),
                          ),
                          onTap: () => _openProduct(product),
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
    final textTheme = Theme.of(context).textTheme;
    // A product with sizes or extras is added from its own screen, so its
    // "+" opens it; another one goes straight to the cart, then shows − n +.
    final showStepper = quantity > 0 && !product.needsChoosing;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      product.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5B6472),
                        height: 1.35,
                      ),
                    ),
                  ],
                  // What can be added, so the "+" opening a screen isn't a
                  // surprise.
                  if (product.hasExtras) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${product.extraGroups.map((g) => g.name).join(' · ')} au choix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: mutedText),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    product.hasOptions
                        ? 'À partir de ${product.price} DT'
                        : '${product.price} DT',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  if (showStepper) ...[
                    const SizedBox(height: 8),
                    QuantityStepper(
                      quantity: quantity,
                      removesAtOne: true,
                      onDecrement: onDecrement,
                      onIncrement: onIncrement,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AppPhoto(
                        product.photoUrl,
                        icon: Icons.restaurant_outlined,
                        width: 96,
                        height: 96,
                        iconSize: 28,
                      ),
                    ),
                  ),
                  if (!showStepper)
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: _AddButton(
                        tooltip: product.needsChoosing ? 'Choisir' : 'Ajouter',
                        count: quantity,
                        onTap: onAdd,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round "+" on a dish's photo; with [count] of it already in the cart
/// (a dish with choices, added from its own screen), that number instead.
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.tooltip,
    required this.count,
    required this.onTap,
  });

  final String tooltip;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: navy,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 3),
        ),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: count > 0
                  ? Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    )
                  : const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
