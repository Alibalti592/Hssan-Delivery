import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/orders/order_models.dart';
import 'package:mobile/orders/order_tracking.dart';

ClientOrder _order({
  String type = 'RESTAURANT',
  String status = 'PENDING',
  String? deliveryStatus,
  Map<String, dynamic>? bill,
}) => ClientOrder.fromJson({
  'id': 1,
  'restaurantId': type == 'RESTAURANT' ? 1 : null,
  'restaurantName': type == 'RESTAURANT' ? 'Pizza Roma' : null,
  'deliveryType': type,
  'status': status,
  'deliveryStatus': deliveryStatus,
  'bill': bill,
});

const _steg = {
  'providerId': 1,
  'providerName': 'STEG',
  'providerKind': 'BILL',
  'amount': '85.500',
  'reference': '123',
};

String? _current(ClientOrder order) =>
    trackingSteps(order).where((s) => s.isCurrent).firstOrNull?.label;

void main() {
  test('a bill is tracked as a bill, not as a meal', () {
    final order = _order(
      type: 'BILL',
      status: 'READY_FOR_PICKUP',
      deliveryStatus: 'ON_THE_WAY',
      bill: _steg,
    );

    expect(trackingSteps(order).map((s) => s.label), [
      'Demande envoyée',
      'Livreur en route vers vous',
      'Facture et argent remis au livreur',
      'Facture payée · reçu en route',
      'Reçu remis',
    ]);
    expect(_current(order), 'Facture payée · reçu en route');
    expect(order.title, 'Facture STEG');
  });

  test('a parcel follows the delivery, step by step', () {
    expect(
      _current(_order(type: 'PARCEL', deliveryStatus: 'PENDING')),
      'Demande envoyée',
    );
    expect(
      _current(_order(type: 'PARCEL', deliveryStatus: 'ACCEPTED')),
      'Livreur en route vers le colis',
    );
    expect(
      _current(_order(type: 'PARCEL', deliveryStatus: 'PICKED_UP')),
      'Colis récupéré',
    );
  });

  test('a delivered order has every step done', () {
    final steps = trackingSteps(
      _order(status: 'COMPLETED', deliveryStatus: 'DELIVERED'),
    );

    expect(steps.every((s) => s.isDone && !s.isCurrent), isTrue);
    expect(steps.last.label, 'Commande livrée');
  });

  test('a waiting order says a courier is being found', () {
    expect(
      trackingHint(_order(deliveryStatus: 'PENDING')),
      'Nous cherchons un livreur…',
    );
    expect(trackingHint(_order(deliveryStatus: 'ACCEPTED')), isNull);
  });

  test('the chip words a failed delivery apart from a cancellation', () {
    expect(
      orderStatusText(_order(status: 'CANCELLED', deliveryStatus: 'FAILED')),
      'Échouée',
    );
    expect(
      orderStatusText(_order(status: 'CANCELLED', deliveryStatus: 'CANCELLED')),
      'Annulée',
    );
    expect(
      orderStatusText(
        _order(status: 'READY_FOR_PICKUP', deliveryStatus: 'ON_THE_WAY'),
      ),
      'En cours',
    );
  });

  test('the courier is heading to the client, in every service', () {
    bool heads(String type, String deliveryStatus) => courierHeadsToClient(
      _order(
        type: type,
        deliveryStatus: deliveryStatus,
        bill: type == 'BILL' ? _steg : null,
      ),
    );

    // A meal, groceries, a parcel: once collected.
    for (final type in ['RESTAURANT', 'GROCERY', 'PARCEL']) {
      expect(heads(type, 'ACCEPTED'), isFalse, reason: type);
      expect(heads(type, 'PICKED_UP'), isTrue, reason: type);
      expect(heads(type, 'ON_THE_WAY'), isTrue, reason: type);
    }
    // A bill: on the way to collect it, and back with the receipt — not
    // at the counter.
    expect(heads('BILL', 'ACCEPTED'), isTrue);
    expect(heads('BILL', 'PICKED_UP'), isFalse);
    expect(heads('BILL', 'ON_THE_WAY'), isTrue);
    // Not before a courier is on it, nor once it's over.
    expect(heads('RESTAURANT', 'PENDING'), isFalse);
    expect(heads('RESTAURANT', 'DELIVERED'), isFalse);
  });
}
