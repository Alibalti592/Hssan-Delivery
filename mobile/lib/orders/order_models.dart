import '../deliveries/delivery.dart' show DeliveryStatus;

/// Client order lifecycle, mirrors the backend `OrderStatus` enum.
enum OrderStatus {
  pending('PENDING', 'En attente'),
  confirmed('CONFIRMED', 'Confirmée'),
  preparing('PREPARING', 'En préparation'),
  readyForPickup('READY_FOR_PICKUP', 'Prête pour le retrait'),
  completed('COMPLETED', 'Livrée'),
  cancelled('CANCELLED', 'Annulée');

  const OrderStatus(this.wire, this.label);

  final String wire;
  final String label;

  static OrderStatus fromWire(String value) {
    return OrderStatus.values.firstWhere(
      (s) => s.wire == value,
      orElse: () => OrderStatus.pending,
    );
  }

  bool get isTerminal => this == completed || this == cancelled;
}

class OrderItemLine {
  OrderItemLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.option,
  });

  final int productId;
  final String productName;
  final int quantity;
  final String unitPrice;

  /// The size/portion ordered ("Familiale"...), if the product had options.
  final String? option;

  String get displayName =>
      option == null ? productName : '$productName ($option)';

  factory OrderItemLine.fromJson(Map<String, dynamic> json) {
    return OrderItemLine(
      productId: json['productId'] as int? ?? 0,
      productName: json['productName'] as String? ?? 'Article',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: json['unitPrice'] as String? ?? '0.000',
      option: json['option'] as String?,
    );
  }
}

class ClientOrder {
  ClientOrder({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.note,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryZoneId,
    required this.deliveryZoneName,
    required this.deliveryFee,
    required this.totalAmount,
    required this.status,
    required this.deliveryType,
    required this.createdAt,
    required this.deliveryStatus,
    required this.courierName,
    required this.courierPhone,
  });

  final int id;

  /// Null for a Colis (parcel) order, which has no restaurant.
  final int? restaurantId;
  final String? restaurantName;
  final List<OrderItemLine> items;
  final String? note;

  /// Set only for a Colis order — where the courier collects the package.
  final String? pickupAddress;
  final String deliveryAddress;

  /// Set only for a Colis order — who receives it at deliveryAddress.
  final String? recipientName;
  final String? recipientPhone;
  final int deliveryZoneId;
  final String deliveryZoneName;
  final String deliveryFee;
  final String totalAmount;
  final OrderStatus status;

  /// Which of the client home screen's four services this order belongs to
  /// (see mobile HomeScreen) — 'RESTAURANT', 'BILL', 'GROCERY', or 'PARCEL'.
  final String deliveryType;
  final DateTime? createdAt;
  final DeliveryStatus? deliveryStatus;
  final String? courierName;
  final String? courierPhone;

  bool get isParcel => deliveryType == 'PARCEL';

  /// A client can back out while the delivery is unclaimed or just assigned,
  /// but not once a courier has actually accepted it — mirrors the backend's
  /// own DeliveryService::cancelDelivery restriction, see OrdersRepository.cancelOrder.
  bool get canCancel =>
      deliveryStatus == DeliveryStatus.pending ||
      deliveryStatus == DeliveryStatus.assigned;

  factory ClientOrder.fromJson(Map<String, dynamic> json) {
    return ClientOrder(
      id: json['id'] as int,
      restaurantId: json['restaurantId'] as int?,
      restaurantName: json['restaurantName'] as String?,
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((e) => OrderItemLine.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      note: json['note'] as String?,
      pickupAddress: json['pickupAddress'] as String?,
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      deliveryZoneId: json['deliveryZoneId'] as int? ?? 0,
      deliveryZoneName: json['deliveryZoneName'] as String? ?? '',
      deliveryFee: json['deliveryFee'] as String? ?? '0.000',
      totalAmount: json['totalAmount'] as String? ?? '0.000',
      status: OrderStatus.fromWire(json['status'] as String? ?? 'PENDING'),
      deliveryType: json['deliveryType'] as String? ?? 'RESTAURANT',
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      deliveryStatus: json['deliveryStatus'] is String
          ? DeliveryStatus.fromWire(json['deliveryStatus'] as String)
          : null,
      courierName: json['courierName'] as String?,
      courierPhone: json['courierPhone'] as String?,
    );
  }
}

class DeliveryZoneOption {
  DeliveryZoneOption({required this.id, required this.name, required this.fee});

  final int id;
  final String name;
  final String fee;

  factory DeliveryZoneOption.fromJson(Map<String, dynamic> json) {
    return DeliveryZoneOption(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      fee: json['fee'] as String? ?? '0.000',
    );
  }
}
