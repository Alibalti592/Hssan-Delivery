import '../core/api_client.dart';
import '../core/ttl_cache.dart';
import 'promotion_model.dart';

/// Short: a flash offer must not linger long after it ends (ordering with
/// one that's over is refused by the server anyway).
const _promotionsTtl = Duration(minutes: 2);

class PromotionsRepository {
  PromotionsRepository(this._api, {TtlCache? cache})
    : _cache = cache ?? TtlCache();

  final ApiClient _api;
  final TtlCache _cache;

  /// Forgets every kept answer (on sign-out).
  void clearCache() => _cache.clear();

  /// Only currently active/valid promotions — the backend already filters
  /// this server-side (see App\Service\PromotionService::listCurrentlyValid),
  /// so there's nothing left to filter on the client.
  ///
  /// Asked for by the home screen and every menu: kept two minutes
  /// (TtlCache), or asked again with [refresh].
  Future<List<Promotion>> listActive({bool refresh = false}) {
    return _cache.get(
      'promotions',
      ttl: _promotionsTtl,
      refresh: refresh,
      () async {
        final body = await _api.get('/api/promotions');
        return (body as List<dynamic>)
            .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      },
    );
  }

  /// One promotion still running (a 404 once it's over).
  Future<Promotion> get(int id) async {
    final body = await _api.get('/api/promotions/$id');
    return Promotion.fromJson(body as Map<String, dynamic>);
  }
}
