import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_photo.dart';
import 'add_ons.dart';
import 'catalogue_models.dart';

/// One of the restaurant's drinks, sauces or supplements as a card: its
/// photo, name and price, and a round "+". The cart's "Complétez votre
/// commande" and the dish page's "Envie d'un petit plus ?" show them in
/// the same row you swipe sideways.
class AddOnCard extends StatelessWidget {
  const AddOnCard({
    required this.product,
    required this.kind,
    required this.onAdd,
    this.picked = false,
    super.key,
  });

  final Product product;
  final AddOnKind kind;
  final VoidCallback onAdd;

  /// On the dish page, a tap picks it to go with the dish (and a second one
  /// drops it): outlined in black, with a tick instead of the "+".
  final bool picked;

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
          side: BorderSide(
            color: picked ? navy : cardBorderOf(context),
            width: picked ? 2 : 1,
          ),
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
                            label: picked
                                ? 'Retirer ${product.name}'
                                : 'Ajouter ${product.name}',
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: navy,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                picked ? Icons.check : Icons.add,
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
