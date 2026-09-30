import 'dart:async';

import '../cart/cart.dart';
import '../core/api_client.dart';
import '../core/paged_result.dart';
import 'order_models.dart';

class OrdersRepository {
  OrdersRepository(this._api);

  final ApiClient _api;

  final _changes = StreamController<int>.broadcast();

  /// Ids of orders that just changed on the server (a push arrived about
  /// them), so open order screens reload at once instead of on their next
  /// poll.
  Stream<int> get changes => _changes.stream;

  void notifyChanged(int orderId) => _changes.add(orderId);

  Future<List<DeliveryZoneOption>> listDeliveryZones() async {
    final body = await _api.get('/api/delivery-zones');
    return (body as List<dynamic>)
        .map((e) => DeliveryZoneOption.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ClientOrder> createOrder({
    required int restaurantId,
    required List<CartLine> items,
    required String deliveryAddress,
    required int deliveryZoneId,
    String? note,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final body = await _api.post('/api/orders', {
      'deliveryLatitude': ?deliveryLatitude,
      'deliveryLongitude': ?deliveryLongitude,
      'restaurantId': restaurantId,
      'items': items
          .map(
            (l) => {
              'productId': l.product.id,
              'quantity': l.quantity,
              if (l.option != null) 'option': l.option!.name,
            },
          )
          .toList(growable: false),
      'deliveryAddress': deliveryAddress,
      'deliveryZoneId': deliveryZoneId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return ClientOrder.fromJson(body as Map<String, dynamic>);
  }

  Future<ClientOrder> createParcelOrder({
    required String pickupAddress,
    required String deliveryAddress,
    required String recipientName,
    required String recipientPhone,
    required int deliveryZoneId,
    String? note,
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final body = await _api.post('/api/orders/parcels', {
      'pickupLatitude': ?pickupLatitude,
      'pickupLongitude': ?pickupLongitude,
      'deliveryLatitude': ?deliveryLatitude,
      'deliveryLongitude': ?deliveryLongitude,
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'deliveryZoneId': deliveryZoneId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return ClientOrder.fromJson(body as Map<String, dynamic>);
  }

  Future<PagedResult<ClientOrder>> listOrders({int page = 1}) async {
    final body = await _api.get('/api/orders?page=$page');
    return PagedResult.fromJson(
      body as Map<String, dynamic>,
      (json) => ClientOrder.fromJson(json),
    );
  }

  Future<ClientOrder> getOrder(int id) async {
    final body = await _api.get('/api/orders/$id');
    return ClientOrder.fromJson(body as Map<String, dynamic>);
  }

  /// Only succeeds while the order's delivery is still unclaimed or just
  /// assigned — see ClientOrder.canCancel and the backend's
  /// OrderService::cancelOrder.
  Future<ClientOrder> cancelOrder(int id) async {
    final body = await _api.post('/api/orders/$id/cancel');
    return ClientOrder.fromJson(body as Map<String, dynamic>);
  }
}
