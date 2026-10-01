import '../deliveries/delivery.dart' show DeliveryStatus;
import 'order_models.dart';

/// One step of an order's progress, as the client sees it.
class TrackingStep {
  const TrackingStep(
    this.label, {
    required this.isDone,
    required this.isCurrent,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
}

/// How far along the delivery is, 0 (sent) to 4 (done). The order's own
/// status only mirrors the delivery's (backend DeliveryStatus::toOrderStatus),
/// so the delivery status is the finer-grained source.
int _progress(ClientOrder order) {
  switch (order.deliveryStatus) {
    case DeliveryStatus.pending:
      return 0;
    case DeliveryStatus.assigned:
    case DeliveryStatus.accepted:
      return 1;
    case DeliveryStatus.pickedUp:
      return 2;
    case DeliveryStatus.onTheWay:
      return 3;
    case DeliveryStatus.delivered:
      return 4;
    case DeliveryStatus.cancelled:
    case DeliveryStatus.failed:
    case null:
      break;
  }
  switch (order.status) {
    case OrderStatus.pending:
    case OrderStatus.cancelled:
      return 0;
    case OrderStatus.confirmed:
    case OrderStatus.preparing:
      return 1;
    case OrderStatus.readyForPickup:
      return 3;
    case OrderStatus.completed:
      return 4;
  }
}

/// The five steps for this kind of order: a meal goes restaurant → client,
/// a parcel pickup → recipient, and a bill client → counter → client.
List<String> _labels(ClientOrder order) {
  final bill = order.bill;
  if (bill != null) {
    return bill.isTransfer
        ? const [
            'Demande envoyée',
            'Livreur en route vers vous',
            'Argent remis au livreur',
            'Mandat envoyé · reçu en route',
            'Reçu remis',
          ]
        : const [
            'Demande envoyée',
            'Livreur en route vers vous',
            'Facture et argent remis au livreur',
            'Facture payée · reçu en route',
            'Reçu remis',
          ];
  }
  if (order.isParcel) {
    return const [
      'Demande envoyée',
      'Livreur en route vers le colis',
      'Colis récupéré',
      'En route vers le destinataire',
      'Colis livré',
    ];
  }
  return [
    'Commande envoyée',
    order.deliveryType == 'GROCERY'
        ? 'Livreur en route vers le magasin'
        : 'Livreur en route vers le restaurant',
    'Commande récupérée',
    'En route vers vous',
    'Commande livrée',
  ];
}

List<TrackingStep> trackingSteps(ClientOrder order) {
  final labels = _labels(order);
  final progress = _progress(order);
  final finished = order.status == OrderStatus.completed;

  return [
    for (var i = 0; i < labels.length; i++)
      TrackingStep(
        labels[i],
        isDone: finished || i < progress,
        isCurrent: !finished && i == progress,
      ),
  ];
}

/// A line under the current step, when there's something worth adding.
String? trackingHint(ClientOrder order) {
  if (order.status.isTerminal) return null;
  if (_progress(order) == 0) return 'Nous cherchons un livreur…';
  return null;
}

/// The status chip's word: finer than "Confirmée"/"Prête pour le retrait",
/// which don't mean much for a parcel or a bill.
String orderStatusText(ClientOrder order) {
  switch (order.status) {
    case OrderStatus.cancelled:
      return order.deliveryStatus == DeliveryStatus.failed
          ? 'Échouée'
          : 'Annulée';
    case OrderStatus.completed:
      return order.isBill ? 'Terminée' : 'Livrée';
    case OrderStatus.pending:
      return 'En attente';
    case OrderStatus.confirmed:
    case OrderStatus.preparing:
    case OrderStatus.readyForPickup:
      return 'En cours';
  }
}
