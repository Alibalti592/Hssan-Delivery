import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

const flash = {
  id: 9,
  title: 'Flash Hour',
  description: null,
  photoUrl: null,
  discountType: 'PERCENTAGE',
  discountValue: '35.000',
  promoCode: 'RB35',
  startAt: '2026-01-01T00:00:00+01:00',
  endAt: null,
  isActive: true,
  restaurantId: null,
  restaurantName: null,
  items: [],
  productId: null,
  createdAt: '2026-01-01T00:00:00+01:00',
  updatedAt: '2026-01-01T00:00:00+01:00',
};

test('sends a Flash notification with the promotion code, after confirming', async ({ page }) => {
  const sent: Record<string, unknown>[] = [];
  await mockStats(page);
  await page.route('**/api/admin/promotions?**', (route) =>
    json(route, { items: [flash], meta: { page: 1, limit: 100, total: 1, pages: 1 } }),
  );
  await page.route('**/api/admin/notifications', (route) => {
    if (route.request().method() === 'POST') {
      const body = route.request().postDataJSON();
      sent.push(body);
      return json(
        route,
        { id: 1, ...body, promotionTitle: 'Flash Hour', recipients: 120, delivered: 118, sentBy: 'Admin', sentAt: '2026-11-18T21:46:00+01:00' },
        201,
      );
    }
    return json(route, { reachableDevices: 120, campaigns: [] });
  });

  await loginAsAdmin(page);
  await page.goto('/notifications');

  await expect(page.getByText('120 customer phones signed in to the app')).toBeVisible();
  await page.getByLabel('Promotion (optional)').selectOption('9');
  await page.getByRole('button', { name: 'Flash' }).click();

  await expect(page.getByLabel(/^Title/)).toHaveValue('⚡ FLASH HOUR : -35% ! 🔥');
  await expect(page.getByLabel(/^Message/)).toHaveValue(/🎟️ Code promo : RB35/);
  // The preview shows it the way the phone will.
  await expect(page.getByLabel('Notification preview')).toContainText('Code promo : RB35');

  page.once('dialog', (dialog) => {
    expect(dialog.message()).toBe('Send this notification to 120 customer phones?');
    dialog.accept();
  });
  await page.getByRole('button', { name: 'Send to 120 phones' }).click();

  await expect(page.getByText('Sent: 118 of 120 phones received it.')).toBeVisible();
  expect(sent).toHaveLength(1);
  expect(sent[0]).toMatchObject({ title: '⚡ FLASH HOUR : -35% ! 🔥', promotionId: 9 });
});
