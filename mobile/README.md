# Hssan Delivery — Mobile App

Flutter application serving both end-user personas, UI in French. The
signed-in account's role decides which half of the app is shown — no
separate builds or flavors.

- **Splash** — branded loading state shown while a stored session is restored
  on launch.
- **Onboarding** — a 2-slide carousel shown once on first launch (persisted
  via secure storage), covering restaurant browsing and order tracking —
  the only two capabilities that exist today. The platform's other planned
  services (see the root README's roadmap) aren't advertised here since
  they aren't built yet.
- **Login / register** — phone + password against `POST /api/auth/login`;
  new clients can self-register via `POST /api/auth/register`
  (`ROLE_CLIENT`). Courier accounts are still admin-provisioned only. An
  account with neither `ROLE_CLIENT` nor `ROLE_LIVREUR` (e.g. an admin-only
  account) is rejected with a friendly message.
- After sign-in, the app branches on the account's role: `ROLE_LIVREUR` →
  the courier dashboard, `ROLE_CLIENT` → the client home.

## Courier (`ROLE_LIVREUR`)

- **Dashboard** (`Tableau de bord`) — greeting, a local availability toggle,
  today's delivered count and pending-proposal count, and a shortcut to the
  in-progress delivery if there is one.
- **Available deliveries** (`Courses disponibles`) — deliveries `ASSIGNED` to
  the courier, awaiting a decision: `Accepter` or `Refuser`.
- **My deliveries** (`Toutes mes courses`) — the queue from
  `GET /api/deliveries/mine`, split into active and history, pull to refresh.
  Active deliveries always load in full; a "Charger plus d'historique"
  button pages in older history beyond the first page.
- **Delivery detail** — pickup restaurant, drop-off address and note, customer
  name with a tap-to-call button, the item list and pricing.
- **Lifecycle actions** — accept / decline / confirm pickup / start delivery /
  mark delivered, plus "report a problem" (fail), each hitting the matching
  `POST /api/deliveries/{id}/…` endpoint. The buttons shown depend on the
  current status. Marking a delivery delivered opens a confirmation screen
  (`Livraison confirmée`) showing the amount collected.
- **Change password** — from the dashboard's overflow menu
  (`POST /api/auth/change-password`, requires the current password). A
  courier who can't sign in at all has an admin reset their password
  instead — see the root README's "Account recovery" section.
- **Push notifications** — notified when a delivery is assigned. Inert
  without a Firebase project configured (see Configuration below).

## Client (`ROLE_CLIENT`)

- **Restaurants** (`Restaurants`) — the public catalogue,
  `GET /api/restaurants` (available restaurants only).
- **Menu** — categories (as filter chips) and products for a restaurant
  (`GET /api/restaurants/{id}/categories`, `.../products`), with inline
  quantity steppers or a dedicated **product detail** screen (quantity
  picker, running total) reached by tapping a row.
- **Cart** — a single restaurant's worth of items at a time (the backend's
  order model is one restaurant per order); adding from a different
  restaurant asks for confirmation before replacing the cart. Reachable both
  as its own tab and as a pushed screen while browsing.
- **Checkout** (`Livraison`) — delivery address (free text, or picked from a
  saved address), delivery zone (`GET /api/delivery-zones`, sets the delivery
  fee), an optional note, and a live running total, then `POST /api/orders`.
- **Order confirmation** — shown right after a successful order.
- **Orders** (`Mes commandes`) — order history (`GET /api/orders`) and detail
  (`GET /api/orders/{id}`) with a status timeline (pending → confirmed →
  preparing → ready for pickup → completed, or cancelled). A "Charger plus"
  button pages in older orders beyond the first page.
- **Saved addresses** (`Mes adresses`, from the profile menu) — list and add
  (`GET`/`POST /api/addresses`); also usable as a picker from checkout.
- **Profile** — account name/phone, saved addresses, change password, and
  sign out.
- **Push notifications** — notified when an order is on its way and when
  it's delivered. Inert without a Firebase project configured (see
  Configuration below).

## Requirements

- Flutter 3.32+ (Dart 3.8+)
- The backend running and reachable (see `../README.md`)

## Configuration

The API host is a compile-time constant. The default (`http://10.0.2.2:8000`)
points at a backend running on the host machine as seen from the Android
emulator. Override it for other targets:

```
flutter run --dart-define=API_BASE_URL=http://localhost:8000        # iOS sim / desktop
flutter run --dart-define=API_BASE_URL=https://api.hssan.example    # deployed
```

Error tracking (Sentry) is off by default — the SDK still runs the app, it
just never sends anything without a DSN:

```
flutter run --dart-define=SENTRY_DSN=https://...@sentry.io/...
```

Push notifications (Firebase Cloud Messaging) are off by default — the app
works the same either way, it just never registers for or receives pushes
without all four of these (from a Firebase project's app config: Project
settings -> General -> Your apps):

```
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

This covers sending/receiving pushes only. A real release build still
needs `flutterfire configure` (or the equivalent manual setup) for native
Android/iOS integration (`google-services.json`, `GoogleService-Info.plist`)
— without it, background/terminated-state notifications on Android in
particular may not display correctly even with the dart-defines above set.

## Native icon and splash screen

The app ships a real launcher icon and splash screen (navy brand background,
white "H" mark) instead of Flutter's default icon, generated with
`flutter_launcher_icons` and `flutter_native_splash` from the source art in
`assets/icon/`. Regenerate both after changing the source art or the brand
colour:

```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Both tools are configured in `pubspec.yaml` (`flutter_launcher_icons:` /
`flutter_native_splash:` keys) and write directly into the native
`android/` and `ios/` projects — there's nothing to run at app startup.

## Run

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Seed accounts in the backend first (`composer fixtures`):
courier `21000001` / `courier1234`, client `22000001` / `client1234` — or
register a new client from the login screen.

## Test

```
flutter analyze
flutter test
```

`test/delivery_test.dart` covers the status/action model; `test/app_flow_test.dart`
drives the auth and delivery controllers against a mocked HTTP client.
`test/widget/` goes one layer up — it pumps real screens (login, the
courier dashboard, the courier delivery queue, the client order list)
with `pumpWidget`/`tester.tap`/`tester.enterText` against the same
mocked-HTTP pattern, so a layout regression that breaks what the user
actually sees or taps (not just the underlying controller logic) fails
CI too.

## Structure

```
lib/
  config.dart              API base URL (--dart-define)
  theme.dart               Material 3 theme (navy brand) + status colours
  core/                    HTTP client, typed errors, secure token/onboarding storage,
                           paginated-list result type
  onboarding/              splash screen, first-launch onboarding carousel
  auth/                    login/register/change-password: repository, ChangeNotifier
                           controller, screens
  dashboard/               courier landing screen after login
  deliveries/              courier queue, available-deliveries, detail, confirmation:
                           models, repository, controller, screens
  catalogue/               restaurant/category/product models + repository
  cart/                    single-restaurant cart (ChangeNotifier)
  orders/                  client order models + repository
  addresses/               saved-address models + repository
  notifications/           FCM wiring: repository + PushNotificationService
                           (inert without a Firebase project — see Configuration)
  client/                  client home shell, restaurant/menu/product detail,
                           cart/checkout, order history/detail, addresses,
                           profile
  widgets/                 shared UI (dark header, delivery/order status chips)
```

State management is `provider` + `ChangeNotifier`. The API client injects the JWT
and, on any `401`, signs the user out.
