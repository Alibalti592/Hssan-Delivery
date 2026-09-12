# Hssan Delivery — Admin Dashboard

React + Vite + TypeScript admin dashboard for the Hssan Delivery backend.

## Requirements

- Node.js 20+
- The backend running and reachable (see `../backend/README.md`)

## Setup

```
npm install
cp .env.example .env   # set VITE_API_URL if the backend isn't at http://127.0.0.1:8000
npm run dev
```

The backend must have CORS configured to allow this dashboard's origin — see
`CORS_ALLOW_ORIGIN` in `../backend/.env.example`. The default there already covers
any `localhost`/`127.0.0.1` port, which includes Vite's default `5173`.

## What's here

Screens, all backed by real endpoints (no mock data):

- **Login** — JWT auth, blocks non-`ROLE_ADMIN` accounts client-side (the backend
  enforces this too via `access_control`).
- **Dashboard** — restaurant/zone/courier/order counts, backed by a dedicated
  `GET /api/admin/stats` summary endpoint rather than paging through every
  list just to count it.
- **Restaurants** — list (paginated, Prev/Next), create, edit, open/close
  toggle, photo upload/replace/remove.
- **Categories** / **Products** — scoped per restaurant, reached from a
  restaurant's detail page. Products list is paginated (Prev/Next); products
  also support photo upload/replace/remove.
- **Delivery Zones** — list, create, edit (name + fee).
- **Couriers** — list (paginated, Prev/Next), create, view,
  activate/deactivate, reset password (relayed to the courier out-of-band).
- **Orders** — list (paginated, Prev/Next), detail (customer, items, pricing
  breakdown, linked delivery).
- **Deliveries** — list (paginated, Prev/Next), detail, assign to a courier
  (dropdown fetches the full courier roster regardless of page size), cancel.

## What's intentionally not here

- No delete for restaurants/categories/products/delivery zones — the backend
  doesn't expose delete endpoints for these (they can be referenced by past
  orders), only availability/update. Couriers likewise: deactivate, not delete.

## Build

```
npm run build
```

Type-checks (`tsc -b`) then builds to `dist/`.

## Test

```
npx playwright install --with-deps chromium   # first run only
npm run test:e2e
```

End-to-end tests (`e2e/`) drive the real app against a real Vite dev
server, but never a real backend — every test mocks the exact
`**/api/**` calls it needs with `page.route()` (see `e2e/mockApi.ts`)
before navigating, so the suite needs no backend or database, locally
or in CI. Covers: the login gate (redirect when signed out, admin
sign-in, non-admin rejection), the dashboard stats summary, and
Prev/Next pagination on the couriers list.
