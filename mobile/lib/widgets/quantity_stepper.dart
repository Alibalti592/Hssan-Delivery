import 'package:flutter/material.dart';

import '../theme.dart';

/// − 2 + in one pill, with buttons big enough for a thumb (40 px, 44 px
/// when [large]). With [removesAtOne], "−" on the last one shows a bin:
/// the line goes away rather than to zero.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    this.large = false,
    this.removesAtOne = false,
    super.key,
  });

  final int quantity;

  /// Null disables "−" (e.g. a quantity that can't go below 1).
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool large;
  final bool removesAtOne;

  @override
  Widget build(BuildContext context) {
    final size = large ? 44.0 : 40.0;
    final removing = removesAtOne && quantity <= 1;

    return Container(
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundButton(
            size: size,
            icon: removing ? Icons.delete_outline : Icons.remove,
            tooltip: removing ? 'Retirer' : 'Moins',
            onTap: onDecrement,
            filled: false,
          ),
          SizedBox(
            width: large ? 40 : 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: large ? 18 : 16,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
          ),
          _RoundButton(
            size: size,
            icon: Icons.add,
            tooltip: 'Plus',
            onTap: onIncrement,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.filled,
  });

  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background = filled
        ? (enabled ? navy : const Color(0xFFBDBDBD))
        : Colors.white;
    final foreground = filled
        ? Colors.white
        : (enabled ? navy : const Color(0xFFBDBDBD));

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: foreground),
          ),
        ),
      ),
    );
  }
}
