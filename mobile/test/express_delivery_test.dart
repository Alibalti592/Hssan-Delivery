import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/deliveries/deliveries_controller.dart';
import 'package:mobile/deliveries/delivery_repository.dart';
import 'package:mobile/orders/delivery_speed.dart';

Map<String, dynamic> _delivery(int id, String speed, String assignedAt) => {
  'id': id,
  'status': 'ACCEPTED',
  'courierId': 3,
  'assignedAt': assignedAt,
  'order': {
    'id': 100 + id,
    'status': 'CONFIRMED',
    'deliverySpeed': speed,
    'items': [],
  },
};

void main() {
  test('an unknown or missing speed reads as standard', () {
    expect(DeliverySpeed.fromApi('EXPRESS'), DeliverySpeed.express);
    expect(DeliverySpeed.fromApi('STANDARD'), DeliverySpeed.standard);
    expect(DeliverySpeed.fromApi(null), DeliverySpeed.standard);
    expect(DeliverySpeed.express.extraFee, 1);
  });

  test(
    "the courier's express job comes first, even if assigned later",
    () async {
      final api = ApiClient(
        tokenProvider: () => 'jwt',
        onUnauthorized: () {},
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'items': [
                _delivery(1, 'STANDARD', '2026-10-14T10:05:00+00:00'),
                _delivery(2, 'EXPRESS', '2026-10-14T10:00:00+00:00'),
              ],
              'meta': {'page': 1, 'limit': 20, 'total': 2, 'pages': 1},
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final deliveries = DeliveriesController(DeliveryRepository(api));

      await deliveries.refresh();

      expect(deliveries.active.map((d) => d.id), [2, 1]);
      expect(deliveries.active.first.order!.speed, DeliverySpeed.express);
    },
  );
}
