import '../core/api_client.dart';
import 'address_models.dart';

class AddressRepository {
  AddressRepository(this._api);

  final ApiClient _api;

  Future<List<SavedAddress>> list() async {
    final body = await _api.get('/api/addresses');
    return (body as List<dynamic>)
        .map((e) => SavedAddress.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SavedAddress> create({
    required String label,
    required String addressLine,
    String? instructions,
    bool isDefault = false,
    int? deliveryZoneId,
    double? latitude,
    double? longitude,
  }) async {
    final body = await _api.post(
      '/api/addresses',
      _body(
        label,
        addressLine,
        instructions,
        isDefault,
        deliveryZoneId,
        latitude,
        longitude,
      ),
    );
    return SavedAddress.fromJson(body as Map<String, dynamic>);
  }

  Future<SavedAddress> update(
    int id, {
    required String label,
    required String addressLine,
    String? instructions,
    bool isDefault = false,
    int? deliveryZoneId,
    double? latitude,
    double? longitude,
  }) async {
    final body = await _api.put(
      '/api/addresses/$id',
      _body(
        label,
        addressLine,
        instructions,
        isDefault,
        deliveryZoneId,
        latitude,
        longitude,
      ),
    );
    return SavedAddress.fromJson(body as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/api/addresses/$id');

  static Map<String, dynamic> _body(
    String label,
    String addressLine,
    String? instructions,
    bool isDefault,
    int? deliveryZoneId,
    double? latitude,
    double? longitude,
  ) => {
    'label': label,
    'addressLine': addressLine,
    if (instructions != null && instructions.isNotEmpty)
      'instructions': instructions,
    'isDefault': isDefault,
    'deliveryZoneId': ?deliveryZoneId,
    'latitude': ?latitude,
    'longitude': ?longitude,
  };
}
