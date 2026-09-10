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
  }) async {
    final body = await _api.post('/api/addresses', {
      'label': label,
      'addressLine': addressLine,
      if (instructions != null && instructions.isNotEmpty)
        'instructions': instructions,
      'isDefault': isDefault,
    });
    return SavedAddress.fromJson(body as Map<String, dynamic>);
  }
}
