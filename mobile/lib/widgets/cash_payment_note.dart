import 'package:flutter/material.dart';

import '../theme.dart';

/// "Paiement en espèces à la livraison": the app takes no online payment,
/// so say plainly how the client pays.
class CashPaymentNote extends StatelessWidget {
  const CashPaymentNote({
    this.text = 'Paiement en espèces à la livraison',
    this.cardFooter = false,
    super.key,
  });

  final String text;

  /// Drawn as the bottom strip of a card rather than a free-standing box.
  final bool cardFooter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: successBg,
        // A footer fits inside the card's 10px corners and 1px border.
        borderRadius: cardFooter
            ? const BorderRadius.vertical(bottom: Radius.circular(9))
            : BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: 18, color: successText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: successText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
