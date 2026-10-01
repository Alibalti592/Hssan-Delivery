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
    },
  };
}

test('orders waiting for a courier are flagged and assigned from the dashboard', async ({ page }) => {
  let queue = [waitingDelivery(7, 12)];
  let assigned: string | null = null;

  await mockStats(page);
  await page.route('**/api/admin/couriers?*', (route) =>
    json(route, {
      items: [courier(3, { name: 'Awa' }), courier(4, { name: 'Off Duty', isActive: false })],
      meta: { page: 1, limit: 100, total: 2, pages: 1 },
    }),
  );
  await page.route('**/api/admin/couriers/locations', (route) =>
    json(route, [
      { courierId: 3, name: 'Awa', status: 'ONLINE', latitude: null, longitude: null, updatedAt: null, currentDeliveryId: null },
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

  const select = page.getByLabel('Courier for delivery 7');
  // Deactivated couriers aren't offered; online ones say so.
  await expect(select.locator('option')).toHaveText(['Choose a courier…', 'Awa (online)']);
  await select.selectOption('3');
  await page.getByRole('button', { name: 'Assign' }).click();

  await expect.poll(() => assigned).not.toBeNull();
  await expect(page.getByText('No order is waiting: every order has a courier.')).toBeVisible();
  await expect(page.locator('.snav-count')).toHaveCount(0);
  await expect(page).toHaveTitle('Hssan Delivery Admin');
});
