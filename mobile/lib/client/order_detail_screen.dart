import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../addresses/route_map.dart';
import '../bills/bill_widgets.dart';
import '../core/api_exception.dart';
import '../deliveries/delivery.dart';
import '../orders/delivery_speed.dart';
import '../orders/courier_position.dart';
import '../orders/order_models.dart';
import '../orders/order_tracking.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import '../widgets/cash_payment_note.dart';
import '../widgets/order_status_chip.dart';
import 'reorder_action.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  ClientOrder? _order;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription<int>? _pushes;

  /// The courier on the map, while they're on this order.
  CourierPosition? _courier;
  Timer? _courierTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // A push about this order: show the new status now, not at the next poll.
    _pushes = context
        .read<OrdersRepository>()
        .changes
        .where((id) => id == widget.orderId)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _courierTimer?.cancel();
    _pollTimer?.cancel();
    _pushes?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final order = await context.read<OrdersRepository>().getOrder(
        widget.orderId,
      );
      if (!mounted) return;
      final statusChanged =
          _order != null && _order!.deliveryStatus != order.deliveryStatus;
      setState(() {
        _order = order;
        _error = null;
      });
      _scheduleNextPoll(order);
      _followCourier(order, statusChanged: statusChanged);
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The backend only pushes a notification for two of the six order
  /// transitions (see DeliveryNotificationListener) — polling covers the
  /// rest (confirmed/preparing/ready-for-pickup) without needing a
  /// websocket. Stops once the order reaches a terminal status.
  void _scheduleNextPoll(ClientOrder order) {
    _pollTimer?.cancel();
    if (order.status.isTerminal) return;
    _pollTimer = Timer(const Duration(seconds: 15), () => _load(silent: true));
  }

  /// From the courier accepting until delivery: where they are, every 10 s
  /// — and at once when the status changes, since the courier's app reports
  /// its position as they tap it (once more a few seconds later, for a slow
  /// GPS fix).
  static bool _courierOnTheJob(ClientOrder order) => const {
    DeliveryStatus.accepted,
    DeliveryStatus.pickedUp,
    DeliveryStatus.onTheWay,
  }.contains(order.deliveryStatus);

  /// Heading to the client, in any service, with a recent position: the
  /// map moves the courier slowly towards them between two positions.
  static bool _comingToClient(ClientOrder order, CourierPosition? courier) {
    final at = courier?.updatedAt;
    return courierHeadsToClient(order) &&
        at != null &&
        DateTime.now().difference(at) < creepLasts;
  }

  void _followCourier(ClientOrder order, {bool statusChanged = false}) {
    if (!_courierOnTheJob(order)) {
      _courierTimer?.cancel();
      _courierTimer = null;
      if (_courier != null) setState(() => _courier = null);
      return;
    }
    if (_courierTimer != null) {
      if (statusChanged) {
        _fetchCourier();
        Timer(const Duration(seconds: 4), () {
          if (mounted) _fetchCourier();
        });
      }
      return;
    }
    _fetchCourier();
    _courierTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchCourier(),
    );
  }

  Future<void> _fetchCourier() async {
    try {
      final position = await context.read<OrdersRepository>().courierPosition(
        widget.orderId,
      );
      if (mounted) setState(() => _courier = position);
    } on ApiException {
      // Next time; the order itself still shows.
    } on NetworkException {
      // Same.
    }
  }

  Future<void> _confirmCancel() async {
    final order = _order;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await context.read<OrdersRepository>().cancelOrder(
        order.id,
      );
      if (!mounted) return;
      setState(() => _order = updated);
      _scheduleNextPoll(updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d\'appeler $phone')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.orderId}')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _order == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _order == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Impossible de charger cette commande.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _load(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final order = _order!;
    final tracking = order.status != OrderStatus.cancelled;
    // A bill's courier collects and returns to the same door: one pin.
    final pickup = order.isBill ? null : order.pickupPoint;
    final dropOff = order.deliveryPoint;
    final courier = _courierOnTheJob(order) ? _courier : null;
    final heading = _headingTo(order, pickup, dropOff);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: Column(
        children: [
          // The client's map: their address and, once on the job, the
          // courier heading to it — nothing else.
          if (tracking && RouteMap.canShow(null, dropOff))
            RouteMap(
              dropOff: dropOff,
              courier: courier?.point,
              heading: courier == null ? null : dropOff,
              creepToward: _comingToClient(order, courier) ? dropOff : null,
              height: courier != null ? 300 : 200,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_courierOnTheJob(order)) ...[
                  _CourierProgress(
                    order: order,
                    courier: courier,
                    heading: heading,
                    goingToPickup: heading != null && heading == pickup,
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Icon(order.serviceIcon, color: navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        order.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrderStatusChip(
                      order.status,
                      label: orderStatusText(order),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DeliverySpeedLine(order.speed),
                ),
                const SizedBox(height: 16),
                if (tracking) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: _StatusTimeline(order: order),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (order.courierName != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.delivery_dining_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              order.courierName!,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          if (order.courierPhone != null &&
                              order.courierPhone!.isNotEmpty)
                            OutlinedButton.icon(
                              // The theme's full-width minimum would
                              // squeeze the courier's name to one letter a
                              // line next to it.
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () => _call(order.courierPhone!),
                              icon: const Icon(Icons.phone, size: 18),
                              label: const Text('Appeler'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (order.bill != null) ...[
                  BillDetailsCard(
                    bill: order.bill!,
                    recipientName: order.recipientName,
                    recipientPhone: order.recipientPhone,
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.isParcel && order.pickupAddress != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.pickupAddress!)),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(order.deliveryAddress)),
                          ],
                        ),
                        if (order.isParcel && order.recipientName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.recipientPhone != null &&
                                          order.recipientPhone!.isNotEmpty
                                      ? '${order.recipientName} · ${order.recipientPhone}'
                                      : order.recipientName!,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(order.deliveryZoneName),
                          ],
                        ),
                        if (order.note != null && order.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.note!)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  order.isParcel || order.isBill ? 'Récapitulatif' : 'Articles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Text('${item.quantity}x '),
                              Expanded(child: Text(item.displayName)),
                              Text('${item.unitPrice} DT'),
                            ],
                          ),
                        ),
                      if (order.bill != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order.bill!.isTransfer
                                    ? 'Montant du mandat'
                                    : 'Montant de la facture',
                              ),
                              Text('${order.bill!.amount} DT'),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      if (order.hasDiscount)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_offer_outlined,
                                size: 16,
                                color: successText,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  order.promotionTitle ?? 'Réduction',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: successText),
                                ),
                              ),
                              Text(
                                '-${order.discountAmount} DT',
                                style: const TextStyle(
                                  color: successText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Frais de livraison'),
                            Text('${order.deliveryFee} DT'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${order.totalAmount} DT',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      CashPaymentNote(
                        cardFooter: true,
                        text: order.isBill
                            ? 'Paiement en espèces, à remettre au livreur'
                            : 'Paiement en espèces à la livraison',
                      ),
                    ],
                  ),
                ),
                if (order.status == OrderStatus.completed &&
                    order.isFromCatalogue) ...[
                  const SizedBox(height: 16),
                  ReorderButton(order: order),
                ],
                if (order.canCancel) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _cancelling ? null : _confirmCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dangerText,
                    ),
                    child: _cancelling
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Annuler la commande'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The order's progress in its service's own words (see trackingSteps) —
/// the backend doesn't record a time per step, so none is invented here.
/// Where the courier is going next: the pickup until they've collected,
/// then the client. A bill's courier collects at the client's door, pays at
/// the counter (no pin), then comes back.
LatLng? _headingTo(ClientOrder order, LatLng? pickup, LatLng? dropOff) {
  switch (order.deliveryStatus) {
    case DeliveryStatus.accepted:
      return pickup ?? dropOff;
    case DeliveryStatus.pickedUp:
      return order.isBill ? null : dropOff;
    case DeliveryStatus.onTheWay:
      return dropOff;
    default:
      return null;
  }
}

