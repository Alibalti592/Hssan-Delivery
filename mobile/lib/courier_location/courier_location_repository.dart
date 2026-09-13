import '../core/api_client.dart';

class CourierLocationRepository {
  CourierLocationRepository(this._api);

  final ApiClient _api;

  Future<void> report(double latitude, double longitude) async {
    await _api.post('/api/couriers/location', {
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
