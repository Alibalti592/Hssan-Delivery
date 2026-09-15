# Hssan Delivery

Hssan Delivery is a delivery platform currently under development.

The project is structured around a Symfony REST API backend, a React/Vite administration dashboard, and a Flutter mobile application.

## Current project structure

```text
Hssan-Delivery/
├── backend/    # Symfony REST API
├── admin/      # React + Vite admin dashboard
├── mobile/     # Flutter mobile application
└── .github/
    └── workflows/
        └── backend.yml

Current status: all three components are in active use end-to-end against a
real backend — Symfony API, React admin dashboard (restaurant/category/
product/delivery-zone/courier/promotion management, order/delivery
visibility, and a live courier map — see `admin/README.md`), and the Flutter
app (client + courier, three of four planned services live — see
`mobile/README.md`).

Technology stack
Backend
PHP 8.2
Symfony 7.4
Doctrine ORM
PostgreSQL
JWT authentication with LexikJWTAuthenticationBundle
PHPUnit
Mobile
Flutter
Dart
Admin dashboard
React
Vite
TypeScript
Playwright (e2e)
CI
GitHub Actions
PostgreSQL 16
PHP 8.2
Roles

The backend currently supports:

ROLE_CLIENT
ROLE_LIVREUR
ROLE_ADMIN
Client

A client can:

create an account
authenticate with phone and password
browse the available catalogue (restaurants, or grocery stores via `?type=GROCERY`)
save multiple labeled delivery addresses
create a restaurant/grocery order, or a Colis parcel-delivery request (pickup
address, drop-off address, named recipient — no restaurant or items involved)
receive a linked delivery
Livreur

A courier account is created by an administrator.

The courier receives credentials from the administrator and uses them to authenticate through the mobile application.

An admin can deactivate a courier account (e.g. one who has left) without deleting
it. A deactivated account can no longer log in, and can no longer be assigned new
deliveries — attempting either returns an explicit error rather than failing silently.

A courier can:

view assigned deliveries
accept a delivery
mark a delivery as picked up
mark a delivery as on the way
mark a delivery as delivered
report a delivery as failed
report their live GPS location while a delivery is active (backs the admin
courier map)
Admin

The administrator can currently:

authenticate (session is an httpOnly cookie — see "Admin authentication" below)
create courier accounts
list and view courier accounts
deactivate/reactivate a courier account
view all orders and deliveries
assign deliveries to couriers
cancel eligible deliveries
manage promotions (create/update/delete, activate/deactivate, photo)
view active couriers' live locations on a map

Additional administration features are planned.

Admin authentication

The admin dashboard authenticates like every other client (`POST
/api/auth/login`), but instead of reading the JWT out of the response body
and holding it in JS, the backend also mirrors it into an httpOnly,
`SameSite=Lax` cookie (`config/packages/lexik_jwt_authentication.yaml`) that
the browser sends automatically and JavaScript can never read — closing off
the obvious XSS-steals-the-token-from-storage attack that plain
`localStorage` had. `POST /api/auth/logout` clears that cookie (JS can't do
it itself for an httpOnly cookie). Mobile is unaffected: it still reads the
token from the JSON body and sends it as `Authorization: Bearer <jwt>`; both
extractors run on the same firewall. `JWT_COOKIE_SECURE` (see
`.env.example`) must be set to `true` once the admin dashboard is served
over HTTPS — a `Secure` cookie is silently dropped by browsers over plain
`http://`, so it defaults to `false` for local development.

Mobile needing the token in the body (`remove_token_from_body_when_cookies_used:
false`) means `POST /api/auth/login`'s response would otherwise carry the
plaintext JWT for the admin dashboard too, even though it never reads it —
narrowing the original XSS risk rather than closing it (a script active in
the page at the exact moment of login could still read the token off the
response, even though nothing sits in storage for it to find afterward).
The admin dashboard sends `X-Client-Platform: web` on every request (see
`admin/src/api/client.ts`); `App\Security\WebLoginResponseSanitizer`
(wired as `security.yaml`'s `json_login` success handler, wrapping Lexik's
own) strips `token` from the login response body whenever that header is
present, returning `204 No Content` instead — so the body genuinely never
carries the JWT for the admin dashboard, matching what the cookie migration
was meant to guarantee. Mobile never sends the header, so its body is
unaffected.

Order workflow

The current order states are:

PENDING
   ↓
CONFIRMED
   ↓
PREPARING
   ↓
READY_FOR_PICKUP
   ↓
COMPLETED

Orders can also become:

CANCELLED
Delivery workflow

The current delivery lifecycle is:

