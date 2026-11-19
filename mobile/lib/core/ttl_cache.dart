import 'dart:async';

/// Answers kept in memory for a while: the catalogue (restaurants, menus,
/// promotions...) changes rarely, and every request costs a round trip to
/// the server. A screen opened again soon after, or the same menu asked for
/// by several screens, gets the kept answer at once.
///
/// Only for data that's the same for every customer: never orders,
/// addresses or anything else that's someone's own. Prices are checked
/// again by the server when ordering, and the checkout's total is always
/// asked for afresh, so a kept menu can't make anyone pay a stale price.
class TtlCache {
  TtlCache({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _Entry> _entries = {};

  /// The kept answer for [key] when younger than [ttl], else [load]'s. A
  /// load still under way is shared: two screens asking at once make one
  /// request. A failed load isn't kept: the next ask tries again. [refresh]
  /// (pull to refresh) always loads.
  Future<T> get<T>(
    String key,
    Future<T> Function() load, {
    required Duration ttl,
    bool refresh = false,
  }) {
    final now = _clock();
    final kept = _entries[key];
    if (!refresh && kept != null && now.isBefore(kept.expiresAt)) {
      return kept.value as Future<T>;
    }

    final value = load();
    _entries[key] = _Entry(value, now.add(ttl));
    unawaited(
      value.then<void>(
        (_) {},
        onError: (Object _) {
          // Only if nothing newer took its place meanwhile.
          if (identical(_entries[key]?.value, value)) _entries.remove(key);
        },
      ),
    );
    return value;
  }

  /// Forgets everything: on sign-out, so the next account starts afresh.
  void clear() => _entries.clear();
}

class _Entry {
  _Entry(this.value, this.expiresAt);

  final Future<Object?> value;
  final DateTime expiresAt;
}
