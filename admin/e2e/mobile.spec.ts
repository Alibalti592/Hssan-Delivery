import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

test.use({ viewport: { width: 390, height: 844 } });

test('on a phone the menu opens from the top bar and closes after picking a page', async ({ page }) => {
  await mockStats(page);
  await page.route('**/api/admin/couriers/locations', (route) =>
    route.fulfill({ status: 200, contentType: 'application/json', body: '[]' }),
  );
  await loginAsAdmin(page);

  const menu = page.getByRole('button', { name: 'Open menu' });
  await expect(menu).toBeVisible();
  // The sidebar is off screen until the menu is opened.
  await expect(page.getByRole('link', { name: 'Courier Map', exact: true })).not.toBeInViewport();

  await menu.click();
  await expect(page.getByRole('link', { name: 'Courier Map', exact: true })).toBeInViewport();

  await page.getByRole('link', { name: 'Courier Map', exact: true }).click();
  await expect(page).toHaveURL(/\/courier-map$/);
  await expect(page.getByRole('link', { name: 'Courier Map', exact: true })).not.toBeInViewport();

  // Nothing is wider than the screen.
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