PENDING
   ↓
ASSIGNED
   ↓
ACCEPTED
   ↓
PICKED_UP
   ↓
ON_THE_WAY
   ↓
DELIVERED

Exception states:

CANCELLED
FAILED
Order / Delivery synchronization

Delivery transitions synchronize the associated order status.

Current mapping:

Delivery status	Order status
PENDING	PENDING
ASSIGNED	CONFIRMED
ACCEPTED	CONFIRMED
PICKED_UP	READY_FOR_PICKUP
ON_THE_WAY	READY_FOR_PICKUP
DELIVERED	COMPLETED
CANCELLED	CANCELLED
FAILED	CANCELLED

Restaurant preparation states such as PREPARING remain part of the planned restaurant workflow and are not controlled by the courier lifecycle.

Backend API
Authentication
POST  /api/auth/register
POST  /api/auth/login
POST  /api/auth/logout
GET   /api/auth/me
POST  /api/auth/change-password
PATCH /api/auth/availability
Courier location
POST /api/couriers/location
Admin courier management
POST  /api/admin/couriers
GET   /api/admin/couriers
GET   /api/admin/couriers/{id}
GET   /api/admin/couriers/locations
PATCH /api/admin/couriers/{id}/active
PATCH /api/admin/couriers/{id}/password
Admin promotion management
POST   /api/admin/promotions
GET    /api/admin/promotions
GET    /api/admin/promotions/{id}
PUT    /api/admin/promotions/{id}
DELETE /api/admin/promotions/{id}
PATCH  /api/admin/promotions/{id}/active
POST   /api/admin/promotions/{id}/photo
DELETE /api/admin/promotions/{id}/photo
Admin restaurant management
POST   /api/admin/restaurants
GET    /api/admin/restaurants
GET    /api/admin/restaurants/{id}
PUT    /api/admin/restaurants/{id}
DELETE /api/admin/restaurants/{id}
PATCH  /api/admin/restaurants/{id}/availability
POST   /api/admin/restaurants/{id}/photo
DELETE /api/admin/restaurants/{id}/photo
Admin category management
POST /api/admin/restaurants/{restaurantId}/categories
GET  /api/admin/restaurants/{restaurantId}/categories
GET  /api/admin/categories/{id}
PUT  /api/admin/categories/{id}
Admin product management
POST   /api/admin/restaurants/{restaurantId}/products
GET    /api/admin/restaurants/{restaurantId}/products
GET    /api/admin/products/{id}
PUT    /api/admin/products/{id}
DELETE /api/admin/products/{id}
PATCH  /api/admin/products/{id}/availability
POST   /api/admin/products/{id}/photo
DELETE /api/admin/products/{id}/photo

Deleting a restaurant or product that has existing orders is refused (409) —
deactivate it instead. Deleting a restaurant with no orders cascades to its
categories and products.
Admin delivery zone management
POST /api/admin/delivery-zones
GET  /api/admin/delivery-zones
GET  /api/admin/delivery-zones/{id}
PUT  /api/admin/delivery-zones/{id}
Admin order management
GET  /api/admin/orders
GET  /api/admin/orders/{id}
Admin delivery oversight
GET  /api/admin/deliveries
GET  /api/admin/deliveries/{id}
Admin dashboard stats
GET  /api/admin/stats
Push notification device tokens
POST   /api/notifications/device-token
DELETE /api/notifications/device-token
Delivery management
GET  /api/deliveries/mine

POST /api/deliveries/{id}/assign/{courierId}
POST /api/deliveries/{id}/accept
POST /api/deliveries/{id}/decline
POST /api/deliveries/{id}/pickup
POST /api/deliveries/{id}/on-the-way
POST /api/deliveries/{id}/delivered
POST /api/deliveries/{id}/cancel
POST /api/deliveries/{id}/fail

Every delivery response embeds an `order` summary (restaurant name, delivery
address, customer name + phone, items, fee, total) so a courier has everything
needed to carry out the job in one call.
Orders
POST /api/orders
POST /api/orders/parcels
GET  /api/orders
GET  /api/orders/{id}
POST /api/orders/{id}/cancel

POST /api/orders/parcels creates a Colis (parcel-delivery) order: no
restaurant, no items, just a pickup address, drop-off address, and a named
recipient — see "Colis (parcel delivery)" below.
Catalogue (what a signed-in client browses before ordering)
GET /api/restaurants[?type=RESTAURANT|GROCERY]
GET /api/restaurants/{id}
GET /api/restaurants/{id}/categories
GET /api/restaurants/{id}/products

