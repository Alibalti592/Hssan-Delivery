import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

test('an order shows the promotion that was taken off', async ({ page }) => {
  await mockStats(page);
  await page.route('**/api/admin/orders/7', (route) =>
    json(route, {
      id: 7,
      userId: 3,
      userName: 'Sami Client',
      userPhone: '22000001',
      restaurantId: 1,
      restaurantName: 'Le Bon Burger',
      items: [{ id: 1, productId: 3, productName: 'Classic Smash', option: null, quantity: 2, unitPrice: '12.000' }],
      note: null,
      pickupAddress: null,
      deliveryAddress: 'Rue de Marseille',
      recipientName: null,
      recipientPhone: null,
      deliveryZoneId: 1,
      deliveryZoneName: 'Bizerte centre',
      deliveryFee: '4.000',
      totalAmount: '23.000',
      discountAmount: '5.000',
      promotionTitle: 'Bienvenue',
      promoCode: 'BIENVENUE',
      status: 'PENDING',
      deliveryType: 'RESTAURANT',
      deliveryId: 12,
      bill: null,
      createdAt: '2026-10-01T10:00:00+00:00',
      updatedAt: '2026-10-01T10:00:00+00:00',
    }),
  );

  await loginAsAdmin(page);
  await page.goto('/orders/7');

  await expect(page.getByText('Discount · Bienvenue (code BIENVENUE)')).toBeVisible();
  await expect(page.getByText('−5.000 DT')).toBeVisible();
  await expect(page.getByText('23.000 DT')).toBeVisible();
});
