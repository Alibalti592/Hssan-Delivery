import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
import '../theme.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.product,
    required this.restaurantName,
    super.key,
  });

  final Product product;
  final String restaurantName;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  Future<void> _addToCart() async {
    final cart = context.read<CartController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (cart.belongsToDifferentRestaurant(widget.product.restaurantId)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer le panier ?'),
          content: Text(
            'Votre panier contient des articles de ${cart.restaurantName}. '
            'L\'ajouter videra ce panier pour commencer une commande chez '
            '${widget.restaurantName}.',
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

    cart.add(
      widget.product,
      restaurantName: widget.restaurantName,
      quantity: _quantity,
    );
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${widget.product.name} ajouté au panier')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final total = (double.tryParse(product.price) ?? 0) * _quantity;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: product.photoUrl != null
                      ? Image.network(product.photoUrl!, fit: BoxFit.cover)
                      : Container(
                          color: fieldFill,
                          child: const Icon(
                            Icons.restaurant_outlined,
                            size: 48,
                            color: Color(0xFF9FB0C4),
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: navy),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _StepButton(
                              icon: Icons.remove,
                              onTap: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '$_quantity',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            _StepButton(
                              icon: Icons.add,
                              onTap: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                        Text(
                          '${total.toStringAsFixed(3)} DT',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _addToCart,
                  child: const Text('AJOUTER AU PANIER'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF2F4F7) : fieldFill,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? mutedText : const Color(0xFF4A5462),
        ),
      ),
    );
  }
}
