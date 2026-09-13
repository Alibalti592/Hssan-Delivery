import '../core/api_client.dart';
import 'promotion_model.dart';

class PromotionsRepository {
  PromotionsRepository(this._api);

  final ApiClient _api;

  /// Only currently active/valid promotions — the backend already filters
  /// this server-side (see App\Service\PromotionService::listCurrentlyValid),
  /// so there's nothing left to filter on the client.
  Future<List<Promotion>> listActive() async {
    final body = await _api.get('/api/promotions');
    return (body as List<dynamic>)
        .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
