import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ttl_cache.dart';

void main() {
  late DateTime now;
  late TtlCache cache;
  late int loads;

  Future<int> load() async => ++loads;

  setUp(() {
    now = DateTime(2026, 11, 19, 12);
    cache = TtlCache(clock: () => now);
    loads = 0;
  });

  const ttl = Duration(minutes: 5);

  test('keeps an answer for its lifetime, then loads again', () async {
    expect(await cache.get('k', load, ttl: ttl), 1);
    now = now.add(const Duration(minutes: 4));
    expect(await cache.get('k', load, ttl: ttl), 1);
    now = now.add(const Duration(minutes: 2));
    expect(await cache.get('k', load, ttl: ttl), 2);
  });

  test('pull to refresh always loads', () async {
    await cache.get('k', load, ttl: ttl);
    expect(await cache.get('k', load, ttl: ttl, refresh: true), 2);
    // And the fresh answer is the one kept.
    expect(await cache.get('k', load, ttl: ttl), 2);
  });

  test('two screens asking at once make one request', () async {
    final first = cache.get('k', load, ttl: ttl);
    final second = cache.get('k', load, ttl: ttl);
    expect(await Future.wait([first, second]), [1, 1]);
    expect(loads, 1);
  });

  test('a failure is not kept', () async {
    var fail = true;
    Future<int> flaky() async {
      loads++;
      if (fail) throw Exception('offline');
      return loads;
    }

    await expectLater(cache.get('k', flaky, ttl: ttl), throwsException);
    fail = false;
    expect(await cache.get('k', flaky, ttl: ttl), 2);
  });

  test('keys are separate, and clear forgets them all', () async {
    await cache.get('a', load, ttl: ttl);
    expect(await cache.get('b', load, ttl: ttl), 2);
    cache.clear();
    expect(await cache.get('a', load, ttl: ttl), 3);
  });
}
