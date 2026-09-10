# Hssan Delivery — Courier App

Flutter application for couriers (`ROLE_LIVREUR`). It covers the courier half of
the delivery workflow end to end:

- **Login** — phone + password against `POST /api/auth/login`; non-courier
  accounts are rejected.
- **My deliveries** — the courier's queue from `GET /api/deliveries/mine`, split
  into active and history, pull to refresh.
- **Delivery detail** — pickup restaurant, drop-off address and note, customer
  name with a tap-to-call button, the item list and pricing.
- **Lifecycle actions** — accept / confirm pickup / start delivery / mark
  delivered, plus "report a problem" (fail), each hitting the matching
  `POST /api/deliveries/{id}/…` endpoint. The buttons shown depend on the
  current status.

The client persona (browsing, cart, checkout, tracking) is not part of this app.

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

## Run

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Seed a courier account in the backend first (`composer fixtures`): `21000001` /
`courier1234`.

## Test

```
flutter analyze
flutter test
```

`test/delivery_test.dart` covers the status/action model; `test/app_flow_test.dart`
drives the auth and delivery controllers against a mocked HTTP client.

## Structure

```
lib/
  config.dart              API base URL (--dart-define)
  theme.dart               Material 3 theme + status colours
  core/                    HTTP client, typed errors, secure token storage
  auth/                    login: repository, ChangeNotifier controller, screen
  deliveries/              queue + detail: models, repository, controller, screens
  widgets/                 shared UI (status chip)
```

State management is `provider` + `ChangeNotifier`. The API client injects the JWT
and, on any `401`, signs the user out.
