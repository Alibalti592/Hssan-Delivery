import '../core/api_client.dart';
import '../core/paged_result.dart';
import 'delivery.dart';

class DeliveryRepository {
  DeliveryRepository(this._api);

  final ApiClient _api;

  /// [limit] defaults well above the backend's own default (20): a
  /// courier's in-progress deliveries must always be visible in full, and
  /// since the backend orders by creation date across every status, a
  /// generous first page all but guarantees active ones are never pushed
  /// off by older history. Older history beyond that is fetched a page at
  /// a time via [DeliveriesController.loadMoreHistory].
  Future<PagedResult<Delivery>> listMine({int page = 1, int limit = 50}) async {
    final body = await _api.get('/api/deliveries/mine?page=$page&limit=$limit');
    return PagedResult.fromJson(
      body as Map<String, dynamic>,
      (json) => Delivery.fromJson(json),
    );
  }

  Future<Delivery> act(int deliveryId, DeliveryAction action) async {
    final body = await _api.post(
      '/api/deliveries/$deliveryId/${action.pathSegment}',
    );
    return Delivery.fromJson(body as Map<String, dynamic>);
  }
}