Requires any authenticated account (ROLE_USER, same as /api/orders — no
separate role check), but not ROLE_ADMIN. Closed restaurants and
unavailable products are left out entirely, matching what OrderService
will actually accept. `type` defaults to RESTAURANT; the mobile app's
"Courses" (grocery) service passes `?type=GROCERY` to browse the same
Restaurant entity's grocery-flagged rows instead (see "Restaurant types"
below).
Promotions (what a signed-in client sees on the home screen)
GET /api/promotions
GET /api/promotions/{id}

Active promotions only (admins manage the full set, including inactive
ones, via the admin endpoints above).
Delivery zones
GET  /api/delivery-zones
Addresses
POST   /api/addresses
GET    /api/addresses
GET    /api/addresses/{id}
PUT    /api/addresses/{id}
DELETE /api/addresses/{id}

The API is protected with JWT authentication and role-based authorization where required. GET /api/orders, GET /api/deliveries/mine and GET /api/addresses(/{id}) scope results to the authenticated user; admins get unscoped visibility via GET /api/admin/orders and GET /api/admin/deliveries, which also return deliveryId/courierId so an admin can find the ID to act on with the assign/cancel endpoints above.

Saved addresses

A user can save multiple labeled delivery addresses (e.g. "Domicile", "Bureau"),
each with a free-text address line and optional courier instructions. Exactly one
address can be marked as the default per user — setting isDefault on one
automatically clears it on every other address that user owns. There is no
geocoding or map integration yet: addressLine is plain text, not lat/lng, and
saved addresses are not yet wired into order creation (POST /api/orders still
takes its own deliveryAddress field directly). This is the "address" half of
Phase 1's "Address / geolocation model" item; geolocation itself is still open.

Delivery pricing

Delivery fees are zone-based rather than distance/GPS-based: each named neighborhood is
pre-assigned a fixed fee (currently seeded for the Bizerte area). The flow is:

Customer selects their delivery zone from the list returned by GET /api/delivery-zones
   ↓
Customer confirms the order, sending deliveryZoneId alongside the item list
   ↓
POST /api/orders looks up that zone's fee and adds it to the item total
   ↓
The order response returns deliveryZoneId, deliveryZoneName, deliveryFee, and totalAmount
(totalAmount = item total + deliveryFee)

There is no geocoding or distance calculation involved — the customer picks their zone
directly. Zones are seeded via migration and managed through the admin delivery zone
endpoints above (name and fee are updatable; there is no delete endpoint, consistent
with restaurants/categories/products — zones already referenced by past orders are
never removed).

Restaurant types

`Restaurant` carries a `type` discriminator (`RESTAURANT` or `GROCERY`)
rather than a separate entity — a grocery store is administered and browsed
exactly like a restaurant (categories, products, photos, availability), so
reusing the entity avoided duplicating that whole stack for what is, at the
data-model level, the same shape of thing. The mobile app's "Restaurants"
service passes no `type` (defaults to RESTAURANT); "Courses" passes
`?type=GROCERY`. The admin dashboard manages both from the same restaurant
screens, filterable by type.

Colis (parcel delivery)

A Colis order reuses `Order`/`Delivery`/`DeliveryZone` wholesale instead of
introducing a new entity: `Order.restaurant` is nullable, and a parcel order
has none, plus no items — just a free-text pickup address, the existing
`deliveryAddress`, and a named/phoned recipient (`recipientName`,
`recipientPhone`), who is deliberately modeled as distinct from the
account holder placing the order. It's priced the same way a restaurant
order is: the selected `DeliveryZone`'s flat fee, with no item total added
and no separate payment integration — cash on delivery, same as every other
service. `deliveryType` on the order is `PARCEL` (the same enum used to tag
restaurant vs. grocery orders). See `POST /api/orders/parcels` above.

Account recovery

There is no email or SMS channel anywhere in this app (accounts are phone
number + password only), so a "forgot password" flow with a reset link/code
isn't possible without adding that infrastructure first. Password recovery
is instead split by how each role's account is provisioned:

A signed-in user (client or courier) can change their own password via
POST /api/auth/change-password (requires the current password).
A courier locked out of their account has an admin reset it via
PATCH /api/admin/couriers/{id}/password — the same out-of-band relay
already used to hand a courier their initial password at creation.

There is no equivalent recovery path for a client who both forgot their
password and isn't signed in anywhere else; that requires a real email/SMS
channel and is out of scope until one exists.

Rate limiting

