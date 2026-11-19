# Performance audit — November 2026

What was measured, what was changed, how it was verified, and what is still
open. Every number below was measured here; none is an estimate unless it
says so.

## How it was measured

- **SQL query counts per endpoint:** the backend ran in `prod` mode
  (`APP_ENV=prod`, opcache) against the integration-test database (125
  orders, 106 deliveries, 126 restaurants, 902 couriers). Each endpoint was
  counted at two page sizes (5 and 50 rows) from PostgreSQL's statement log.
  If the count grows with the page size, that's an N+1.
- **Query plans:** `EXPLAIN ANALYZE` on a scaled copy of the real catalogue:
  1,111 restaurants and 47,672 dishes (the real menus ×100), plus 120,012
  orders spread over 90 days, each with its delivery. Queries ran as
  prepared statements, the way Doctrine sends them.
- **Endpoint timings:** `curl` against the same prod-mode server,
  repeated runs.
- **App:** widget tests with a counting HTTP client, and counts of the photo
  widgets actually built at a phone's height (844 logical pixels).
- **Admin:** `vite build` sizes, and Playwright with mocked APIs.

Limits: nothing here was measured on the production server or a real phone.
This environment can't reach the production domain, and has no device.

## 1. N+1 queries

| Endpoint | Before (5 / 50 rows) | After |
|---|---|---|
| `GET /api/admin/promotions` | 8 / 23 queries | 4 / 4 |
| `GET /api/admin/notifications` (latest 30) | 16 queries | 4 |
| Every other list (orders, deliveries, couriers, restaurants, products, categories, zones, bill providers, client restaurants/menus/orders, courier jobs) | flat: 3–5 | unchanged |

**Fixes:**
- `PromotionService::list` and `PromotionRepository::currentlyValid` now
  fetch-join the restaurant.
- `PushCampaignRepository::latest` fetch-joins the promotion and the sender.
- `PopularityService` loads popular dishes together with their restaurant
  (it checks each one is still open).

**Regression tests:**
- `tests/Integration/QueryCountTest.php` uses a DBAL middleware that is
  active in tests only (`tests/Support/QueryCounter.php`, `when@test` in
  `services.yaml`). It asserts that each list costs the same number of
  queries for 2 rows as for 6.
- The notifications list always shows the latest 30, so it has no page size
  to compare. Its test asserts a ceiling of 6 queries instead; without the
  fix the count was 63.
- Both tests were run against the old code to confirm they fail
  (promotions: 5 → 9; notifications: 63).

## 2. Indexes

The baseline was measured on the scaled copy, without yesterday's composite
indexes (as production was before `Version20261118180020`).

| Query | Before | Production indexes (`…180020`) | Plus `Version20261119175647` |
|---|---|---|---|
| Admin orders, newest first (`ORDER BY created_at DESC LIMIT 20`) | 16.7 ms | 14.6 ms | **0.025 ms** |
| A customer's orders (`user_id = ? ORDER BY created_at`) | 18.4 ms | **0.065 ms** | 0.079 ms |
| Today's dashboard (`created_at >= today`) | 8.8 ms | 7.6 ms | **0.96 ms** |
| Popular restaurants (completed, last 30 days) | 21.5 ms | 13.8 ms | 14.8 ms (see §3) |
| Waiting deliveries (30 pending of 120,000) | 6.4 ms | **0.20 ms** | 0.15 ms |
| Admin deliveries, newest first | 18.5 ms | 19.4 ms | **0.093 ms** |
| Dish search `LOWER(name) LIKE '%pizza%'` | 28.5 ms | — | **0.67 ms** |
| Dish search, a common word (6,060 hits) | 43.7 ms | — | **7.9 ms** |
| Dish search, no match | 26.3 ms | — | **0.03 ms** |
| Restaurant search (1,111 rows) | 0.3–0.5 ms | — | not indexed (not needed) |

