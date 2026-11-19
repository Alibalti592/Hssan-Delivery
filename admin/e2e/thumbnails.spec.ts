import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({
    status,
    contentType: 'application/json',
    body: JSON.stringify(body),
  });
}

// 1x1 transparent PNG, served for any photo the page asks for.
const PIXEL = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  'base64',
);

function promotion(id: number, photoUrl: string) {
  return {
    id,
    title: `Promo ${id}`,
    description: null,
    photoUrl,
    discountType: 'PERCENTAGE',
    discountValue: '10.000',
    promoCode: null,
    startAt: '2026-01-01T00:00:00+01:00',
    endAt: null,
    isActive: true,
    restaurantId: null,
    restaurantName: null,
    items: [],
    productId: null,
    createdAt: '2026-01-01T00:00:00+01:00',
    updatedAt: '2026-01-01T00:00:00+01:00',
  };
}

test('list photos come as the light copy, lazily, the original when missing', async ({ page }) => {
  const photos: string[] = [];
  await mockStats(page);
  await page.route('**/api/admin/promotions**', (route) =>
    json(route, {
      items: [promotion(1, '/uploads/promotions/has-copy.jpg'), promotion(2, '/uploads/promotions/no-copy.jpg')],
      meta: { page: 1, limit: 20, total: 2, pages: 1 },
    }),
  );
  await page.route('**/uploads/**', (route) => {
    const path = new URL(route.request().url()).pathname;
    photos.push(path);
    // Uploaded before copies existed: only the original is there.
    if (path === '/uploads/promotions/w480/no-copy.webp') return route.fulfill({ status: 404 });
    return route.fulfill({
      status: 200,
      contentType: 'image/png',
      body: PIXEL,
    });
  });

  await loginAsAdmin(page);
  await page.goto('/promotions');

  const images = page.locator('table img');
  await expect(images).toHaveCount(2);
  await expect(images.first()).toHaveAttribute('loading', 'lazy');
  await expect(images.first()).toHaveAttribute('src', /\/uploads\/promotions\/w480\/has-copy\.webp$/);
  await expect(images.nth(1)).toHaveAttribute('src', /\/uploads\/promotions\/no-copy\.jpg$/);

  expect(photos).toContain('/uploads/promotions/w480/has-copy.webp');
  expect(photos).not.toContain('/uploads/promotions/has-copy.jpg');
});
