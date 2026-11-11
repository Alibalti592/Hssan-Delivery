import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

const sauces = {
  name: 'Sauces',
  required: false,
  multiple: true,
  choices: [
    { name: 'Harissa', price: '0.000' },
    { name: 'Mayonnaise', price: '0.000' },
  ],
};

function product(id: number, name: string, extraGroups: unknown[] = []) {
  return {
    id,
    name,
    description: null,
    price: '8.000',
    options: [],
    extraGroups,
    isAvailable: true,
    photoUrl: null,
    restaurantId: 3,
    categoryId: 7,
  };
}

/** A snack whose menu has a Chapati (with sauces) and a Baguette (none). */
async function mockSnack(page: import('@playwright/test').Page, onSave: (body: Record<string, unknown>) => void) {
  await page.route('**/api/admin/restaurants/3**', (route) => {
    const url = new URL(route.request().url());
    const method = route.request().method();

    if (url.pathname === '/api/admin/restaurants/3') {
      return json(route, { id: 3, name: 'Snack Salem', description: null, isAvailable: true, type: 'RESTAURANT', photoUrl: null, categories: [] });
    }
    if (url.pathname === '/api/admin/restaurants/3/categories') {
      return json(route, [{ id: 7, name: 'Sandwichs', restaurantId: 3 }]);
    }
    if (url.pathname === '/api/admin/restaurants/3/products' && method === 'POST') {
      const body = route.request().postDataJSON();
      onSave(body);
      return json(route, { ...product(20, body.name), ...body }, 201);
    }
    if (url.pathname === '/api/admin/restaurants/3/products') {
      return json(route, {
        items: [product(11, 'Chapati', [sauces]), product(12, 'Baguette')],
        meta: { page: 1, limit: 100, total: 2, pages: 1 },
      });
    }
    return route.fallback();
  });
  await page.route('**/api/admin/products/12', (route) => {
    if (route.request().method() !== 'PUT') return route.fallback();
    const body = route.request().postDataJSON();
    onSave(body);
    return json(route, { ...product(12, 'Baguette'), ...body });
  });
}

test('adds sauces, extras and a required drink to a new product', async ({ page }) => {
  await mockStats(page);
  await loginAsAdmin(page);
  let saved: Record<string, unknown> | undefined;
  await mockSnack(page, (body) => (saved = body));

  await page.goto('/restaurants/3');
  await page.getByRole('button', { name: '+ Add product' }).first().click();
  const drawer = page.getByRole('dialog', { name: 'New product' });

  await drawer.getByLabel('Name', { exact: true }).fill('Makloub');
  await drawer.getByLabel('Price (DT)').fill('9.500');

  await drawer.getByRole('button', { name: '+ Sauces' }).click();
  await drawer.getByLabel('Sauces choice 1 name').fill('Harissa');
  await drawer.getByRole('button', { name: '+ Add a choice' }).click();
  await drawer.getByLabel('Sauces choice 2 name').fill('Algérienne');

  await drawer.getByRole('button', { name: '+ Extras' }).click();
  await drawer.getByLabel('Suppléments choice 1 name').fill('Fromage');
  await drawer.getByLabel('Suppléments choice 1 price').fill('1.500');

  await drawer.getByRole('button', { name: '+ Drink' }).click();
  await expect(drawer.getByLabel('Group 3 picks')).toHaveValue('one');
  await drawer.getByLabel('Boisson choice 1 name').fill('Coca-Cola');
  await drawer.getByLabel('Boisson choice 1 price').fill('2.000');
  await drawer.getByText('Required: the client must pick one').click();

  // Each preset is offered once.
  await expect(drawer.getByRole('button', { name: '+ Sauces' })).toHaveCount(0);

  await drawer.getByRole('button', { name: 'Add product', exact: true }).click();
  await expect(drawer).toHaveCount(0);

  expect(saved?.extraGroups).toEqual([
    {
      name: 'Sauces',
      required: false,
      multiple: true,
      choices: [
        { name: 'Harissa', price: '0' },
        { name: 'Algérienne', price: '0' },
      ],
    },
    { name: 'Suppléments', required: false, multiple: true, choices: [{ name: 'Fromage', price: '1.500' }] },
    { name: 'Boisson', required: true, multiple: false, choices: [{ name: 'Coca-Cola', price: '2.000' }] },
  ]);
});

test("copies another product's choices", async ({ page }) => {
  await mockStats(page);
  await loginAsAdmin(page);
  let saved: Record<string, unknown> | undefined;
  await mockSnack(page, (body) => (saved = body));

  await page.goto('/restaurants/3');
  await page.getByRole('button', { name: /Baguette/ }).click();
  const drawer = page.getByRole('dialog', { name: 'Edit product' });

  await drawer.getByLabel('Copy the choices of another product').selectOption({ label: 'Chapati' });
  await expect(drawer.getByLabel('Sauces choice 2 name')).toHaveValue('Mayonnaise');

  await drawer.getByRole('button', { name: 'Save changes' }).click();
  await expect(drawer).toHaveCount(0);
  expect(saved?.extraGroups).toEqual([sauces]);
});
