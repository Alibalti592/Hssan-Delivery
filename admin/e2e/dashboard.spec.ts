import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

test('shows the admin.stats summary counts', async ({ page }) => {
  await mockStats(page, {
    restaurants: 7,
    deliveryZones: 3,
    couriers: 12,
    totalOrders: 256,
    activeOrders: 9,
  });
  await loginAsAdmin(page);

  const stats = page.locator('.stcard');
  await expect(stats).toHaveCount(5);
  await expect(page.getByText('7').first()).toBeVisible();
  await expect(page.getByText('256')).toBeVisible();
  await expect(page.getByText('9')).toBeVisible();
});
