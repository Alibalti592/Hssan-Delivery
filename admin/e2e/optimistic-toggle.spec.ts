import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

const pizza = {
  id: 31,
  name: 'Pizza Reine',
  description: null,
  price: '15.000',
  isAvailable: true,
  photoUrl: null,
  restaurantId: 3,
  categoryId: 1,
  options: [],
  extraGroups: [],
};

/**
 * The dishes of restaurant 3. The server's answer to "mark unavailable" is
 * held until [release] is called, to look at the screen meanwhile.
 */
async function mockMenu(page: import('@playwright/test').Page, answer: 'ok' | 'refuse') {
  let current = { ...pizza };
  let release: () => void = () => {};
  const held = new Promise<void>((resolve) => (release = resolve));
  let calls = 0;

  await mockStats(page);
  await page.route('**/api/admin/restaurants/3', (route) =>
    json(route, { id: 3, name: 'Pizzeria', isAvailable: true, type: 'RESTAURANT', categories: [] }),
  );
  await page.route('**/api/admin/restaurants/3/categories**', (route) =>
    json(route, [{ id: 1, name: 'Pizzas', restaurantId: 3 }]),
  );
  await page.route('**/api/admin/restaurants/3/products**', (route) =>
    json(route, { items: [current], meta: { page: 1, limit: 20, total: 1, pages: 1 } }),
  );
  await page.route('**/api/admin/products/31/availability', async (route) => {
    calls++;
    await held;
    if (answer === 'refuse') return json(route, { message: 'Ce plat ne peut pas être modifié.' }, 400);
    current = { ...current, isAvailable: route.request().postDataJSON().isAvailable };
    return json(route, current);
  });

  return { release: () => release(), calls: () => calls };
}

test('a dish marked unavailable shows it at once, then the server confirms', async ({ page }) => {
  const server = await mockMenu(page, 'ok');
  await loginAsAdmin(page);
  await page.goto('/restaurants/3/products');

  await page.getByRole('button', { name: 'Mark unavailable' }).click();

  // Before the server has answered: already shown, and not clickable again.
  const toggle = page.getByRole('button', { name: 'Mark available' });
  await expect(toggle).toBeVisible();
  await expect(toggle).toBeDisabled();

  server.release();
  await expect(toggle).toBeEnabled();
  await expect(page.getByRole('button', { name: 'Mark available' })).toBeVisible();
  expect(server.calls()).toBe(1);
});

test('a refusal puts the dish back as it was, with the reason', async ({ page }) => {
  const server = await mockMenu(page, 'refuse');
  await loginAsAdmin(page);
  await page.goto('/restaurants/3/products');

  await page.getByRole('button', { name: 'Mark unavailable' }).click();
  await expect(page.getByRole('button', { name: 'Mark available' })).toBeVisible();

  server.release();
  await expect(page.getByRole('button', { name: 'Mark unavailable' })).toBeVisible();
  await expect(page.getByText('Ce plat ne peut pas être modifié.')).toBeVisible();
});
