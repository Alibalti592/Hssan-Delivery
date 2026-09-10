import 'package:flutter/material.dart';

import '../orders/order_models.dart';
import '../theme.dart';

Color orderStatusColor(OrderStatus status, ColorScheme scheme) {
  switch (status) {
    case OrderStatus.completed:
      return const Color(0xFF2E7D52);
    case OrderStatus.cancelled:
      return scheme.error;
    case OrderStatus.preparing:
    case OrderStatus.readyForPickup:
      return navy;
    case OrderStatus.confirmed:
      return const Color(0xFFC98A2C);
    case OrderStatus.pending:
      return scheme.outline;
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
