import 'dart:async';

import '../cart/cart.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/paged_result.dart';
import 'courier_position.dart';
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

  /// Where the courier is, while they're on this order (accepted it, until
  /// delivered); null otherwise, or before their app reports a position.
  Future<CourierPosition?> courierPosition(int orderId) async {
    try {
      final body = await _api.get('/api/orders/$orderId/courier-location');
      // Polled every few seconds: a malformed answer just means no
      // position this time, never an error.
      if (body is! Map<String, dynamic> ||
          body['latitude'] is! num ||
          body['longitude'] is! num) {
        return null;
      }
      return CourierPosition.fromJson(body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// The zone an address pin falls in, from the zones the admin placed on
  /// the map; null when none covers it (the client then picks one).
  Future<DeliveryZoneOption?> locateZone(
    double latitude,
    double longitude,
  ) async {
    try {
      final body = await _api.get(
        '/api/delivery-zones/locate?latitude=$latitude&longitude=$longitude',
      );
      return DeliveryZoneOption.fromJson(body as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ClientOrder> createOrder({
    required int restaurantId,
    required List<CartLine> items,
    required String deliveryAddress,
    required int deliveryZoneId,
    String? note,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? promoCode,
  }) async {
    final body = await _api.post(
      '/api/orders',
      _orderBody(
        restaurantId: restaurantId,
        items: items,
        deliveryAddress: deliveryAddress,
        deliveryZoneId: deliveryZoneId,
        note: note,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        promoCode: promoCode,
      ),
    );
    return ClientOrder.fromJson(body as Map<String, dynamic>);
  }

  /// What [createOrder] would charge, promotion included, without placing
  /// the order. Throws the same ApiException (e.g. a wrong promo code).
  Future<OrderQuote> quoteOrder({
    required int restaurantId,
    required List<CartLine> items,
    required int deliveryZoneId,
    String? promoCode,
  }) async {
    final body = await _api.post(
      '/api/orders/quote',
      _orderBody(
        restaurantId: restaurantId,
        items: items,
        // Not priced; the endpoint only needs it to be there.
        deliveryAddress: '-',
        deliveryZoneId: deliveryZoneId,
        promoCode: promoCode,
      ),
    );
    return OrderQuote.fromJson(body as Map<String, dynamic>);
  }

  Map<String, dynamic> _orderBody({
    required int restaurantId,
    required List<CartLine> items,
    required String deliveryAddress,
    required int deliveryZoneId,
    String? note,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? promoCode,
  }) => {
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
    if (promoCode != null && promoCode.trim().isNotEmpty)
      'promoCode': promoCode.trim(),
  };

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
