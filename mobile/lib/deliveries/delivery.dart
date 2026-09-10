/// Delivery lifecycle, mirrors the backend `DeliveryStatus` enum.
enum DeliveryStatus {
  pending('PENDING', 'Pending'),
  assigned('ASSIGNED', 'Assigned'),
  accepted('ACCEPTED', 'Accepted'),
  pickedUp('PICKED_UP', 'Picked up'),
  onTheWay('ON_THE_WAY', 'On the way'),
  delivered('DELIVERED', 'Delivered'),
  cancelled('CANCELLED', 'Cancelled'),
  failed('FAILED', 'Failed');

  const DeliveryStatus(this.wire, this.label);

  final String wire;
  final String label;

  static DeliveryStatus fromWire(String value) {
    return DeliveryStatus.values.firstWhere(
      (s) => s.wire == value,
      orElse: () => DeliveryStatus.pending,
    );
  }

  bool get isTerminal =>
      this == delivered || this == cancelled || this == failed;

  bool get isActive => !isTerminal && this != pending;
}

/// A step a courier can take from the current status.
enum DeliveryAction {
  accept('accept', 'Accept'),
  pickup('pickup', 'Confirm pickup'),
  onTheWay('on-the-way', 'Start delivery'),
  delivered('delivered', 'Mark delivered'),
  fail('fail', 'Report a problem');

  const DeliveryAction(this.pathSegment, this.label);

  final String pathSegment;
  final String label;
}

/// Actions offered for a given status. The first entry is the primary step;
/// [DeliveryAction.fail] (when present) is the destructive fallback.
List<DeliveryAction> actionsFor(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.assigned:
      return const [DeliveryAction.accept];
    case DeliveryStatus.accepted:
      return const [DeliveryAction.pickup, DeliveryAction.fail];
    case DeliveryStatus.pickedUp:
      return const [DeliveryAction.onTheWay, DeliveryAction.fail];
    case DeliveryStatus.onTheWay:
      return const [DeliveryAction.delivered, DeliveryAction.fail];
    case DeliveryStatus.pending:
    case DeliveryStatus.delivered:
    case DeliveryStatus.cancelled:
    case DeliveryStatus.failed:
      return const [];
  }
}

class DeliveryItem {
  DeliveryItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final int quantity;
  final String unitPrice;

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      productName: json['productName'] as String? ?? 'Item',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: json['unitPrice'] as String? ?? '0.000',
    );
  }
}

class DeliveryOrder {
  DeliveryOrder({
    required this.id,
    required this.restaurantName,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.note,
    required this.deliveryFee,
    required this.totalAmount,
    required this.items,
  });

  final int id;
  final String restaurantName;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String? note;
  final String deliveryFee;
  final String totalAmount;
  final List<DeliveryItem> items;

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'] as int,
      restaurantName: json['restaurantName'] as String? ?? 'Restaurant',
      customerName: json['customerName'] as String? ?? 'Customer',
      customerPhone: json['customerPhone'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      note: json['note'] as String?,
      deliveryFee: json['deliveryFee'] as String? ?? '0.000',
      totalAmount: json['totalAmount'] as String? ?? '0.000',
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((e) => DeliveryItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class Delivery {
  Delivery({
    required this.id,
    required this.status,
    required this.courierId,
    required this.assignedAt,
    required this.acceptedAt,
    required this.pickedUpAt,
    required this.deliveredAt,
    required this.order,
  });

  final int id;
  final DeliveryStatus status;
  final int? courierId;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DeliveryOrder? order;

  List<DeliveryAction> get availableActions => actionsFor(status);

  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final order = json['order'];

    return Delivery(
      id: json['id'] as int,
      status: DeliveryStatus.fromWire(json['status'] as String),
      courierId: json['courierId'] as int?,
      assignedAt: _parseDate(json['assignedAt']),
      acceptedAt: _parseDate(json['acceptedAt']),
      pickedUpAt: _parseDate(json['pickedUpAt']),
      deliveredAt: _parseDate(json['deliveredAt']),
      order: order is Map<String, dynamic>
          ? DeliveryOrder.fromJson(order)
          : null,
    );
  }
}
