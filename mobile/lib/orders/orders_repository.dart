import '../cart/cart.dart';
import '../core/api_client.dart';
import '../core/paged_result.dart';
import 'order_models.dart';

class OrdersRepository {
  OrdersRepository(this._api);

  final ApiClient _api;

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
  }) async {
    final body = await _api.post('/api/orders', {
      'restaurantId': restaurantId,
      'items': items
          .map((l) => {'productId': l.product.id, 'quantity': l.quantity})
          .toList(growable: false),
      'deliveryAddress': deliveryAddress,
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
}
