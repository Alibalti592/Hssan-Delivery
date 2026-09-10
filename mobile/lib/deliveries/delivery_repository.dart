import '../core/api_client.dart';
import 'delivery.dart';

class DeliveryRepository {
  DeliveryRepository(this._api);

  final ApiClient _api;

  Future<List<Delivery>> listMine() async {
    final body = await _api.get('/api/deliveries/mine');
    final list = (body as List<dynamic>?) ?? const [];
    return list
        .map((e) => Delivery.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Delivery> act(int deliveryId, DeliveryAction action) async {
    final body = await _api.post(
      '/api/deliveries/$deliveryId/${action.pathSegment}',
    );
    return Delivery.fromJson(body as Map<String, dynamic>);
  }
}
