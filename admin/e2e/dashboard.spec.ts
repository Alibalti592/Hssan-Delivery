import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

test("shows today's live figures and the overall counts", async ({ page }) => {
  await mockStats(page, {
    restaurants: 7,
    deliveryZones: 3,
    couriers: 12,
    totalOrders: 256,
    activeOrders: 9,
    todayOrders: 31,
    todayCompleted: 24,
  });
  await loginAsAdmin(page);

  await expect(page.locator('.kpi')).toHaveCount(5);
  await expect(page.locator('.kpi', { hasText: 'Orders today' })).toContainText('31');
  await expect(page.locator('.kpi', { hasText: 'Orders today' })).toContainText('24 delivered');
  await expect(page.locator('.kpi', { hasText: 'Waiting for a courier' })).toContainText('All assigned');
  await expect(page.locator('.dash-footer')).toHaveText(
    '7 restaurants · 3 delivery zones · 12 couriers · 256 orders in all · 9 in progress',
  );
});