POST /api/auth/login is throttled via Symfony's built-in login_throttling
(5 failed attempts per username+IP per minute, plus an automatic 25/minute
per-IP floor across all usernames), returning 429 once exceeded.
POST /api/auth/register is limited to 5 attempts per IP per 10 minutes
(config/packages/rate_limiter.yaml) as a basic guard against spam signups.
POST /api/orders and POST /api/orders/parcels are limited to 20 attempts
per authenticated user per 10 minutes, and POST /api/auth/change-password
to 5 attempts per authenticated user per 15 minutes — both keyed by user id
rather than IP since they require auth already, guarding against a
compromised token being used to spam order creation or brute-force the
current-password check.

Order creation also bounds each request's shape: at most 50 line items per
order, and at most 100 units of a single product per line item
(App\Dto\Order\CreateOrderRequest / OrderItemRequest) — generous enough for
any real order, and small enough to keep total-price arithmetic away from
float overflow.

Error tracking

Uncaught exceptions can be reported to Sentry (sentry/sentry-symfony on the
backend, sentry_flutter on mobile). Both are no-ops until a real DSN is
supplied — SENTRY_DSN in the backend's .env.local, or
--dart-define=SENTRY_DSN=... when running/building the mobile app — so
this is inert by default and doesn't require a Sentry account to develop.

Pagination

The list endpoints most likely to grow unbounded over real usage —
admin couriers/restaurants/products/orders/deliveries, the public
restaurant/product catalogue, a client's own order history, and a
courier's own delivery queue — accept `?page=` and `?limit=` (default
page 1, limit 20, capped at 100) and return
`{"items": [...], "meta": {"page", "limit", "total", "pages"}}` instead of
a bare array. Small, admin-bounded lists (categories, delivery zones,
saved addresses) aren't paginated — there's no realistic scenario where
those grow past one page. The admin dashboard's list pages show Prev/Next
controls backed by this; the mobile app fetches a large single page for
the catalogue (administratively bounded) and a "load more" button for
order history and delivery history (the two lists that genuinely grow
per-user over time). GET /api/admin/stats backs the admin dashboard's
overview counts with dedicated COUNT queries rather than paging through
every list just to count it.

