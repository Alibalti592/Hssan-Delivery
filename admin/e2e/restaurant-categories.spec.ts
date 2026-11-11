import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function category(id: number, overrides: Record<string, unknown> = {}) {
  return {
    id,
    name: `Category ${id}`,
    icon: 'restaurant',
    imageUrl: null,
    position: id,
    restaurantCount: 0,
    ...overrides,
  };
}

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

test('lists the restaurant categories with their icon and how many restaurants have them', async ({ page }) => {
  await mockStats(page);
  // First: its default (no categories) must not win over this test's own.
  await loginAsAdmin(page);
  await page.route('**/api/admin/restaurant-categories', (route) =>
    json(route, [
      category(1, { name: 'Pizza', icon: 'pizza', restaurantCount: 3 }),
      category(2, { name: 'Sucré', icon: 'cake' }),
    ]),
  );

  await page.getByRole('link', { name: 'Categories', exact: true }).click();

  await expect(page).toHaveURL('/restaurant-categories');
  await expect(page.getByText('2 categories to browse restaurants by in the app')).toBeVisible();
  await expect(page.getByText('Pizza', { exact: true })).toBeVisible();
  await expect(page.getByText('Pizza slice')).toBeVisible();
  await expect(page.getByText('Cake', { exact: true })).toBeVisible();
  await expect(page.getByText('None yet', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Upload image' })).toHaveCount(2);
});

test('adds a category, edits it and deletes it', async ({ page }) => {
  await mockStats(page);
  // First: its default (no categories) must not win over this test's own.
  await loginAsAdmin(page);
  let categories = [category(1, { name: 'Pizza', icon: 'pizza', restaurantCount: 2 })];
  let created: unknown;
  let edited: unknown;
  let deleted = false;

  await page.route('**/api/admin/restaurant-categories**', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const method = request.method();

    if (method === 'GET') return json(route, categories);

    if (method === 'POST' && url.pathname.endsWith('/restaurant-categories')) {
      created = request.postDataJSON();
      categories = [...categories, category(7, { ...(created as object) })];
      return json(route, categories[1], 201);
    }

    if (method === 'PUT' && url.pathname.endsWith('/7')) {
      edited = request.postDataJSON();
      categories = [categories[0], { ...categories[1], ...(edited as object) }];
      return json(route, categories[1]);
    }

    if (method === 'DELETE' && url.pathname.endsWith('/1')) {
      deleted = true;
      categories = [categories[1]];
      return route.fulfill({ status: 204 });
    }

    return route.fallback();
  });

  await page.goto('/restaurant-categories');

  await page.getByRole('button', { name: '+ New category' }).click();
  await page.getByLabel('Name').fill('  Boissons ');
  await page.getByLabel('Icon').selectOption('drink');
  await page.getByRole('button', { name: 'Add', exact: true }).click();

  await expect(page.getByText('Boissons', { exact: true })).toBeVisible();
  // After the last one, and trimmed.
  expect(created).toEqual({ name: 'Boissons', icon: 'drink', position: 2 });

  await page.getByRole('row', { name: /Boissons/ }).getByRole('button', { name: 'Edit' }).click();
  await page.getByLabel('Name').fill('Jus & Boissons');
  await page.getByLabel('Icon').selectOption('coffee');
  await page.getByRole('button', { name: 'Save' }).click();

  await expect(page.getByText('Jus & Boissons', { exact: true })).toBeVisible();
  await expect(page.getByText('Coffee cup')).toBeVisible();
  expect(edited).toEqual({ name: 'Jus & Boissons', icon: 'coffee', position: 2 });

  // Deleting says what happens to the restaurants that have it.
  let confirmMessage = '';
  page.once('dialog', (dialog) => {
    confirmMessage = dialog.message();
    return dialog.accept();
  });
  await page.getByRole('row', { name: /Pizza/ }).getByRole('button', { name: 'Delete' }).click();

  await expect(page.getByText('Pizza', { exact: true })).toHaveCount(0);
  expect(deleted).toBe(true);
  expect(confirmMessage).toContain('2 restaurants have it');
});

test("ticks a restaurant's categories on its page", async ({ page }) => {
  await mockStats(page);
  // First: its default (no categories) must not win over this test's own.
  await loginAsAdmin(page);
  await page.route('**/api/admin/restaurant-categories', (route) =>
    json(route, [
      category(1, { name: 'Pizza', icon: 'pizza' }),
      category(2, { name: 'Sucré', icon: 'cake' }),
      category(3, { name: 'Boissons', icon: 'drink' }),
    ]),
  );

  let restaurant = {
    id: 3,
    name: 'Pizzeria Roma',
    description: null,
    isAvailable: true,
    type: 'RESTAURANT',
    photoUrl: null,
    categories: [category(1, { name: 'Pizza', icon: 'pizza' })],
  };
  let saved: { categoryIds?: number[] } | undefined;

  await page.route('**/api/admin/restaurants/3**', (route) => {
    const url = new URL(route.request().url());
    const method = route.request().method();

    if (url.pathname === '/api/admin/restaurants/3' && method === 'PUT') {
      saved = route.request().postDataJSON();
      restaurant = {
        ...restaurant,
        categories: (saved?.categoryIds ?? []).map((id) => category(id)),
      };
      return json(route, restaurant);
    }
    if (url.pathname === '/api/admin/restaurants/3') return json(route, restaurant);
    if (url.pathname === '/api/admin/restaurants/3/categories') return json(route, []);
    if (url.pathname === '/api/admin/restaurants/3/products') {
      return json(route, { items: [], meta: { page: 1, limit: 100, total: 0, pages: 1 } });
    }
    return route.fallback();
  });

  await page.goto('/restaurants/3');

  const pizza = page.getByRole('button', { name: 'Pizza', exact: true });
  const sweet = page.getByRole('button', { name: 'Sucré', exact: true });
  const save = page.getByRole('button', { name: 'Save changes' });

  // What it already has is on; nothing to save yet.
  await expect(pizza).toHaveAttribute('aria-pressed', 'true');
  await expect(sweet).toHaveAttribute('aria-pressed', 'false');
  await expect(save).toBeDisabled();

  await sweet.click();
  await pizza.click();
  await page.getByRole('button', { name: 'Boissons', exact: true }).click();
  await save.click();

  await expect(page.getByRole('button', { name: '✓ Saved' })).toBeVisible();
  expect(saved?.categoryIds).toEqual([2, 3]);
});

test('a new restaurant is created with the categories ticked', async ({ page }) => {
  await mockStats(page);
  // First: its default (no categories) must not win over this test's own.
  await loginAsAdmin(page);
  await page.route('**/api/admin/restaurant-categories', (route) =>
    json(route, [category(1, { name: 'Pizza' }), category(2, { name: 'Fast Food' })]),
  );

  let created: { categoryIds?: number[] } | undefined;
  await page.route('**/api/admin/restaurants', (route) => {
    if (route.request().method() !== 'POST') return route.fallback();
    created = route.request().postDataJSON();
    return json(
      route,
      { id: 9, description: null, photoUrl: null, categories: [], ...(created as object) },
      201,
    );
  });
  await page.route('**/api/admin/restaurants/9**', (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === '/api/admin/restaurants/9') {
      return json(route, {
        id: 9,
        name: 'Burger Corner',
        description: null,
        isAvailable: false,
        type: 'RESTAURANT',
        photoUrl: null,
        categories: [category(2, { name: 'Fast Food' })],
      });
    }
    if (url.pathname.endsWith('/categories')) return json(route, []);
    return json(route, { items: [], meta: { page: 1, limit: 100, total: 0, pages: 1 } });
  });

  await page.goto('/restaurants/new');

  await page.getByLabel('Name').fill('Burger Corner');
  await page.getByRole('button', { name: 'Fast Food', exact: true }).click();
  await page.getByRole('button', { name: /Create and add the menu/ }).click();

  await expect(page).toHaveURL('/restaurants/9');
  expect(created?.categoryIds).toEqual([2]);
});
