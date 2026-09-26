import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function promotion(id: number, overrides: Record<string, unknown> = {}) {
  return {
    id,
    title: `Promo ${id}`,
    description: null,
    photoUrl: null,
    discountType: 'PERCENTAGE',
    discountValue: '10.000',
    promoCode: null,
    startAt: '2026-01-01T00:00:00+00:00',
    endAt: '2026-12-31T00:00:00+00:00',
    isActive: true,
    restaurantId: null,
    restaurantName: null,
    items: [],
    productId: null,
    createdAt: '2026-01-01T00:00:00+00:00',
    updatedAt: '2026-01-01T00:00:00+00:00',
    ...overrides,
  };
}

test('lists promotions with discount and status', async ({ page }) => {
  await mockStats(page);
  await page.route('**/api/admin/promotions**', (route) => {
    if (route.request().method() !== 'GET') return route.fallback();
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        items: [
          promotion(1, { title: 'Summer Sale', discountValue: '15.000' }),
          promotion(2, { title: 'Inactive Promo', isActive: false }),
          promotion(3, {
            title: '2 Sandwiches Chawarma',
            discountType: 'FIXED_PRICE',
            discountValue: '11.000',
            endAt: null,
            restaurantId: 4,
            restaurantName: 'Chawarma House',
          }),
        ],
        meta: { page: 1, limit: 20, total: 3, pages: 1 },
      }),
    });
  });

  await loginAsAdmin(page);
  await page.goto('/promotions');

  await expect(page.getByText('Summer Sale')).toBeVisible();
  await expect(page.getByText('15.000%')).toBeVisible();
  await expect(page.getByText('Inactive Promo')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Hide from app' })).toHaveCount(2);
  await expect(page.getByRole('button', { name: 'Show in app' })).toBeVisible();
  await expect(page.getByText('Hidden', { exact: true })).toBeVisible();
  await expect(page.getByText('Offer · 11.000 DT')).toBeVisible();
  await expect(page.getByText('no end date')).toBeVisible();
});

test('hiding a promotion from the app calls the active endpoint', async ({ page }) => {
  await mockStats(page);
  let patchedActive: unknown;

  await page.route('**/api/admin/promotions**', (route) => {
    const method = route.request().method();

    if (method === 'GET') {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          items: [promotion(1, { title: 'Weekend Deal' })],
          meta: { page: 1, limit: 20, total: 1, pages: 1 },
        }),
      });
    }

    if (method === 'PATCH') {
      const body = route.request().postDataJSON() as { isActive: boolean };
      patchedActive = body.isActive;
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(promotion(1, { title: 'Weekend Deal', isActive: body.isActive })),
      });
    }

    return route.fallback();
  });

  await loginAsAdmin(page);
  await page.goto('/promotions');

  await expect(page.getByText('Weekend Deal')).toBeVisible();
  await page.getByRole('button', { name: 'Hide from app' }).click();

  await expect.poll(() => patchedActive).toBe(false);
});

test('creates a new promotion and returns to its edit page', async ({ page }) => {
  await mockStats(page);

  await page.route('**/api/admin/restaurants**', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ items: [], meta: { page: 1, limit: 100, total: 0, pages: 1 } }),
    }),
  );

  let createdBody: Record<string, unknown> | undefined;

  await page.route('**/api/admin/promotions**', (route) => {
    const method = route.request().method();
    const url = new URL(route.request().url());

    if (method === 'GET' && /\/api\/admin\/promotions\/\d+$/.test(url.pathname)) {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(promotion(9, { title: 'New Launch Promo' })),
      });
    }

    if (method === 'GET') {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ items: [], meta: { page: 1, limit: 20, total: 0, pages: 1 } }),
      });
    }

    if (method === 'POST') {
      createdBody = route.request().postDataJSON();
      return route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify(promotion(9, { title: 'New Launch Promo' })),
      });
    }

    return route.fallback();
  });

  await loginAsAdmin(page);
  await page.goto('/promotions');
  await page.getByRole('link', { name: '+ New promotion' }).click();
  await expect(page).toHaveURL('/promotions/new');

  await page.getByLabel('Title').fill('New Launch Promo');
  await page.getByLabel(/Discount value/).fill('10');
  await page.getByLabel('Starts at').fill('2026-01-01T00:00');
  await page.getByLabel('Ends at').fill('2026-12-31T00:00');
  await page.getByRole('button', { name: 'Create promotion' }).click();

  await expect(page).toHaveURL(/\/promotions\/9\/edit$/);
  await expect.poll(() => createdBody?.title).toBe('New Launch Promo');
});

