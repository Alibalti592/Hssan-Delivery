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
- **Dashboard** — restaurant/zone/courier/order counts.
- **Restaurants** — list, create, edit, open/close toggle.
- **Categories** / **Products** — scoped per restaurant, reached from a
  restaurant's detail page.
- **Delivery Zones** — list, create, edit (name + fee).
- **Couriers** — list, create, view, activate/deactivate.
- **Orders** — list, detail (customer, items, pricing breakdown, linked delivery).
- **Deliveries** — list, detail, assign to a courier, cancel.

## What's intentionally not here

- No delete for restaurants/categories/products/delivery zones — the backend
  doesn't expose delete endpoints for these (they can be referenced by past
  orders), only availability/update. Couriers likewise: deactivate, not delete.
- No pagination — the backend doesn't paginate list endpoints yet, so neither
  does this dashboard.
- No restaurant photo/image upload — `Restaurant`/`Product` have no image field
  in the backend yet.

## Build

```
npm run build
```

Type-checks (`tsc -b`) then builds to `dist/`.
