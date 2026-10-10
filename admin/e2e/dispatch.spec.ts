import { test, expect, type Route } from '@playwright/test';
import { courier, mockLogin, mockStats } from './mockApi';

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

function waitingDelivery(id: number, minutesAgo: number) {
  return {
    id,
    orderId: 100 + id,
    status: 'PENDING',
    courierId: null,
    assignedAt: null,
    acceptedAt: null,
    pickedUpAt: null,
    deliveredAt: null,
    createdAt: new Date(Date.now() - minutesAgo * 60_000).toISOString(),
    order: {
      id: 100 + id,
      status: 'PENDING',
      deliveryType: 'RESTAURANT',
      restaurantName: 'Le Bon Burger',
      customerName: 'Sami',
      customerPhone: '22000001',
      pickupAddress: null,
      deliveryAddress: '12 Rue de Marseille, Bizerte',
      totalAmount: '20.000',
      bill: null,
      pickupLatitude: null,
      pickupLongitude: null,
      deliveryLatitude: 37.2744,
      deliveryLongitude: 9.8739,
    },
  };
}

test('orders waiting for a courier are assigned to the nearest one in one click', async ({ page }) => {
  let queue = [waitingDelivery(7, 12)];
  let assigned: string | null = null;

  await mockStats(page);
  await page.route('**/api/admin/couriers?*', (route) =>
    json(route, {
      items: [
        courier(3, { name: 'Awa' }),
        courier(5, { name: 'Nour' }),
        courier(4, { name: 'Off Duty', isActive: false }),
      ],
      meta: { page: 1, limit: 100, total: 3, pages: 1 },
    }),
  );
  await page.route('**/api/admin/couriers/locations', (route) =>
    json(route, [
      // Nour is 3 km away, Awa 300 m: Awa is the one to send.
      { courierId: 5, name: 'Nour', status: 'ONLINE', latitude: 37.3014, longitude: 9.8739, updatedAt: new Date().toISOString(), currentDeliveryId: null },
      { courierId: 3, name: 'Awa', status: 'ONLINE', latitude: 37.2771, longitude: 9.8739, updatedAt: new Date().toISOString(), currentDeliveryId: null },
    ]),
  );
  await page.route('**/api/deliveries/7/assign/3', (route) => {
    assigned = route.request().url();
    queue = [];
    return json(route, { ...waitingDelivery(7, 12), status: 'ASSIGNED', courierId: 3 });
  });
  await mockLogin(page, ['ROLE_ADMIN']);
  // Registered after mockLogin so it wins over its empty queue.
  await page.route('**/api/admin/deliveries/waiting', (route) => json(route, queue));
  await page.goto('/login');
  await page.getByLabel('Phone').fill('+21622000000');
  await page.getByLabel('Password').fill('secret1234');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('heading', { name: /Waiting for a courier/ })).toBeVisible();
  await expect(page.getByText('Le Bon Burger')).toBeVisible();
  await expect(page.getByText('12 min')).toBeVisible();
  await expect(page.locator('.snav-count')).toHaveText('1');
  await expect(page).toHaveTitle('(1) Hssan Delivery Admin');

  await expect(page.getByText('2 couriers online')).toBeVisible();
  const select = page.getByLabel('Courier for delivery 7');
  // Deactivated couriers aren't offered; the nearest online one comes first
  // and is already chosen.
  await expect(select.locator('option')).toHaveText([
    'Choose a courier…',
    'Awa · online · 300 m away (nearest)',
    'Nour · online · 3.0 km away',
  ]);
  await expect(select).toHaveValue('3');
  await page.getByRole('button', { name: 'Assign Awa' }).click();

  await expect.poll(() => assigned).not.toBeNull();
  await expect(page.getByText('No order is waiting: every order has a courier.')).toBeVisible();
  await expect(page.locator('.snav-count')).toHaveCount(0);
  await expect(page).toHaveTitle('Hssan Delivery Admin');
});