The order and delivery list endpoints (client/admin order history, a
courier's delivery queue, admin delivery oversight) eager-join every to-one
relation their response needs (restaurant, delivery zone, delivery, courier,
user) and batch-fetch each page's order items in one follow-up query
(`OrderRepository::hydrateItems`) — a page of N orders costs a small,
constant number of queries rather than N+1 lazily-loaded ones. Covered by
`OrderApiTest::testListingOrdersDoesNotIssueAQueryPerOrder` and
`DeliveryApiTest::testListingOwnDeliveriesDoesNotIssueAQueryPerDelivery`,
which assert the actual query count via Doctrine's own debug middleware
rather than just checking the response shape.

Push notifications

Delivery status changes can push a notification via Firebase Cloud
Messaging: a courier is notified when a delivery is assigned to them, and
a client is notified once their order is on its way and once it's
delivered. The mobile app registers/unregisters its FCM token against the
signed-in account via POST/DELETE /api/notifications/device-token
(a device can belong to at most one account at a time — registering a
token already owned by someone else reassigns it, since that means the
same device switched accounts). Both the backend (kreait/firebase-php)
and the mobile app are inert without a real Firebase project — see
FIREBASE_CREDENTIALS in backend/.env.example and the FIREBASE_* dart-defines
documented in mobile/lib/config.dart — so this doesn't require a Firebase
account to develop, and a failed or skipped push never blocks the
delivery/order action that triggered it.

Client order cancellation

A client can cancel their own order via POST /api/orders/{id}/cancel while
its delivery is still unclaimed (PENDING) or just assigned (ASSIGNED) —
the same boundary DeliveryService::cancelDelivery already enforces for
admin cancellation, reused here rather than duplicated. Once a courier has
accepted it, the client can no longer self-cancel. The order response also
carries deliveryStatus, courierName and courierPhone (once a courier is
assigned) so the mobile client order screen can show who's delivering and
call them — the reverse of the courier-can-call-the-client direction that
already existed.

Courier availability

A courier can self-report availability via PATCH /api/auth/availability
(GET /api/auth/me and every other user-response endpoint returns
isAvailable too). This is separate from isActive, which is an admin-only
deactivation — a courier stepping away for a break sets their own
availability; only an admin can deactivate the account entirely. The
mobile dashboard's availability toggle is wired to this field rather than
being purely cosmetic local state.

Live courier locations

A courier's mobile app reports its GPS position via POST
/api/couriers/location whenever it has a non-terminal, non-pending delivery
(assigned, accepted, picked up, or on the way) and stops otherwise — no
location is collected once a delivery is delivered/cancelled/failed or
before one is assigned. The admin dashboard's courier map (GET
/api/admin/couriers/locations)
plots every active courier with a reported position, refreshing on a
timer, so dispatch can see where couriers actually are without a client or
courier-facing map/navigation feature (still not built — see "Not yet in
the app" below).

Promotions

Admins create promotions (title, description, a percentage/fixed discount
value, an optional promo code, a start/end window, an optional photo, and
an optional linked restaurant) via the /api/admin/promotions endpoints
above; GET /api/promotions (no /admin prefix) returns only the active ones,
which is what the mobile client home screen's promotions carousel
displays. A promotion isn't applied to an order automatically — there's no
coupon-code redemption flow yet, this is display-only marketing surface for
now.

Docker / CD pipeline

The backend (backend/Dockerfile, php-apache) and admin dashboard
(admin/Dockerfile, a static Vite build served by nginx) each build into a
standalone image. .github/workflows/cd.yml builds and pushes both to
GHCR (ghcr.io/<owner>/hssan-delivery-backend and -admin, tagged :latest
and :<commit-sha>) on every push to main — this is the "CD" half; the
existing backend/admin/mobile CI workflows already gate every merge with
lint + tests. Backend image details: JWT keys are generated on first boot
from JWT_PASSPHRASE (never baked into the image, matching config/jwt/*.pem
being gitignored), and pending Doctrine migrations run automatically on
every boot.

The workflow's final step in each job SSHes into a staging host and runs
`docker compose pull && up -d` — inert until three repo secrets exist
(STAGING_SSH_HOST, STAGING_SSH_USER, STAGING_SSH_KEY), so the pipeline
runs end-to-end (build + push) without requiring a staging server to
exist yet. docker-compose.staging.yml documents the layout such a server
needs (backend + admin + postgres, referencing the GHCR images) — it's a
template to fill in and place on the staging host, not something CI runs
itself.

Backend setup
Requirements
PHP 8.2+
Composer
PostgreSQL
OpenSSL
Git
Install dependencies
cd backend
composer install
Configure the environment

Create your local environment file from the example:

cp .env.example .env

Then configure:

APP_ENV
APP_SECRET
DATABASE_URL
JWT_SECRET_KEY
JWT_PUBLIC_KEY
JWT_PASSPHRASE
CORS_ALLOW_ORIGIN

CORS_ALLOW_ORIGIN is a regex of browser origins allowed to call /api/* (via
nelmio/cors-bundle). Needed for any browser-based client — the admin
dashboard in particular. The example default covers any localhost/127.0.0.1
port for local development; tighten it to the real deployed origin(s) in
production.

The local .env file must never be committed.

JWT keys

Create the JWT directory:

mkdir -p config/jwt

Generate the private key:

openssl genrsa -out config/jwt/private.pem 4096

Generate the public key:

openssl rsa \
  -in config/jwt/private.pem \
  -pubout \
  -out config/jwt/public.pem

JWT key files are ignored by Git.

Database

Configure DATABASE_URL for your PostgreSQL installation.

For example:

DATABASE_URL="postgresql://USER:PASSWORD@127.0.0.1:5433/hssan_delivery?serverVersion=16&charset=utf8"

Run migrations:

php bin/console doctrine:migrations:migrate

Clear the Symfony cache:

php bin/console cache:clear
Seed data (dev / test)

Load a reproducible set of demo data — one account per role, a small
catalogue, and a few orders/deliveries in different states:

composer fixtures

Or rebuild the whole local database from scratch (drop, create, migrate,
seed) in one step:

composer db-reset

The fixture is idempotent: if its admin account already exists it does
nothing, so `composer fixtures` is safe to re-run. It never touches the
migration-seeded delivery zones. Seeded credentials (phone / password):

admin     20000000 / admin1234
courier   21000001 / courier1234   (active)
courier   21000002 / courier1234   (deactivated)
client    22000001 / client1234
client    22000002 / client1234

Run the backend

Using the Symfony CLI:

symfony server:start

Or use the appropriate PHP/Symfony development server for your environment.

Testing

The backend contains integration tests covering:

client registration
login
authenticated /api/auth/me
wrong passwords
duplicate phone numbers
invalid registration data
admin courier creation
courier authentication
courier authorization
self-service password change, including the wrong-current-password case
admin-initiated courier password reset (account recovery)
login throttling after repeated failed attempts
registration rate limiting
admin restaurant, category, product and delivery zone management
restaurant/product photo upload, replace and remove
restaurant/product delete, including the has-existing-orders conflict guard
public catalogue (available restaurants/categories/products only, any signed-in role)
admin order and delivery visibility
admin courier listing and deactivation
deactivated accounts cannot log in
deactivated couriers cannot be assigned deliveries
saved address CRUD and per-user ownership scoping
default-address invariant (setting one clears the others)
delivery assignment
delivery lifecycle transitions
invalid delivery transitions
courier decline (reverts an assigned delivery to pending)
wrong-courier protection
non-courier protection
order/delivery status synchronization
pagination (page/limit, envelope shape, boundary behavior) on couriers, restaurants, products, orders, and deliveries
admin dashboard stats (COUNT-based, correct regardless of list size)
device-token registration/unregistration, including reassignment when a device switches accounts
a delivery notification firing without blocking the underlying status change even when a device token is registered
restaurant type filtering (RESTAURANT vs. GROCERY) on the public catalogue
Colis parcel order creation (no restaurant, priced off the zone fee alone) and its validation/not-found error cases
promotion CRUD, activation, and photo upload/replace/remove, including the active-only filter on the public endpoint
courier location reporting and the admin courier-locations endpoint
the public GET /api/delivery-zones endpoint
order/delivery list endpoints eager-load correctly (a small, constant query
count per page rather than one query per row) — see "Pagination" above
a browser (cookie-based) client's login response never carries the JWT in
its body — see "Admin authentication" above
order/parcel creation and password change are rate-limited per user, and
order creation rejects oversized requests (too many line items, or too
large a quantity on one item) — see "Rate limiting" above

It also contains unit tests for the pure logic that backs those workflows: the
decimal/millimes money conversion and the delivery-to-order status mapping.

Run the complete test suite (this resets the test database first):

composer test

Or, against an already-migrated test database:

php bin/phpunit

Current baseline:

228 tests
1383 assertions

Tests share a single Postgres database rather than running each in its own
transaction, so re-running `php bin/phpunit` without resetting the database
first (`composer test`, or the `test-db-reset` composer script) can fail on
leftover data from the previous run.
Continuous Integration

GitHub Actions runs three workflows on pushes and pull requests targeting
`dev` and `main`, one per component:

.github/workflows/backend.yml   PHP 8.2 · PostgreSQL 16 · composer validate ·
                                temporary JWT keys · migrate · schema:validate ·
                                PHPUnit
.github/workflows/admin.yml     Node 20 · npm ci · oxlint · tsc + vite build
.github/workflows/mobile.yml    Flutter stable · pub get · dart format check ·
                                flutter analyze · flutter test

The backend job uses temporary JWT credentials and an isolated PostgreSQL database.

Dependabot (.github/dependabot.yml) opens a PR for outdated dependencies
across composer, npm, pub, Docker base images, and GitHub Actions — these
still go through the same CI gate and need a human merge, they aren't
auto-merged.

Security

Never commit:

.env
.env.local
JWT private keys
production credentials
production database passwords

Use:

backend/.env.example

as the template for local configuration.

Any secret that has previously been committed to Git history must be considered exposed and should be rotated before staging or production deployment.

Set JWT_COOKIE_SECURE=true once the admin dashboard and backend are served
over HTTPS in production — see "Admin authentication" above. It defaults to
false, which is correct for local development but wrong for production over
plain HTTP.

Current implementation status
Backend

Currently implemented:

Symfony REST API
JWT authentication
client registration
login
authenticated profile endpoint
restaurant/product management, including photos, for admins
grocery stores as a second Restaurant type (RESTAURANT/GROCERY), browsable
via ?type on the public catalogue
public catalogue for browsing/ordering (any signed-in account)
saved delivery addresses
order creation (restaurant/grocery)
Colis parcel order creation — no restaurant, priced off the zone fee alone
zone-based delivery pricing
automatic delivery creation
delivery assignment
courier delivery lifecycle
courier live GPS location reporting while a delivery is active
admin courier creation
admin courier listing and deactivation
admin order and delivery visibility
admin promotion management (CRUD, activation, photo)
admin courier-location map data
role-based authorization
order/delivery status synchronization
self-service password change
admin-initiated courier password reset (account recovery)
login throttling and registration rate limiting
error tracking (Sentry, inert until a DSN is configured)
pagination on every list endpoint likely to grow unbounded
admin dashboard stats via dedicated COUNT queries
push notifications on delivery status changes (FCM, inert until a Firebase project is configured)
client-initiated order cancellation (while still unclaimed or just assigned)
courier self-service availability toggle
httpOnly-cookie session for the admin dashboard (see "Admin authentication" above)
integration tests
GitHub Actions CI
Mobile

The Flutter application (`mobile/`) now serves **both personas** — courier
and client — from a single app, branching on the signed-in account's role
right after login (`ROLE_LIVREUR` → courier dashboard, `ROLE_CLIENT` →
client home). See `mobile/README.md`.

Courier:

courier authentication (ROLE_LIVREUR only)
a dashboard (real self-service availability toggle backed by PATCH
/api/auth/availability, today's stats, current delivery shortcut)
an available-deliveries screen to accept/decline a proposed delivery
(shows "Colis" + pickup/drop-off addresses for a parcel proposal, the
restaurant name for a restaurant/grocery one)
delivery queue (GET /api/deliveries/mine, active vs. history, "load more" for older history)
delivery details — pickup, drop-off, customer/recipient, items, pricing;
a Colis job shows the pickup address and named recipient instead of a
restaurant and customer
accept / decline / pickup / on-the-way / delivered / fail actions
a delivery-confirmed screen showing the amount collected
tap-to-call the customer (or the recipient, for a Colis job)
live GPS location reporting while a delivery is active (backs the admin
courier map, see "Live courier locations" above)
change password (dashboard menu)
push notification registration (FCM, inert without a Firebase project — see "Push notifications" above)

Client:

client registration and authentication (ROLE_CLIENT)
a home screen with four service cards — Restaurants, Courses (grocery),
and Colis (parcel) are live; Factures (bill payment) is still a "coming
soon" placeholder — plus a promotions carousel (GET /api/promotions)
restaurant browsing with a search box (GET /api/restaurants)
grocery store browsing the same way, via the "Courses" service (GET
/api/restaurants?type=GROCERY)
menu browsing by category with add-to-cart (GET .../categories, .../products)
a cart (single-restaurant, quantity steppers, restaurant-switch confirmation)
checkout (delivery address, delivery zone, optional note, live total)
Colis: a dedicated parcel form (pickup address, drop-off address, named
recipient, delivery zone, optional note) — POST /api/orders/parcels,
bypassing the cart/checkout flow entirely since there's no catalogue or
restaurant involved
order placement and a confirmation screen (copy branches on whether the
order is a Colis parcel or a restaurant/grocery order)
order history and order detail (GET /api/orders, GET /api/orders/{id},
"load more" for older orders) — a Colis order's detail screen shows pickup
address and recipient instead of a restaurant and an item list
order tracking that polls for status changes and shows/calls the assigned
courier once one exists, plus self-service cancellation while still
possible (POST /api/orders/{id}/cancel)
a profile screen (account info, change password, sign out)
push notification registration (FCM, inert without a Firebase project — see "Push notifications" above)

Not yet in the app:

Factures (bill payment) — still a placeholder, no biller integration
map / navigation integration
saved-address picker in checkout (the backend has `/api/addresses`; checkout
currently takes a free-text address)
Admin dashboard

The React/Vite admin dashboard (`admin/`) is implemented and covers:

admin authentication (httpOnly-cookie session — see "Admin authentication" above),
including a global handler that signs the admin out and redirects to
/login on a 401 from any request, not just the initial session check
dashboard (counts overview, backed by GET /api/admin/stats)
order visibility (list + detail, paginated with Prev/Next) — a Colis
order's detail shows pickup address and recipient instead of a restaurant
delivery monitoring (list + detail, paginated with Prev/Next)
delivery assignment / cancellation
courier management (list, create, activate/deactivate, password reset, paginated with Prev/Next)
a live courier map (GET /api/admin/couriers/locations)
promotion management (create/edit/delete, activate/deactivate, photo)
restaurant management (including delete and photo upload/replace/remove,
paginated with Prev/Next) — covers both restaurants and grocery stores
category management
product/menu management (including delete and photo upload/replace/remove, paginated with Prev/Next)
delivery zone management
client-side guards ahead of the backend's own validation: money-shaped
fields (price/fee/discount value) reject non-numeric input via the
browser's native form validation, a promotion's end date is checked
against its start date before submit, and a photo upload is checked
against the backend's 5 MB limit before it's sent rather than after
Playwright e2e coverage (admin/e2e/)

Not yet implemented in the dashboard:

operational statistics beyond simple counts
Future services

The platform is intended to expand beyond restaurant delivery. Of the five
originally planned service areas, three are now live (see "Client" above);
two remain:

Restaurant delivery (done)
Supermarket/grocery delivery (done — see "Restaurant types" above)
Parcel delivery (done — see "Colis (parcel delivery)" above)
Bill payment (not started — needs a biller catalogue and payment method
integration this project has no information about yet; the mobile "Factures"
card is a placeholder pending that decision)
Money transfer (not started — needs a wallet/balance per user and a
transaction ledger, plus a money-transmission licensing review)

Development roadmap
Phase 0 — Backend stabilization
 Authentication / JWT
 Order MVP
 Delivery lifecycle
 Order / Delivery synchronization
 Admin courier creation
 Integration tests
 Dead-code cleanup
 Formatting
 GitHub Actions CI
 Environment example
 Remove tracked .env
Phase 1 — Backend domain completeness
 Restaurant management
 Category management
 Product management
 Admin order management (done — see "Admin order management" and "Admin delivery oversight" above)
 Courier management improvements (done — list/show/deactivate, see "Admin courier management" above)
 Delivery pricing (done — zone-based, see "Delivery pricing" above, including admin CRUD for zones)
 Address / geolocation model (address half done — see "Saved addresses" above; geolocation/lat-lng still open)
Phase 2 — Restaurant operations
 Order confirmation
 Order preparation workflow
 Ready-for-pickup workflow
 Restaurant operational endpoints
Phase 3 — Flutter application (done — see "Mobile" above)
 Client application shell (done)
 Client authentication (done)
 Restaurant browsing (done)
 Catalogue (done)
 Cart (done)
 Checkout (done)
 Order tracking (done — history + detail, load more, push notifications on status changes)
 Courier application (done)
 Courier delivery queue (done)
 Delivery status actions (done)
Phase 4 — React admin dashboard (done — see admin/README.md)
 Admin authentication
 Dashboard
 Order management
 Delivery monitoring
 Courier management
 Courier assignment
 Restaurant management
 Category/product management
Phase 5 — Real-time features
 Push notifications (done — delivery assigned/on-the-way/delivered via FCM, inert until a Firebase project is configured; see "Push notifications" above)
 Live delivery status
 Courier location updates (done — GPS reporting while active + an admin courier map, see "Live courier locations" above; polling-based, not a live socket)
 Live delivery tracking
 Maps/navigation
Phase 6 — Additional services

`Order`/`Delivery` turned out not to need a schema rewrite to support more
service types: `Order.restaurant` was made nullable, `Order` gained a
handful of new nullable columns (`pickupAddress`, `recipientName`,
`recipientPhone`), and the existing `DeliveryType` enum
(`RESTAURANT`, `BILL`, `GROCERY`, `PARCEL` — in `src/Enum/DeliveryType.php`)
was wired in as a discriminator, reusing `Order`/`Delivery`/`DeliveryZone`
wholesale for both grocery orders (as a second `Restaurant` type — see
"Restaurant types" above) and parcel orders (see "Colis (parcel delivery)"
above). No polymorphic rewrite was needed in the end.

Bill payment and money transfer are a different shape of problem — not
delivery workflows at all. They need a wallet/balance per user and a
transaction ledger, not a courier. Money transfer in particular carries
money-transmission licensing considerations that depend on jurisdiction and
should be scoped before implementation starts.

 Supermarket/grocery delivery (done — see "Restaurant types" above)
 Parcel delivery (done — see "Colis (parcel delivery)" above)
 Bill payment (biller integration, payment method, transaction ledger)
 Money transfer (wallet/balance, transaction ledger, licensing review)
Phase 7 — Production infrastructure
 Docker (done — backend + admin images, see "Docker / CD pipeline" above)
 CD pipeline (done — build/push to GHCR on merge to main; staging deploy inert until a host exists, see "Docker / CD pipeline" above)
 Staging environment (host not provisioned yet — docker-compose.staging.yml is ready to place on one)
 Production environment
 Nginx / HTTPS (nginx serves the admin image; HTTPS itself is a staging/production host concern, not yet set up)
 Database backups
 Monitoring
 Error tracking (done — Sentry, inert until a DSN is configured; see "Error tracking" above)
Phase 8 — Production hardening
 Security review
 Rate limiting (done — login throttling + registration limiter, see "Rate limiting" above)
 Authentication hardening (partial — password change/reset done, see
"Account recovery" above; admin session moved from localStorage to an
httpOnly cookie, see "Admin authentication" above; no 2FA)
 Performance testing
 Load testing
 Beta rollout
 Production launch
Repository branches

The main development branch is:

dev

The production branch is:

main

Feature work should preferably be developed on dedicated branches and merged into dev through pull requests.

Development workflow

Recommended Git workflow:

feature/<name>
      ↓
pull request
      ↓
dev
      ↓
CI
      ↓
testing
      ↓
main
      ↓
production

Every change should keep the automated test suite green before being merged.
