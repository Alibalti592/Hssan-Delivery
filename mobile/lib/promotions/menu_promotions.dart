import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import 'promotion_model.dart';
import 'promotion_sheet.dart';
import 'promotions_repository.dart';

/// At the top of a menu: the promotions that take money off an order here
/// ("-10 % sur votre commande", "Code BIENVENUE · -5 DT"). Nothing at all
/// when there are none or they can't be loaded.
class MenuPromotions extends StatefulWidget {
  const MenuPromotions({required this.restaurantId, super.key});

  final int restaurantId;

  @override
  State<MenuPromotions> createState() => _MenuPromotionsState();
}

class _MenuPromotionsState extends State<MenuPromotions> {
  List<Promotion> _promotions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await context.read<PromotionsRepository>().listActive();
      if (!mounted) return;
      setState(() {
        _promotions = all
            .where((p) => p.appliesTo(widget.restaurantId))
            .toList(growable: false);
      });
    } catch (_) {
      // A nicety: the menu works the same without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_promotions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: _promotions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) =>
            _PromotionChip(promotion: _promotions[index]),
      ),
    );
  }
}

class _PromotionChip extends StatelessWidget {
  const _PromotionChip({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: successBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showPromotionSheet(context, promotion),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: successText,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promotion.discountSentence,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: successText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      promotion.hasCode
                          ? 'Avec le code ${promotion.promoCode}'
                          : 'Appliquée automatiquement',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: successText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
