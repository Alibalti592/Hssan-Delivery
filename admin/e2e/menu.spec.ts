import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

test('builds a menu on the restaurant page: a category inline, then products one after another', async ({ page }) => {
  await mockStats(page);

  const categories: { id: number; name: string; restaurantId: number }[] = [];
  const products: Record<string, unknown>[] = [];

  await page.route('**/api/admin/restaurants/3**', (route) => {
    const url = new URL(route.request().url());
    const method = route.request().method();
    const json = (status: number, body: unknown) =>
      route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

    if (url.pathname === '/api/admin/restaurants/3') {
      return json(200, {
        id: 3,
        name: 'Pizzeria Roma',
        description: null,
        isAvailable: false,
        type: 'RESTAURANT',
        photoUrl: null,
      });
    }
    if (url.pathname === '/api/admin/restaurants/3/categories' && method === 'POST') {
      const category = { id: 7 + categories.length, restaurantId: 3, ...route.request().postDataJSON() };
      categories.push(category);
      return json(201, category);
    }
    if (url.pathname === '/api/admin/restaurants/3/categories') {
      return json(200, categories);
    }
    if (url.pathname === '/api/admin/restaurants/3/products' && method === 'POST') {
      const product = { id: 11 + products.length, photoUrl: null, ...route.request().postDataJSON() };
      products.push(product);
      return json(201, product);
    }
    if (url.pathname === '/api/admin/restaurants/3/products') {
      return json(200, { items: products, meta: { page: 1, limit: 100, total: products.length, pages: 1 } });
    }
    return route.fallback();
  });

  await loginAsAdmin(page);
  await page.goto('/restaurants/3');

  await expect(page.getByText('Start with a category.')).toBeVisible();
  await page.getByLabel('New category').fill('Pizzas');
  await page.keyboard.press('Enter');
  await expect(page.getByRole('heading', { name: /Pizzas/ })).toBeVisible();

  await page.getByRole('button', { name: 'Add the first one' }).click();
  const drawer = page.getByRole('dialog', { name: 'New product' });
  await expect(drawer.getByLabel('Category')).toHaveValue('7');

  await drawer.getByLabel('Name', { exact: true }).fill('Margherita');
  await drawer.getByLabel('Price (DT)').fill('14.500');
  await drawer.getByRole('button', { name: 'Add & add another' }).click();

  // The panel stays open, blank, on the same category.
  await expect(drawer.getByText('“Margherita” added. Add the next one.')).toBeVisible();
  await expect(drawer.getByLabel('Name', { exact: true })).toHaveValue('');
  await expect(drawer.getByLabel('Category')).toHaveValue('7');

  await drawer.getByLabel('Name', { exact: true }).fill('Regina');
  await drawer.getByLabel('Price (DT)').fill('16.000');
  await drawer.getByRole('button', { name: 'Add product' }).click();

  await expect(drawer).toHaveCount(0);
  await expect(page.getByRole('status')).toHaveText('✓ “Regina” added.');
  await expect(page.getByLabel('Margherita available')).toBeChecked();
  await expect(page.getByLabel('Regina available')).toBeChecked();
  expect(products).toMatchObject([
    { name: 'Margherita', price: '14.500', categoryId: 7 },
    { name: 'Regina', price: '16.000', categoryId: 7 },
  ]);
});