test('rejects an end date before the start date without calling the API', async ({ page }) => {
  await mockStats(page);

  await page.route('**/api/admin/restaurants**', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ items: [], meta: { page: 1, limit: 100, total: 0, pages: 1 } }),
    }),
  );

  let createCalled = false;

  await page.route('**/api/admin/promotions**', (route) => {
    if (route.request().method() === 'POST') {
      createCalled = true;
    }
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ items: [], meta: { page: 1, limit: 20, total: 0, pages: 1 } }),
    });
  });

  await loginAsAdmin(page);
  await page.goto('/promotions/new');

  await page.getByLabel('Title').fill('Backwards Promo');
  await page.getByLabel(/Discount value/).fill('10');
  await page.getByLabel('Starts at').fill('2026-12-31T00:00');
  await page.getByLabel('Ends at').fill('2026-01-01T00:00');
  await page.getByRole('button', { name: 'Create promotion' }).click();

  await expect(page.getByText('End date must be after the start date.')).toBeVisible();
  expect(createCalled).toBe(false);
});

test('creates a fixed-price offer with its included items and no end date', async ({ page }) => {
  await mockStats(page);

  await page.route('**/api/admin/restaurants**', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        items: [{ id: 4, name: 'Chawarma House' }],
        meta: { page: 1, limit: 100, total: 1, pages: 1 },
      }),
    }),
  );

  let createdBody: Record<string, unknown> | undefined;

  await page.route('**/api/admin/promotions**', (route) => {
    const method = route.request().method();

    if (method === 'POST') {
      createdBody = route.request().postDataJSON();
      return route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify(promotion(12, { ...createdBody, productId: 30 })),
      });
    }

    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(promotion(12, { ...createdBody, productId: 30 })),
    });
  });

  await loginAsAdmin(page);
  await page.goto('/promotions/new');

  await page.getByLabel('Title').fill('2 Sandwiches Chawarma');
  await page.getByLabel('Discount type').selectOption('FIXED_PRICE');

  // An offer has a price, lists what it includes, and needs a restaurant
  // instead of a promo code.
  await expect(page.getByLabel(/Promo code/)).toHaveCount(0);
  await page.getByLabel('Offer price (DT)').fill('11.000');
  await page.getByRole('button', { name: '+ Add item' }).click();
  await page.getByLabel('Included item 1', { exact: true }).fill('2 Sandwichs Chawarma au Poulet Grillé');
  await page.getByRole('button', { name: '+ Add item' }).click();
  await page.getByLabel('Included item 2', { exact: true }).fill('Frites dorées');
  await page.getByLabel('Restaurant').selectOption('4');
  await page.getByLabel('Starts at').fill('2026-01-01T00:00');
  await page.getByLabel(/No end date/).check();
  await expect(page.getByLabel('Ends at')).toHaveCount(0);
  await expect(page.getByLabel('Visible in the app')).toBeChecked();

  await page.getByRole('button', { name: 'Create promotion' }).click();

  await expect(page).toHaveURL(/\/promotions\/12\/edit$/);
  expect(createdBody).toMatchObject({
    title: '2 Sandwiches Chawarma',
    discountType: 'FIXED_PRICE',
    discountValue: '11.000',
    promoCode: null,
    endAt: null,
    isActive: true,
    restaurantId: 4,
    items: ['2 Sandwichs Chawarma au Poulet Grillé', 'Frites dorées'],
  });
});
