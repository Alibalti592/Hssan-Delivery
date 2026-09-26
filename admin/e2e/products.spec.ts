import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

test('creates a pizza with sizes instead of a single price', async ({ page }) => {
  await mockStats(page);

  let createdBody: Record<string, unknown> | undefined;

  await page.route('**/api/admin/restaurants/3**', (route) => {
    const url = new URL(route.request().url());
    const method = route.request().method();

    if (url.pathname === '/api/admin/restaurants/3') {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ id: 3, name: 'Pizzeria Roma' }),
      });
    }

    if (url.pathname === '/api/admin/restaurants/3/categories') {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([{ id: 7, name: 'Pizzas', restaurantId: 3 }]),
      });
    }

    if (url.pathname === '/api/admin/restaurants/3/products' && method === 'POST') {
      createdBody = route.request().postDataJSON();
      return route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify({ id: 11, ...createdBody }),
      });
    }

    if (url.pathname === '/api/admin/restaurants/3/products') {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ items: [], meta: { page: 1, limit: 20, total: 0, pages: 1 } }),
      });
    }

    return route.fallback();
  });

  await loginAsAdmin(page);
  await page.goto('/restaurants/3/products/new');

  await page.getByLabel('Name', { exact: true }).fill('Pizza Margherita');
  await expect(page.getByLabel('Price (DT)')).toBeVisible();

  await page.getByRole('button', { name: '+ Add size / option' }).click();
  await page.getByLabel('Option 1 name').fill('M');
  await page.getByLabel('Option 1 price').fill('12.000');
  await page.getByRole('button', { name: '+ Add size / option' }).click();
  await page.getByLabel('Option 2 name').fill('Familiale');
  await page.getByLabel('Option 2 price').fill('22.000');

  // With sizes, each size carries the price, so the single price goes away.
  await expect(page.getByLabel('Price (DT)')).toHaveCount(0);

  await page.getByRole('button', { name: 'Create product' }).click();

  await expect(page).toHaveURL('/restaurants/3/products');
  expect(createdBody).toMatchObject({
    name: 'Pizza Margherita',
    price: null,
    categoryId: 7,
    options: [
      { name: 'M', price: '12.000' },
      { name: 'Familiale', price: '22.000' },
    ],
  });
});
