import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/deliveries/deliveries_controller.dart';
import 'package:mobile/deliveries/delivery.dart';
import 'package:mobile/deliveries/delivery_repository.dart';

import 'widget/test_utils.dart';

Map<String, dynamic> _delivery(int id, {required String status}) => {
  'id': id,
  'status': status,
  'courierId': 3,
  'assignedAt': '2026-01-0${id}T08:00:00+00:00',
  'acceptedAt': null,
  'pickedUpAt': null,
  'deliveredAt': null,
  'order': {
    'id': 100 + id,
    'restaurantName': 'Restaurant $id',
    'customerName': 'Client',
    'customerPhone': '22000000',
    'deliveryAddress': '$id Rue de la Paix',
    'note': null,
    'deliveryFee': '3.000',
    'totalAmount': '25.000',
    'items': [],
  },
};

DeliveriesController _controller(MockClient client) => DeliveriesController(
  DeliveryRepository(
    ApiClient(
      tokenProvider: () => 'jwt-123',
      onUnauthorized: () {},
      httpClient: client,
    ),
  ),
);

void main() {
  test('a refused action shows where the delivery really stands', () async {
    var cancelled = false;
    final controller = _controller(
      MockClient((request) async {
        if (request.url.path == '/api/deliveries/mine') {
          return jsonResponse(
            pagedBody([
              _delivery(1, status: cancelled ? 'CANCELLED' : 'ASSIGNED'),
            ]),
          );
        }
        // The client cancelled while the courier looked at it.
        cancelled = true;
        return jsonResponse({
          'message': "Cette course n'est plus à accepter.",
        }, 400);
      }),
    );
    await controller.refresh();

    final error = await controller.perform(
      controller.byId(1)!,
      DeliveryAction.accept,
    );

    expect(error, "Cette course n'est plus à accepter.");
    expect(controller.byId(1)!.status, DeliveryStatus.cancelled);
    expect(controller.active, isEmpty);
  });

  test('older history never shows a delivery twice', () async {
    final controller = _controller(
      MockClient((request) async {
        final page = request.url.queryParameters['page'];
        if (page == '1') {
          return jsonResponse(
            pagedBody([
              _delivery(3, status: 'DELIVERED'),
              _delivery(2, status: 'DELIVERED'),
            ], pages: 2),
          );
        }
        // A new assignment since page 1 pushed delivery 2 onto page 2.
        return jsonResponse(
          pagedBody(
            [
              _delivery(2, status: 'DELIVERED'),
              _delivery(1, status: 'DELIVERED'),
            ],
            page: 2,
            pages: 2,
          ),
        );
      }),
    );
    await controller.refresh();

    expect(await controller.loadMoreHistory(), isNull);

    expect(controller.history.map((d) => d.id), [3, 2, 1]);
  });
}
