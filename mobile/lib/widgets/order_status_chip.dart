import 'package:flutter/material.dart';

import '../orders/order_models.dart';
import '../theme.dart';

Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.completed:
      return successText;
    case OrderStatus.cancelled:
      return dangerText;
    case OrderStatus.preparing:
    case OrderStatus.readyForPickup:
    case OrderStatus.confirmed:
      return warnText;
    case OrderStatus.pending:
      return const Color(0xFF6B7787);
  }
}

Color orderStatusBgColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.completed:
      return successBg;
    case OrderStatus.cancelled:
      return dangerBg;
    case OrderStatus.preparing:
    case OrderStatus.readyForPickup:
    case OrderStatus.confirmed:
      return warnBg;
    case OrderStatus.pending:
      return const Color(0xFFEDF0F4);
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: orderStatusBgColor(status),
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
