import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart.dart';
import '../client/cart_screen.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import '../widgets/quantity_stepper.dart';
import 'promotion_model.dart';

/// A fixed-price offer ("2 Sandwiches Chawarma — 11 DT"): the full flyer,
/// what it includes, and a one-tap order. Ordering puts the offer's product
/// in the cart and goes straight to it, so checkout is the normal one.
class OfferScreen extends StatefulWidget {
  const OfferScreen({required this.offer, super.key});

  final Promotion offer;

  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  int _quantity = 1;

  Future<void> _order() async {
    final offer = widget.offer;
    final restaurantName = offer.restaurantName ?? '';
    final cart = context.read<CartController>();
    final navigator = Navigator.of(context);

    if (cart.belongsToDifferentRestaurant(offer.restaurantId!)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer le panier ?'),
          content: Text(
            'Votre panier contient des articles de ${cart.restaurantName}. '
            'Commander cette offre videra ce panier pour commencer une '
            'commande chez $restaurantName.',
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
      offer.toProduct(),
      restaurantName: restaurantName,
      quantity: _quantity,
    );
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final textTheme = Theme.of(context).textTheme;
    final total = (double.tryParse(offer.discountValue) ?? 0) * _quantity;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        // The whole flyer, never cropped: it's the ad.
                        AppPhoto(
                          offer.photoUrl,
                          icon: Icons.local_offer_outlined,
                          iconSize: 48,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
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
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    sliver: SliverList.list(
                      children: [
                        const OfferTag(),
                        const SizedBox(height: 10),
                        Text(
                          offer.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (offer.restaurantName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                size: 16,
                                color: mutedText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                offer.restaurantName!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: mutedText,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        _PriceBadge(price: offer.discountValue),
                        if (offer.description != null &&
                            offer.description!.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(offer.description!, style: textTheme.bodyMedium),
                        ],
                        if (offer.items.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: cardBorder),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ce qui est inclus',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                for (final item in offer.items) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        size: 20,
                                        color: successText,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: cardBorder)),
                ),
                child: Row(
                  children: [
                    QuantityStepper(
                      large: true,
                      quantity: _quantity,
                      onDecrement: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      onIncrement:
                          _quantity < CartController.maxQuantityPerProduct
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: _order,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'COMMANDER · ${total.toStringAsFixed(3)} DT',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "OFFRE SPÉCIALE" label, shared by the offer page and its home card.
class OfferTag extends StatelessWidget {
  const OfferTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: warnBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'OFFRE SPÉCIALE',
          style: TextStyle(
            color: warnText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$price DT',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
