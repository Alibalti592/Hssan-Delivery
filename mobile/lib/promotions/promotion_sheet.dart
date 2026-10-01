import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalogue/catalogue_models.dart';
import '../client/restaurant_menu_screen.dart';
import '../client/restaurants_screen.dart';
import '../theme.dart';
import 'promotion_model.dart';

/// A discount promotion's details: how much, where, and how to get it (by
/// itself, or with its code to copy), with a way to go and order.
Future<void> showPromotionSheet(BuildContext context, Promotion promotion) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PromotionSheet(promotion: promotion),
  );
}

class _PromotionSheet extends StatelessWidget {
  const _PromotionSheet({required this.promotion});

  final Promotion promotion;

  void _order(BuildContext context) {
    final navigator = Navigator.of(context)..pop();
    final restaurantId = promotion.restaurantId;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => restaurantId == null
            ? Scaffold(
                appBar: AppBar(title: const Text('Restaurants')),
                body: const RestaurantsScreen(),
              )
            : RestaurantMenuScreen(
                restaurant: Restaurant(
                  id: restaurantId,
                  name: promotion.restaurantName ?? '',
                  description: null,
                  isAvailable: true,
                  type: RestaurantType.restaurant,
                  photoUrl: null,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = promotion.description;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: successBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  promotion.discountLabel,
                  style: textTheme.headlineMedium?.copyWith(
                    color: successText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              promotion.title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: mutedText),
              ),
            ],
            const SizedBox(height: 20),
            _Fact(
              icon: Icons.storefront_outlined,
              text: promotion.restaurantName == null
                  ? 'Valable dans tous les restaurants et magasins'
                  : 'Valable chez ${promotion.restaurantName}',
            ),
            _Fact(
              icon: Icons.receipt_long_outlined,
              text: 'Sur les articles, hors frais de livraison',
            ),
            _Fact(
              icon: promotion.hasCode
                  ? Icons.keyboard_outlined
                  : Icons.auto_awesome_outlined,
              text: promotion.hasCode
                  ? 'Saisissez le code au moment de commander'
                  : 'Appliquée automatiquement au moment de commander',
            ),
            if (promotion.hasCode) ...[
              const SizedBox(height: 12),
              _CodeBox(code: promotion.promoCode!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _order(context),
              child: Text(
                promotion.restaurantId == null
                    ? 'VOIR LES RESTAURANTS'
                    : 'COMMANDER CHEZ ${(promotion.restaurantName ?? '').toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: mutedText),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// The code in a dashed-looking box with "Copier".
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFCCDB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Code $code copié')));
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copier'),
          ),
        ],
      ),
    );
  }
}