/// Under the map, while the courier is on the order: where they're going,
/// the order's steps as an amber bar, and "Arrivée estimée ≈ 5 min". The
/// pill says the map is live; the order's status chip is further down.
class _CourierProgress extends StatelessWidget {
  const _CourierProgress({
    required this.order,
    required this.courier,
    required this.heading,
    required this.goingToPickup,
  });

  final ClientOrder order;
  final CourierPosition? courier;
  final LatLng? heading;
  final bool goingToPickup;

  String get _title {
    if (order.isBill) {
      return switch (order.deliveryStatus) {
        DeliveryStatus.accepted => 'Votre livreur vient chez vous',
        DeliveryStatus.pickedUp => 'Votre livreur paie au guichet',
        _ => 'Votre livreur revient avec le reçu',
      };
    }
    return goingToPickup
        ? 'Votre livreur va chercher votre commande'
        : 'Votre livreur arrive';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final courier = this.courier;
    final heading = this.heading;
    final steps = trackingSteps(order);

    // No arrival time without a position or somewhere to go: one line.
    String? note;
    String? label;
    String? value;
    String? distance;
    if (courier == null) {
      note = 'Sa position s\'affichera sur la carte dans un instant.';
    } else if (heading == null) {
      note = 'Suivez-le sur la carte.';
    } else {
      final km = courier.distanceKmTo(heading);
      label = goingToPickup ? 'Au point de retrait dans' : 'Arrivée estimée';
      value = '≈ ${estimatedMinutes(km)} min';
      distance = formatDistance(km);
      final age = courier.updatedAt == null
          ? null
          : DateTime.now().difference(courier.updatedAt!).inMinutes;
      if (age != null && age >= 2) note = 'Position d\'il y a $age min';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: trackAmberBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'En direct',
                    style: TextStyle(
                      color: trackAmberText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: steps[i].isDone || steps[i].isCurrent
                            ? trackAmber
                            : const Color(0xFFE9ECF1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: navy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: value == null
                      ? Text(
                          note!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: mutedText,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label!,
                              style: textTheme.bodySmall?.copyWith(
                                color: mutedText,
                              ),
                            ),
                            Text(
                              value,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
                if (distance != null)
                  Text(
                    distance,
                    style: textTheme.bodyMedium?.copyWith(
                      color: mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            if (value != null && note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: textTheme.bodySmall?.copyWith(color: mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
    final steps = trackingSteps(order);
    final hint = trackingHint(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            label: steps[i].label,
            hint: steps[i].isCurrent ? hint : null,
            isDone: steps[i].isDone,
            isCurrent: steps[i].isCurrent,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final active = isDone || isCurrent;
    final dotColor = isCurrent ? warnText : (isDone ? successText : cardBorder);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: isDone ? 16 : 12,
                  height: isDone ? 16 : 12,
                  margin: EdgeInsets.all(isDone ? 0 : 2),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone ? successText : const Color(0xFFE6EAEF),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? navy : mutedText,
                      fontSize: 13,
                    ),
                  ),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        hint!,
                        style: const TextStyle(color: mutedText, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
