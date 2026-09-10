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

Current status: The Symfony backend is the most advanced component, followed by
the admin dashboard (covers restaurant/category/product/delivery-zone/courier
management and order/delivery visibility — see `admin/README.md`). The Flutter
application is not yet implemented as a production-ready application.

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
Planned administration dashboard
React
Vite
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
browse the available catalogue
save multiple labeled delivery addresses
create orders
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
Admin

The administrator can currently:

authenticate
create courier accounts
list and view courier accounts
deactivate/reactivate a courier account
view all orders and deliveries
assign deliveries to couriers
cancel eligible deliveries

Additional administration features are planned.

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
POST /api/auth/register
POST /api/auth/login
GET  /api/auth/me
Admin courier management
POST  /api/admin/couriers
GET   /api/admin/couriers
GET   /api/admin/couriers/{id}
PATCH /api/admin/couriers/{id}/active
Admin restaurant management
POST   /api/admin/restaurants
GET    /api/admin/restaurants
GET    /api/admin/restaurants/{id}
PUT    /api/admin/restaurants/{id}
PATCH  /api/admin/restaurants/{id}/availability
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
PATCH  /api/admin/products/{id}/availability
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
Delivery management
GET  /api/deliveries/mine

POST /api/deliveries/{id}/assign/{courierId}
POST /api/deliveries/{id}/accept
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
GET  /api/orders
GET  /api/orders/{id}
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
admin restaurant, category, product and delivery zone management
admin order and delivery visibility
admin courier listing and deactivation
deactivated accounts cannot log in
deactivated couriers cannot be assigned deliveries
saved address CRUD and per-user ownership scoping
default-address invariant (setting one clears the others)
delivery assignment
delivery lifecycle transitions
invalid delivery transitions
wrong-courier protection
non-courier protection
order/delivery status synchronization

It also contains unit tests for the pure logic that backs those workflows: the
decimal/millimes money conversion and the delivery-to-order status mapping.

Run the complete test suite (this resets the test database first):

composer test

Or, against an already-migrated test database:

php bin/phpunit

Current baseline:

90 tests
546 assertions

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

Current implementation status
Backend

Currently implemented:

Symfony REST API
JWT authentication
client registration
login
authenticated profile endpoint
restaurant/product foundations
saved delivery addresses
order creation
zone-based delivery pricing
automatic delivery creation
delivery assignment
courier delivery lifecycle
admin courier creation
admin courier listing and deactivation
admin order and delivery visibility
role-based authorization
order/delivery status synchronization
integration tests
GitHub Actions CI
Mobile

The Flutter application (`mobile/`) currently implements the **courier app** —
see `mobile/README.md`:

courier authentication (ROLE_LIVREUR only)
delivery queue (GET /api/deliveries/mine, active vs. history)
delivery details (pickup, drop-off, customer, items, pricing)
accept / pickup / on-the-way / delivered / fail actions
tap-to-call the customer

Not yet in the app:

the entire client persona (browsing, cart, checkout, order tracking)
push notifications
map / navigation integration

The client persona is also blocked on the backend: there is no public
catalogue endpoint yet (restaurant/product listing is ROLE_ADMIN only).
Admin dashboard

The React/Vite admin dashboard (`admin/`) is implemented and covers:

admin authentication
dashboard (counts overview)
order visibility (list + detail)
delivery monitoring (list + detail)
delivery assignment / cancellation
courier management (list, create, activate/deactivate)
restaurant management
category management
product/menu management
delivery zone management

Not yet implemented in the dashboard:

operational statistics beyond simple counts
image/photo upload for restaurants or products
pagination on any list (matches the backend, which doesn't paginate yet either)
Future services

The platform is intended to expand beyond restaurant delivery.

Planned service areas include:

Restaurant delivery
Supermarket delivery
Parcel delivery
Bill payment
Money transfer

These services will be introduced after the core food-delivery workflow is stable.

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
Phase 3 — Flutter application
 Client application shell
 Client authentication
 Restaurant browsing
 Catalogue
 Cart
 Checkout
 Order tracking
 Courier application
 Courier delivery queue
 Delivery status actions
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
 Push notifications
 Live delivery status
 Courier location updates
 Live delivery tracking
 Maps/navigation
Phase 6 — Additional services

The current schema is hard-coupled to restaurant delivery: `Order` requires a
`Restaurant` and `Delivery` is always tied 1:1 to an `Order`. None of the
services below can be added on top of that as-is — `Order`/`Delivery` need
to be generalized first (e.g. `Order` becoming polymorphic across a
restaurant order, a parcel job, or a supermarket cart) before any service
work starts. A `DeliveryType` enum (`RESTAURANT`, `SUPERMARKET`, `PARCEL`)
already exists in `src/Enum/DeliveryType.php` as a placeholder but isn't
wired into anything yet.

Bill payment and money transfer aren't delivery workflows at all — they need
a wallet/balance per user and a transaction ledger, not a courier. Money
transfer in particular carries money-transmission licensing considerations
that depend on jurisdiction and should be scoped before implementation
starts.

 Generalize Order/Delivery schema (prerequisite for every item below)
 Supermarket delivery
 Parcel delivery
 Bill payment (biller integration, payment method, transaction ledger)
 Money transfer (wallet/balance, transaction ledger, licensing review)
Phase 7 — Production infrastructure
 Docker
 Staging environment
 Production environment
 Nginx / HTTPS
 Database backups
 Monitoring
 Error tracking
Phase 8 — Production hardening
 Security review
 Rate limiting
 Authentication hardening
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
