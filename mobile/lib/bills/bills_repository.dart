import '../core/api_client.dart';
import '../core/ttl_cache.dart';
import '../orders/order_models.dart';
import 'bill_models.dart';

class BillsRepository {
  BillsRepository(this._api, {TtlCache? cache}) : _cache = cache ?? TtlCache();

  final ApiClient _api;
  final TtlCache _cache;

  /// Forgets every kept answer (on sign-out).
  void clearCache() => _cache.clear();

  /// Headers to load a bill photo with (Image.network(headers: ...)) —
  /// it is only served to the client, their courier and admins.
  Map<String, String> get photoHeaders => _api.authHeaders;

  /// Only the providers the admin has left visible, in their chosen order.
  /// Kept half an hour (TtlCache): the list hardly ever changes.
  Future<List<BillProvider>> listProviders({bool refresh = false}) {
    return _cache.get(
      'bill-providers',
      ttl: const Duration(minutes: 30),
      refresh: refresh,
      () async {
        final body = await _api.get('/api/bill-providers');
        return (body as List<dynamic>)
            .map((e) => BillProvider.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      },
    );
  }

  /// [reference] is for a bill, [recipientName]/[recipientPhone] for a
  /// mandat — the backend ignores whichever doesn't apply.
  Future<ClientOrder> createBillOrder({
    required int providerId,
    required String amount,
    required String address,
    required int deliveryZoneId,
    String? reference,
    String? recipientName,
    String? recipientPhone,
    String? note,
    double? latitude,
    double? longitude,
    DeliverySpeed speed = DeliverySpeed.standard,
  }) async {
    final body = await _api.post('/api/orders/bills', {
      if (speed.isExpress) 'deliverySpeed': speed.apiValue,
      'deliveryLatitude': ?latitude,
      'deliveryLongitude': ?longitude,
      'providerId': providerId,
      'amount': amount,
      'address': address,
      'deliveryZoneId': deliveryZoneId,
      'reference': ?reference,
      'recipientName': ?recipientName,
      'recipientPhone': ?recipientPhone,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return ClientOrder.fromJson(body as Map<String, dynamic>);
  }

  Future<ClientOrder> uploadBillPhoto(
    int orderId, {
    required List<int> bytes,
    required String filename,
  }) async {
    final body = await _api.postFile(
      '/api/orders/$orderId/bill-photo',
      field: 'photo',
      bytes: bytes,
      filename: filename,
    );
    return ClientOrder.fromJson(body as Map<String, dynamic>);
  }
}
