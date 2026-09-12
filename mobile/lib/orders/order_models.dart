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
  });

  final int productId;
  final String productName;
  final int quantity;
  final String unitPrice;

  factory OrderItemLine.fromJson(Map<String, dynamic> json) {
    return OrderItemLine(
      productId: json['productId'] as int? ?? 0,
      productName: json['productName'] as String? ?? 'Article',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: json['unitPrice'] as String? ?? '0.000',
    );
  }
}

class ClientOrder {
  ClientOrder({
    required this.id,
    required this.restaurantId,
    required this.items,
    required this.note,
    required this.deliveryAddress,
    required this.deliveryZoneId,
    required this.deliveryZoneName,
    required this.deliveryFee,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int restaurantId;
  final List<OrderItemLine> items;
  final String? note;
  final String deliveryAddress;
  final int deliveryZoneId;
  final String deliveryZoneName;
  final String deliveryFee;
  final String totalAmount;
  final OrderStatus status;
  final DateTime? createdAt;

  factory ClientOrder.fromJson(Map<String, dynamic> json) {
    return ClientOrder(
      id: json['id'] as int,
      restaurantId: json['restaurantId'] as int? ?? 0,
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((e) => OrderItemLine.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      note: json['note'] as String?,
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      deliveryZoneId: json['deliveryZoneId'] as int? ?? 0,
      deliveryZoneName: json['deliveryZoneName'] as String? ?? '',
      deliveryFee: json['deliveryFee'] as String? ?? '0.000',
      totalAmount: json['totalAmount'] as String? ?? '0.000',
      status: OrderStatus.fromWire(json['status'] as String? ?? 'PENDING'),
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
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
