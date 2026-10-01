import 'package:flutter/material.dart';

import '../orders/order_models.dart';
import '../orders/order_tracking.dart';

/// The order(s) on their way, at the top of the home screen: where the
/// latest one is, in its service's own words, with a tap to follow it.
class ActiveOrderBanner extends StatelessWidget {
  const ActiveOrderBanner({
    required this.orders,
    required this.onOpen,
    this.onSeeAll,
    super.key,
  });

  /// Orders still in progress, newest first. Shows nothing when empty.
  final List<ClientOrder> orders;
  final void Function(ClientOrder order) onOpen;

  /// "Voir mes commandes", shown when more than one order is in progress.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final order = orders.first;
    final steps = trackingSteps(order);
    final current = steps.indexWhere((s) => s.isCurrent);
    final others = orders.length - 1;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Material(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(order),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _LiveDot(),
                    const SizedBox(width: 8),
                    Text(
                      order.isBill || order.isParcel
                          ? 'DEMANDE EN COURS'
                          : 'COMMANDE EN COURS',
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF7EE2A8),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '#${order.id}',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        order.serviceIcon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current >= 0
                                ? steps[current].label
                                : orderStatusText(order),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _subtitle(order),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _Progress(steps: steps),
                ),
                if (others > 0) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.white12),
                  InkWell(
                    onTap: onSeeAll,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, right: 4),
                      child: Row(
                        children: [
                          Text(
                            others == 1
                                ? '+ 1 autre en cours'
                                : '+ $others autres en cours',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Voir mes commandes',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What it is and who's on it: "Pizza Roma · Livreur : Ahmed", or what
  /// happens next while nobody has taken it yet.
  static String _subtitle(ClientOrder order) {
    final courier = order.courierName;
    if (courier != null && courier.isNotEmpty) {
      return '${order.title} · Livreur : $courier';
    }
    final hint = trackingHint(order);
    return hint == null ? order.title : '${order.title} · $hint';
  }
}

/// A green "live" dot with a soft halo. Static on purpose: a looping
/// animation would keep the home screen repainting all the time.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF34C77B).withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF34C77B),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// One segment per tracking step: done in white, the current one half lit.
class _Progress extends StatelessWidget {
  const _Progress({required this.steps});

  final List<TrackingStep> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: steps[i].isDone
                    ? Colors.white
                    : steps[i].isCurrent
                    ? const Color(0xFF34C77B)
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
