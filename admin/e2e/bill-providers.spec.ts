import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function provider(id: number, overrides: Record<string, unknown> = {}) {
  return {
    id,
    name: `Provider ${id}`,
    kind: 'BILL',
    logoUrl: null,
    isActive: true,
    position: id,
    ...overrides,
  };
}

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

// 1x1 PNG, served as the private bill photo.
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  'base64',
);

test('lists providers with their type, status and logo slot', async ({ page }) => {
  await mockStats(page);
  await page.route('**/api/admin/bill-providers', (route) =>
    json(route, [
      provider(1, { name: 'STEG' }),
      provider(5, { name: 'Wafa Cash', kind: 'TRANSFER', isActive: false }),
    ]),
  );

  await loginAsAdmin(page);
  await page.getByRole('link', { name: 'Bill Providers' }).click();

  await expect(page.getByText('STEG', { exact: true })).toBeVisible();
  await expect(page.getByText('Mandat (money transfer)')).toBeVisible();
  await expect(page.getByText('Hidden', { exact: true })).toBeVisible();
  await expect(page.getByText('1 shown in the app')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Upload logo' })).toHaveCount(2);
  await expect(page.getByRole('button', { name: 'Show in app' })).toBeVisible();
});

test('adds a provider, uploads its logo and hides it', async ({ page }) => {
  await mockStats(page);
  let providers = [provider(1, { name: 'STEG' })];
  let created: unknown;
  let uploadedField: string | null = null;
  let hidden: unknown;

  await page.route('**/api/admin/bill-providers**', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const method = request.method();

    if (method === 'GET') return json(route, providers);

    if (method === 'POST' && url.pathname.endsWith('/bill-providers')) {
      created = request.postDataJSON();
      providers = [...providers, provider(7, { ...(created as object) })];
      return json(route, providers[1], 201);
    }

    if (method === 'POST' && url.pathname.endsWith('/7/logo')) {
      uploadedField = /name="(\w+)"/.exec(request.postData() ?? '')?.[1] ?? null;
      providers = [providers[0], { ...providers[1], logoUrl: '/uploads/bill-providers/ooredoo.png' }];
      return json(route, providers[1]);
    }

    if (method === 'PATCH' && url.pathname.endsWith('/7/active')) {
      hidden = (request.postDataJSON() as { isActive: boolean }).isActive;
      providers = [providers[0], { ...providers[1], isActive: false }];
      return json(route, providers[1]);
    }

    return route.fallback();
  });
  await page.route('**/uploads/bill-providers/ooredoo.png', (route) =>
    route.fulfill({ status: 200, contentType: 'image/png', body: PNG }),
  );

  await loginAsAdmin(page);
  await page.goto('/bill-providers');

  await page.getByRole('button', { name: '+ New provider' }).click();
  await page.getByLabel('Name').fill('Ooredoo');
  await page.getByRole('button', { name: 'Add' }).click();

  await expect.poll(() => created).toEqual({ name: 'Ooredoo', kind: 'BILL', position: 2 });
  await expect(page.getByText('Ooredoo', { exact: true })).toBeVisible();

  await page.getByLabel('Logo for Ooredoo').setInputFiles({
    name: 'ooredoo.png',
    mimeType: 'image/png',
    buffer: PNG,
  });
  await expect.poll(() => uploadedField).toBe('logo');
  await expect(page.getByAltText('Ooredoo logo')).toBeVisible();

  await page.getByRole('row', { name: /Ooredoo/ }).getByRole('button', { name: 'Hide from app' }).click();
  await expect.poll(() => hidden).toBe(false);
});

test('an order shows its bill, amount and the private bill photo', async ({ page }) => {
  await mockStats(page);
  await page.route('**/api/admin/orders/9', (route) =>
    json(route, {
      id: 9,
      userId: 3,
      userName: 'Sami Client',
      userPhone: '22000001',
      restaurantId: null,
      restaurantName: null,
      items: [],
      note: null,
      pickupAddress: 'Rue de Marseille',
      deliveryAddress: 'Rue de Marseille',
      recipientName: null,
      recipientPhone: null,
      deliveryZoneId: 1,
      deliveryZoneName: 'Bizerte centre',
      deliveryFee: '4.000',
      totalAmount: '89.500',
      status: 'PENDING',
      deliveryType: 'BILL',
      deliveryId: 12,
      bill: {
        providerId: 1,
        providerName: 'STEG',
        providerKind: 'BILL',
        providerLogoUrl: null,
        reference: '1234567890',
        amount: '85.500',
        photoUrl: '/api/orders/9/bill-photo',
      },
      createdAt: '2026-09-29T10:00:00+00:00',
      updatedAt: '2026-09-29T10:00:00+00:00',
    }),
  );
  await page.route('**/api/orders/9/bill-photo', (route) =>
    route.fulfill({ status: 200, contentType: 'image/png', body: PNG }),
  );

  await loginAsAdmin(page);
  await page.goto('/orders/9');

  await expect(page.getByText('1234567890')).toBeVisible();
  await expect(page.getByText('Collect cash at')).toBeVisible();
  await expect(page.getByText('Bill amount').first()).toBeVisible();
  await expect(page.getByText('85.500 DT').first()).toBeVisible();
  await expect(page.getByAltText('Photo of the bill')).toBeVisible();
});
