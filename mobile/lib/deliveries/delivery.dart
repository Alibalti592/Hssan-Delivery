import 'package:flutter/material.dart' show IconData, Icons;

import '../bills/bill_models.dart';

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

  /// The button's words for this job: what the courier just did, in the
  /// service's own terms ("Colis récupéré", "Facture payée, je rapporte le
  /// reçu"). Mirrors the client's tracking steps (orders/order_tracking.dart).
  String labelFor(DeliveryOrder? order) {
    if (order == null) return label;
    final bill = order.bill;
    switch (this) {
      case DeliveryAction.pickup:
        if (bill != null) {
          return bill.isTransfer
              ? "J'ai reçu l'argent du mandat"
              : "J'ai reçu la facture et l'argent";
        }
        if (order.isParcel) return 'Colis récupéré';
        if (order.deliveryType == 'GROCERY') return 'Courses récupérées';
        return 'Commande récupérée';
      case DeliveryAction.onTheWay:
        if (bill != null) {
          return bill.isTransfer
              ? 'Mandat envoyé, je rapporte le reçu'
              : 'Facture payée, je rapporte le reçu';
        }
        if (order.isParcel) return 'En route vers le destinataire';
        return 'En route vers le client';
      case DeliveryAction.delivered:
        if (bill != null) return 'Reçu remis au client';
        if (order.isParcel) return 'Colis remis au destinataire';
        if (order.deliveryType == 'GROCERY') return 'Courses livrées';
        return 'Commande livrée';
      case DeliveryAction.accept:
      case DeliveryAction.decline:
      case DeliveryAction.fail:
        return label;
    }
  }
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
    this.option,
  });

  final String productName;
  final int quantity;
  final String unitPrice;

  /// The size/portion ordered ("Familiale"...), if the product had options —
  /// what the courier must check they were handed at pickup.
  final String? option;

  String get displayName =>
      option == null ? productName : '$productName ($option)';

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      productName: json['productName'] as String? ?? 'Item',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: json['unitPrice'] as String? ?? '0.000',
      option: json['option'] as String?,
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
    this.bill,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
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

  /// Set only for a Factures job: the bill (or mandat) to pay at the
  /// provider's counter with the cash collected from the customer.
  final BillInfo? bill;

  /// The pins the client placed on the map, when they did — what "Ouvrir
  /// dans Maps" navigates to.
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  bool get hasPickupLocation =>
      pickupLatitude != null && pickupLongitude != null;

  bool get hasDeliveryLocation =>
      deliveryLatitude != null && deliveryLongitude != null;

  bool get isParcel => deliveryType == 'PARCEL';

  bool get isBill => bill != null;

  /// What the job is, in a word or two: the restaurant, "Colis",
  /// "Facture STEG", "Mandat Wafa Cash" (same words as ClientOrder.title).
  String get title {
    final bill = this.bill;
    if (bill != null) {
      return '${bill.isTransfer ? 'Mandat' : 'Facture'} ${bill.provider.name}';
    }
    if (isParcel) return 'Colis';
    final name = restaurantName;
    return name == null || name.isEmpty ? 'Course #$id' : name;
  }

  IconData get serviceIcon {
    if (isBill) return Icons.receipt_long_outlined;
    switch (deliveryType) {
      case 'PARCEL':
        return Icons.inventory_2_outlined;
      case 'GROCERY':
        return Icons.shopping_basket_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  /// The one line that matters after the address: what's in the bag, who
  /// gets the parcel, or how much the bill is.
  String get summary {
    final bill = this.bill;
    if (bill != null) return 'Montant : ${bill.amount} DT';
    if (isParcel) {
      final name = recipientName;
      return name == null || name.isEmpty ? 'Colis à livrer' : 'Pour $name';
    }
    final count = items.fold<int>(0, (sum, i) => sum + i.quantity);
    return '$count article${count > 1 ? 's' : ''} · $totalAmount DT';
  }

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
      bill: BillInfo.fromJson(json['bill']),
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
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