**Migration `Version20261119175647`** (applied, rolled back and applied
again here; `doctrine:schema:validate` passes):
- `idx_order_created`, `idx_delivery_created`: indexes on the date alone.
  The composites `(status, created_at)` and `(user_id, created_at)` can't
  serve an unfiltered sort.
- `idx_product_name_trgm`: GIN `gin_trgm_ops` on `LOWER(name)`, created
  with `CREATE EXTENSION IF NOT EXISTS pg_trgm`. Doctrine can't describe it,
  but it leaves it alone (checked with `schema:update --dump-sql`).
  1.8 MB for 47,672 dishes.
- `DROP idx_f5299398a76ed395` (the order's customer alone): redundant with
  `(user_id, created_at)` and the unique `(user_id, client_request_id)`.
  Doctrine doesn't want it back.

**Not indexed, on purpose:**
- **Restaurant search:** already sub-millisecond on 1,111 rows.
- **Product menus:** at most a few dozen rows per restaurant, served by
  `restaurant_id`.
- **The popularity aggregate:** 60% of orders are completed, so a status
  index barely helps. It's cached instead (§3).

## 3. Caching

**Server: `/api/popular`.** It was the only expensive read: it ranks 30 days
of delivered orders.

- **Pool:** `cache.popular` (filesystem, 10-minute lifetime).
- **What's stored:** only the ranking (ids and counts). Restaurants and
  dishes are loaded fresh on every request, so one that closes leaves the
  feed at once.
- **Invalidation:** `PopularityCache` listens to `DeliveryStatusChangedEvent`
  and clears the pool when a delivery becomes, or stops being, DELIVERED.
  `OrderDeletion` clears it when it deletes a completed order.
- **No per-user concern:** the data is the same for every customer.
- **Timings** on 120,000 orders, whole request: uncached 91–132 ms, cached
  **25–32 ms**.
- **Tests:** `PopularApiTest` checks that the ranking is reused, that a
  closed restaurant disappears at once while the ranking is cached, and
  that a delivered delivery clears it. These tests were confirmed to fail
  with the cache disabled.

**App: `TtlCache`** (`mobile/lib/core/ttl_cache.dart`). It keeps catalogue
answers in memory for:

| Data | Lifetime |
|---|---|
| restaurants | 5 min |
| menus | 3 min |
| restaurant categories | 30 min |
| popular | 5 min |
| promotions | 2 min |
| bill providers | 30 min |

- **Shared loads:** two screens asking at once share one request.
- **Failures:** a failed load is never kept.
- **Refresh:** pull-to-refresh and "Réessayer" bypass it.
- **Sign-out:** sign-out clears it.
- **User data is never cached:** orders, addresses, quotes and the like
  always go to the server.
- **Consistency:** prices are checked again by the server when ordering,
  and the checkout total is always asked for afresh. A menu kept for a few
  minutes can therefore never make anyone pay a stale price.
- **Measured** (`test/catalogue_cache_test.dart`): a usual visit (home, a
  menu, a dish, the cart, home again) made **15 requests before, 6 now**,
  never the same one twice. Each request it saves is a round trip to the
  server, which is in Canada.

## 4. Images

- **Responsive copies** (delivered in the previous update):
  - the server keeps 480 px and 960 px WebP copies of every photo;
  - the app downloads the smallest copy wide enough for where the photo is
    shown;
  - on the real photos, a menu photo goes from 300 KB to 31 KB on average.
- **App home screen:** it was built in full, photos included, even below
  the fold. It's now a lazy list.
  - Each section is kept alive once built, which avoids the flashing that
    led to the old design: a lazy list used to rebuild a section scrolled
    out of view, and reload its photos.
  - At opening, at a phone's height, **25 photos** were built before
    against **13** now (the first screen plus a small margin below it).
  - Regression test: `home_screen_test.dart`, "photos below the fold wait
    until scrolled near".
- **Admin lists** (promotions, dishes, restaurants, the menu editor) now use
  the `Thumb` component:
  - it loads the 480 px copy instead of the original;
  - it uses `loading="lazy"` and `decoding="async"`;
  - it falls back to the original if the copy is missing.
  - Test: `e2e/thumbnails.spec.ts`.

## 5. Optimistic UI

**Only for reversible toggles:**
- dish availability (list and menu editor);
- restaurant open or closed (list and detail page);
- promotion active;
- courier active (list and detail page);
- the courier's own availability in the app.

**Not optimistic:** orders, deletions, uploads, assignments, cancellations
and notification sends. They are irreversible or visible to others, so they
wait for the server's answer.

**Admin:** `optimisticToggle` (`admin/src/api/optimistic.ts`):
- cancels any reload in flight, then patches the item in every cached view
  (page, list or detail);
- rolls back to the snapshot if the server refuses, and the page shows the
  server's message;
- always reloads from the server to settle the state;
- keeps the control disabled while the request is pending, so a double
  click can't send two opposite requests.
- Test: `e2e/optimistic-toggle.spec.ts` (immediate change, control locked,
  confirmation, then rollback with the message). It was confirmed to fail
  on the old, non-optimistic toggle.

**App:** `AuthController.setAvailability`:
- flips the switch at once, keeps it locked until the server answers, and
  puts it back with the reason if refused or offline;
- doesn't restore anything if the failure signed the user out.
- Test: `app_flow_test.dart`, "availability flips at once, and back when
  refused".

## 6. Frontend

- **Admin bundle:** a single chunk of 583 kB (167.5 kB gzipped). The two
  map pages (Leaflet, 153 kB) are now loaded on demand, and the main chunk
  is **420 kB (119.4 kB gzipped), −29%**.
- **Fewer API requests:** the app cache (§3) cuts them; the admin's
  optimistic updates no longer wait to show a change.
- **Re-renders and memoization:** no re-render problem was measured, so
  none was added (no `React.memo`, `useMemo` or `select` changes). The
  heaviest re-render seen is the menu screen rebuilding its rows on a cart
  change, at most a few dozen rows; it wasn't worth the added complexity
  without a measurement showing a cost.

## 7. Backend

- **Endpoint timings:**
  - client and admin endpoints answer in 18–28 ms locally, with 2–8
    queries;
  - JSON bodies weigh 2–6.5 kB (0.6–1.4 kB gzipped).
- **Firebase's sign-in token** is cached (previous update), so a request
  that sends a push no longer asks Google first.
- **Pagination totals:** `COUNT(*)` on the admin lists costs 13–17 ms at
  120,000 orders. It's inherent to showing a total and was left as is.

## Still open

1. **The server is in Canada; the customers are in Tunisia.**
   - Each round trip costs well over 100 ms, an estimate since it wasn't
     measured from Tunisia.
   - Cloudflare now serves photos from close by, and the app cache saves
     repeat requests. Menus, orders and the checkout still make the
     transatlantic trip.
   - This is the largest remaining cost, and only moving the server to
     Europe removes it.
2. **Pushes are still sent during the request** that triggers them (a
   courier accepting a job, each status change), so the request waits for
   Firebase.
   - Sending them afterwards needs a worker process (Symfony Messenger
     with a consumer container).
   - Under Apache with mod_php, the response can't be flushed before the
     request finishes. Not done.
3. **Recomputing the popularity ranking** costs about 100 ms at 120,000
   orders. It happens once per 10 minutes, and after each delivered order.
   At a high delivery rate it would be recomputed often. Restricting the
   clearing to orders in the 30-day window is possible, but wasn't needed
   at today's volume.
4. **Searches of 1–2 letters** can't use the trigram index (it needs 3), so
   they scan the table: about 26–44 ms at 47,000 dishes.
5. **The `pg_trgm` extension** needs a role allowed to create extensions.
   The official Postgres image's user is a superuser, so production and CI
   are fine. A managed database without that right would fail on this
   migration.
6. **On a real device:** the home screen's lazy build was measured in
   widget tests, not on a phone.
