import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/deliveries/delivery.dart';

void main() {
  group('DeliveryStatus', () {
    test('parses wire values and falls back to pending', () {
      expect(DeliveryStatus.fromWire('ON_THE_WAY'), DeliveryStatus.onTheWay);
      expect(DeliveryStatus.fromWire('NONSENSE'), DeliveryStatus.pending);
    });

    test('terminal / active classification', () {
      expect(DeliveryStatus.delivered.isTerminal, isTrue);
      expect(DeliveryStatus.failed.isTerminal, isTrue);
      expect(DeliveryStatus.cancelled.isTerminal, isTrue);
      expect(DeliveryStatus.onTheWay.isTerminal, isFalse);
      expect(DeliveryStatus.pending.isActive, isFalse);
      expect(DeliveryStatus.accepted.isActive, isTrue);
    });
  });

  group('actionsFor', () {
    test('assigned offers accept and decline', () {
      expect(actionsFor(DeliveryStatus.assigned), [
        DeliveryAction.accept,
        DeliveryAction.decline,
      ]);
    });

    test('mid-lifecycle offers a step plus fail', () {
      expect(actionsFor(DeliveryStatus.accepted), [
        DeliveryAction.pickup,
        DeliveryAction.fail,
      ]);
      expect(actionsFor(DeliveryStatus.pickedUp), [
        DeliveryAction.onTheWay,
        DeliveryAction.fail,
      ]);
      expect(actionsFor(DeliveryStatus.onTheWay), [
        DeliveryAction.delivered,
        DeliveryAction.fail,
      ]);
    });

    test('terminal and pending offer nothing', () {
      for (final s in [
        DeliveryStatus.pending,
        DeliveryStatus.delivered,
        DeliveryStatus.cancelled,
        DeliveryStatus.failed,
      ]) {
        expect(actionsFor(s), isEmpty);
      }
    });
  });

  group('Delivery.fromJson', () {
    test('reads the embedded order summary', () {
      final delivery = Delivery.fromJson({
        'id': 7,
        'status': 'ASSIGNED',
        'courierId': 3,
        'assignedAt': '2026-09-10T10:00:00+00:00',
        'acceptedAt': null,
        'pickedUpAt': null,
        'deliveredAt': null,
        'order': {
          'id': 42,
          'status': 'CONFIRMED',
          'restaurantName': 'Le Bon Burger',
          'customerName': 'Sami',
          'customerPhone': '22000001',
          'deliveryAddress': '12 Rue de la Corniche',
          'note': 'Ring twice',
          'deliveryFee': '4.000',
          'totalAmount': '29.000',
          'items': [
            {
              'productName': 'Classic Smash',
              'quantity': 2,
              'unitPrice': '12.500',
            },
          ],
        },
      });

      expect(delivery.id, 7);
      expect(delivery.status, DeliveryStatus.assigned);
      expect(delivery.assignedAt, isNotNull);
      expect(delivery.order, isNotNull);
      expect(delivery.order!.restaurantName, 'Le Bon Burger');
      expect(delivery.order!.deliveryAddress, '12 Rue de la Corniche');
      expect(delivery.order!.items.single.quantity, 2);
    });

    test('tolerates a missing order block', () {
      final delivery = Delivery.fromJson({
        'id': 1,
        'status': 'PENDING',
        'courierId': null,
      });
      expect(delivery.order, isNull);
      expect(delivery.availableActions, isEmpty);
    });
  });
}
