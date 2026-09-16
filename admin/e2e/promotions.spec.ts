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
        ],
        meta: { page: 1, limit: 20, total: 2, pages: 1 },
      }),
    });
  });

  await loginAsAdmin(page);
  await page.goto('/promotions');

  await expect(page.getByText('Summer Sale')).toBeVisible();
  await expect(page.getByText('15.000%')).toBeVisible();
  await expect(page.getByText('Inactive Promo')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Deactivate' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Activate', exact: true })).toBeVisible();
});

test('deactivating a promotion calls the active endpoint', async ({ page }) => {
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
  await page.getByRole('button', { name: 'Deactivate' }).click();

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
