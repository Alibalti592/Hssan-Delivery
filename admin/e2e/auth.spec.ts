import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockLogin, mockStats } from './mockApi';

test('redirects an unauthenticated visitor to the login page', async ({ page }) => {
  // AuthContext always calls /me on mount now (it can't read the httpOnly
  // auth cookie itself to short-circuit that call) — mock the "no session"
  // response explicitly rather than relying on an unmocked request failing.
  await page.route('**/api/auth/me', (route) => route.fulfill({ status: 401 }));

  await page.goto('/');
  await expect(page).toHaveURL(/\/login$/);
  await expect(page.getByRole('heading', { name: 'Delivery Hassen' })).toBeVisible();
});

test('signs an admin in and lands on the dashboard', async ({ page }) => {
  await mockStats(page);
  await loginAsAdmin(page);

  await expect(page).toHaveURL('/');
  await expect(page.locator('.ttitle')).toHaveText('Dashboard');
});

test('rejects a non-admin account with a friendly message, without navigating', async ({ page }) => {
  await mockLogin(page, ['ROLE_CLIENT']);
  await page.goto('/login');
  await page.getByLabel('Phone').fill('+21622000001');
  await page.getByLabel('Password').fill('secret1234');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByText("This account isn't an administrator account.")).toBeVisible();
  await expect(page).toHaveURL(/\/login$/);
});

test('a 401 on any request mid-session sends the admin back to login', async ({ page }) => {
  // Simulates the auth cookie expiring (or being revoked) after the admin
  // is already signed in and navigating around — not the initial /me check
  // on mount, which AuthContext handles separately. Any other endpoint
  // returning 401 should clear the session and bounce to /login, instead
  // of leaving the authenticated layout up with every request failing.
  await mockStats(page);
  await loginAsAdmin(page);
  await expect(page).toHaveURL('/');

  await page.route('**/api/admin/restaurants**', (route) => route.fulfill({ status: 401 }));

  await page.getByRole('link', { name: 'Restaurants' }).click();

  await expect(page).toHaveURL(/\/login$/);
});

test('an expired session is renewed quietly instead of sending the admin to login', async ({ page }) => {
  await mockLogin(page, ['ROLE_ADMIN']);
  let renewed = false;
  await page.route('**/api/auth/refresh', (route) => {
    renewed = true;
    return route.fulfill({ status: 204 });
  });
  // The first stats call finds the hour-old session expired; after the
  // renewal the same call goes through.
  await page.route('**/api/admin/stats', (route) =>
    renewed
      ? route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ restaurants: 4, deliveryZones: 2, couriers: 3, totalOrders: 99, activeOrders: 1 }),
        })
      : route.fulfill({ status: 401, contentType: 'application/json', body: '{"message":"Expired JWT Token"}' }),
  );

  await page.goto('/login');
  await page.getByLabel('Phone').fill('+21622000000');
  await page.getByLabel('Password').fill('secret1234');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByText('99')).toBeVisible();
  await expect(page).not.toHaveURL(/\/login/);
  expect(renewed).toBe(true);
});
