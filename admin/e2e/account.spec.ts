import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

test('changes the admin password from the sidebar', async ({ page }) => {
  await mockStats(page);
  let sentBody: Record<string, unknown> | undefined;

  await page.route('**/api/auth/change-password', (route) => {
    sentBody = route.request().postDataJSON();
    return route.fulfill({ status: 204 });
  });

  await loginAsAdmin(page);
  await page.getByRole('link', { name: 'Change password' }).click();
  await expect(page).toHaveURL('/account/password');

  await page.getByLabel('Current password').fill('admin1234');
  await page.getByLabel('New password', { exact: true }).fill('a-much-better-one');
  await page.getByLabel('Repeat the new password').fill('a-much-better-one');
  await page.getByRole('button', { name: 'Change password' }).click();

  await expect(page.getByRole('status')).toContainText('Password changed');
  expect(sentBody).toEqual({ currentPassword: 'admin1234', newPassword: 'a-much-better-one' });
});

test('checks the new password before calling the API', async ({ page }) => {
  await mockStats(page);
  let called = false;
  await page.route('**/api/auth/change-password', (route) => {
    called = true;
    return route.fulfill({ status: 204 });
  });

  await loginAsAdmin(page);
  await page.goto('/account/password');

  await page.getByLabel('Current password').fill('admin1234');
  await page.getByLabel('New password', { exact: true }).fill('abcdefgh');
  await page.getByLabel('Repeat the new password').fill('abcdefgX');
  await page.getByRole('button', { name: 'Change password' }).click();

  await expect(page.getByText('The two new passwords do not match.')).toBeVisible();
  expect(called).toBe(false);
});

test('shows the backend error for a wrong current password', async ({ page }) => {
  await mockStats(page);
  await page.route('**/api/auth/change-password', (route) =>
    route.fulfill({
      status: 400,
      contentType: 'application/json',
      body: JSON.stringify({ message: 'Current password is incorrect.' }),
    }),
  );

  await loginAsAdmin(page);
  await page.goto('/account/password');

  await page.getByLabel('Current password').fill('wrong-one');
  await page.getByLabel('New password', { exact: true }).fill('a-much-better-one');
  await page.getByLabel('Repeat the new password').fill('a-much-better-one');
  await page.getByRole('button', { name: 'Change password' }).click();

  await expect(page.getByText('Current password is incorrect.')).toBeVisible();
});
