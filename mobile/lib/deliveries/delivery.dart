/// Delivery lifecycle, mirrors the backend `DeliveryStatus` enum.
enum DeliveryStatus {
  pending('PENDING', 'En attente'),
  assigned('ASSIGNED', 'Nouvelle'),
  accepted('ACCEPTED', 'Acceptée'),
  pickedUp('PICKED_UP', 'Récupérée'),
  onTheWay('ON_THE_WAY', 'En route'),
  delivered('DELIVERED', 'Livrée'),
  cancelled('CANCELLED', 'Annulée'),
  failed('FAILED', 'Échouée');

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
  accept('accept', 'Accepter'),
  decline('decline', 'Refuser'),
  pickup('pickup', 'Confirmer la récupération'),
  onTheWay('on-the-way', 'Démarrer la course'),
  delivered('delivered', 'Confirmer la livraison'),
  fail('fail', 'Signaler un problème');

  const DeliveryAction(this.pathSegment, this.label);

  final String pathSegment;
  final String label;

  /// Destructive actions get a red outline and a confirmation dialog.
  bool get isDestructive => this == fail || this == decline;
}

/// Actions offered for a given status. The first entry is the primary step;
/// a trailing destructive action (when present) is the secondary/fallback.
List<DeliveryAction> actionsFor(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.assigned:
      return const [DeliveryAction.accept, DeliveryAction.decline];
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
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.recipientName,
    required this.recipientPhone,
    required this.note,
    required this.deliveryFee,
    required this.totalAmount,
    required this.deliveryType,
    required this.items,
  });

  final int id;

  /// Null for a Colis (parcel) job — see pickupAddress instead.
  final String? restaurantName;
  final String customerName;
  final String customerPhone;

  /// Set only for a Colis job — where the courier collects the package.
  final String? pickupAddress;
  final String deliveryAddress;

  /// Set only for a Colis job — who the courier hands the package to.
  final String? recipientName;
  final String? recipientPhone;
  final String? note;
  final String deliveryFee;
  final String totalAmount;

  /// Which of the four client services this delivery is for — see
  /// ClientOrder.deliveryType.
  final String deliveryType;
  final List<DeliveryItem> items;

  bool get isParcel => deliveryType == 'PARCEL';

  /// Who the courier hands the delivery to — the recipient for a Colis
  /// job, the customer for everything else. Unifies the isParcel branch so
  /// callers (see delivery_detail_screen.dart) don't repeat it themselves.
  String get contactName => isParcel ? (recipientName ?? '') : customerName;
  String? get contactPhone => isParcel ? recipientPhone : customerPhone;

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'] as int,
      restaurantName: json['restaurantName'] as String?,
      customerName: json['customerName'] as String? ?? 'Customer',
      customerPhone: json['customerPhone'] as String? ?? '',
      pickupAddress: json['pickupAddress'] as String?,
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      note: json['note'] as String?,
      deliveryFee: json['deliveryFee'] as String? ?? '0.000',
      totalAmount: json['totalAmount'] as String? ?? '0.000',
      deliveryType: json['deliveryType'] as String? ?? 'RESTAURANT',
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
