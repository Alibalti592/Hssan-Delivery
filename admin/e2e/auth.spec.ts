import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockLogin, mockStats } from './mockApi';

test('redirects an unauthenticated visitor to the login page', async ({ page }) => {
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
