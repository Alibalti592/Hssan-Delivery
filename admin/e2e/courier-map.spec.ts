import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

// A tiny transparent PNG — stands in for OpenStreetMap tiles so the map
// renders without this test depending on real internet access.
const TILE_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  'base64',
);

test('shows courier counts derived from last known locations', async ({ page }) => {
  await mockStats(page);

  await page.route('https://*.tile.openstreetmap.org/**', (route) =>
    route.fulfill({ status: 200, contentType: 'image/png', body: TILE_PNG }),
  );

  await page.route('**/api/admin/couriers/locations', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([
        {
          courierId: 1,
          name: 'Courier Online',
          status: 'ONLINE',
          latitude: 36.8,
          longitude: 10.18,
          updatedAt: new Date().toISOString(),
          currentDeliveryId: null,
        },
        {
          courierId: 2,
          name: 'Courier Busy',
          status: 'ON_DELIVERY',
          latitude: 36.81,
          longitude: 10.19,
          updatedAt: new Date().toISOString(),
          currentDeliveryId: 42,
        },
        {
          courierId: 3,
          name: 'Courier Offline',
          status: 'OFFLINE',
          latitude: null,
          longitude: null,
          updatedAt: null,
          currentDeliveryId: null,
        },
      ]),
    }),
  );

  await loginAsAdmin(page);
  await page.goto('/courier-map');

  await expect(page.locator('.stcard')).toHaveCount(4);

  const values = await page.locator('.stval').allTextContents();
  expect(values).toEqual(['3', '1', '1', '1']);

  await expect(
    page.getByText(
      "This shows each courier's last reported position, not live continuous tracking.",
      { exact: false },
    ),
  ).toBeVisible();
});

test('shows an empty map with zero counts when no courier has ever reported', async ({ page }) => {
  await mockStats(page);

  await page.route('https://*.tile.openstreetmap.org/**', (route) =>
    route.fulfill({ status: 200, contentType: 'image/png', body: TILE_PNG }),
  );

  await page.route('**/api/admin/couriers/locations', (route) =>
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([]) }),
  );

  await loginAsAdmin(page);
  await page.goto('/courier-map');

  await expect(page.locator('.stcard')).toHaveCount(4);

  const values = await page.locator('.stval').allTextContents();
  expect(values).toEqual(['0', '0', '0', '0']);
});
