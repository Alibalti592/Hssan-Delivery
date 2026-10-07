import { test, expect, type Route } from '@playwright/test';
import { loginAsAdmin, mockStats } from './mockApi';

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

test('sets a new password for a phone number and offers to send it on WhatsApp', async ({ page }) => {
  await mockStats(page);
  let sent: unknown = null;
  await page.route('**/api/admin/users/password', (route) => {
    sent = route.request().postDataJSON();
    return json(route, { id: 9, name: 'Sami Client', phone: '22000001', role: 'CLIENT' });
  });

  await loginAsAdmin(page);
  await page.getByRole('link', { name: 'Password Reset' }).click();

  await page.getByLabel('Their phone number').fill('22 000 001');
  await page.getByLabel('New password').fill('pain2026x');
  await page.getByRole('button', { name: 'Set new password' }).click();

  await expect(page.getByRole('status')).toContainText('Sami Client');
  await expect(page.getByText('pain2026x')).toBeVisible();
  expect(sent).toEqual({ phone: '22 000 001', password: 'pain2026x' });

  const whatsapp = page.getByRole('link', { name: 'Send on WhatsApp' });
  const href = await whatsapp.getAttribute('href');
  expect(href).toContain('https://wa.me/21622000001?text=');
  expect(decodeURIComponent(href!.split('text=')[1])).toContain(
    'Bonjour Sami Client, votre nouveau mot de passe Delivery Hassen est : pain2026x',
  );
});

test('suggests a readable password and shows when the number is unknown', async ({ page }) => {
  await mockStats(page);
  await page.route('**/api/admin/users/password', (route) =>
    json(route, { message: 'Aucun compte avec ce numéro.' }, 404),
  );

  await loginAsAdmin(page);
  await page.goto('/password-reset');

  const suggested = await page.getByLabel('New password').inputValue();
  expect(suggested).toMatch(/^[a-km-np-z2-9]{8}$/);

  await page.getByLabel('Their phone number').fill('99999999');
  await page.getByRole('button', { name: 'Set new password' }).click();

  await expect(page.getByText('Aucun compte avec ce numéro.')).toBeVisible();
});
