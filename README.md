# Hssan Delivery

Hssan Delivery is a delivery platform currently under development.

The project is structured around a Symfony REST API backend, a Flutter mobile application, and a planned React/Vite administration dashboard.

## Current project structure

```text
Hssan-Delivery/
├── backend/    # Symfony REST API
├── mobile/     # Flutter mobile application
├── admin/      # Planned React + Vite dashboard
└── .github/
    └── workflows/
        └── backend.yml

Current status: The Symfony backend is the most advanced component. The Flutter application and React admin dashboard are not yet implemented as production-ready applications.

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
create orders
receive a linked delivery
Livreur

A courier account is created by an administrator.

The courier receives credentials from the administrator and uses them to authenticate through the mobile application.

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
POST /api/admin/couriers
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
Delivery management
GET  /api/deliveries/mine

POST /api/deliveries/{id}/assign/{courierId}
POST /api/deliveries/{id}/accept
POST /api/deliveries/{id}/pickup
POST /api/deliveries/{id}/on-the-way
POST /api/deliveries/{id}/delivered
POST /api/deliveries/{id}/cancel
POST /api/deliveries/{id}/fail
Orders
POST /api/orders
GET  /api/orders
GET  /api/orders/{id}

The API is protected with JWT authentication and role-based authorization where required. Order and delivery listing endpoints scope results to the authenticated user; there is currently no admin-wide order listing (tracked in Phase 1 of the roadmap below).

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
admin restaurant, category and product management
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

GitHub Actions runs the backend CI workflow on pushes and pull requests targeting:

dev
main

Workflow file:

.github/workflows/backend.yml

The CI pipeline performs:

Checkout
   ↓
PHP 8.2
   ↓
PostgreSQL 16
   ↓
Composer validation
   ↓
Composer install
   ↓
Generate temporary JWT test keys
   ↓
Create test database
   ↓
Run migrations
   ↓
Validate Doctrine schema
   ↓
Run PHPUnit

The CI environment uses temporary JWT credentials and an isolated PostgreSQL database.

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
order creation
automatic delivery creation
delivery assignment
courier delivery lifecycle
admin courier creation
role-based authorization
order/delivery status synchronization
integration tests
GitHub Actions CI
Mobile

The Flutter application is still under development.

Planned client features:

authentication
restaurant browsing
categories
product browsing
cart
checkout
order history
order tracking
notifications
profile
address management

Planned courier features:

courier authentication
delivery queue
delivery details
accept delivery
pickup
on-the-way
delivered
failed delivery
notifications
map/navigation integration
Admin dashboard

The React/Vite admin dashboard is planned but is not yet implemented.

Planned features:

admin authentication
dashboard
order management
delivery monitoring
courier management
courier assignment
restaurant management
category management
product/menu management
operational statistics
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
 Admin order management
 Courier management improvements
 Delivery pricing
 Address / geolocation model
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
Phase 4 — React admin dashboard
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
 Supermarket delivery
 Parcel delivery
 Bill payment
 Money transfer
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
