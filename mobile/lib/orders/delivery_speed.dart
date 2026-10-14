import 'package:flutter/material.dart';

import '../theme.dart';

/// Standard (30–40 min) or express (15–20 min, 1 DT more). Express orders
/// go first: on top of the admin's queue, and a courier already on a
/// standard delivery can take one on top of it.
enum DeliverySpeed {
  standard('STANDARD', 'Standard', '30–40 min', 0),
  express('EXPRESS', 'Express', '15–20 min', 1);

  const DeliverySpeed(this.apiValue, this.label, this.eta, this.extraFee);

  final String apiValue;
  final String label;

  /// How long it takes, as the client is told.
  final String eta;

  /// What it adds to the zone's delivery fee, in DT.
  final double extraFee;

  bool get isExpress => this == DeliverySpeed.express;

  /// Unknown or missing (older orders): standard.
  static DeliverySpeed fromApi(String? value) =>
      value == express.apiValue ? express : standard;
}

/// The two speeds side by side; tap one to choose it.
class DeliverySpeedPicker extends StatelessWidget {
  const DeliverySpeedPicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final DeliverySpeed value;
  final ValueChanged<DeliverySpeed> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Livraison',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final speed in DeliverySpeed.values) ...[
              if (speed != DeliverySpeed.values.first)
                const SizedBox(width: 10),
              Expanded(
                child: _SpeedCard(
                  speed: speed,
                  selected: speed == value,
                  onTap: enabled ? () => onChanged(speed) : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final DeliverySpeed speed;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : navy;
    final sub = selected ? Colors.white70 : mutedText;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? navy : fieldFillOf(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      speed.isExpress
                          ? Icons.bolt_rounded
                          : Icons.schedule_rounded,
                      size: 18,
                      color: fg,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      speed.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: fg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  speed.eta,
                  style: TextStyle(fontWeight: FontWeight.w600, color: sub),
                ),
                const SizedBox(height: 2),
                Text(
                  speed.isExpress
                      ? '+${speed.extraFee.toStringAsFixed(3)} DT'
                      : 'Sans supplément',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: speed.isExpress && !selected ? warnText : sub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Livraison express · 15–20 min": what the client chose, on their order.
class DeliverySpeedLine extends StatelessWidget {
  const DeliverySpeedLine(this.speed, {super.key});

  final DeliverySpeed speed;

  @override
  Widget build(BuildContext context) {
    final color = speed.isExpress ? warnText : mutedText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          speed.isExpress ? Icons.bolt_rounded : Icons.schedule_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          'Livraison ${speed.label.toLowerCase()} · ${speed.eta}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// A small "Express" pill for order and delivery cards.
class ExpressBadge extends StatelessWidget {
  const ExpressBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warnBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: warnText),
          SizedBox(width: 2),
          Text(
            'Express',
            style: TextStyle(
              color: warnText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
