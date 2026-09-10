import 'package:flutter/material.dart';

import '../deliveries/delivery.dart';
import '../theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusBgColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
