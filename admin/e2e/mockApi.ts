import type { Page, Route } from '@playwright/test';

/**
 * These tests never talk to a real backend. Every scenario registers
 * page.route() handlers for the exact endpoints it needs before
 * navigating, so the suite runs the same with no backend/database
 * present — locally or in CI.
 */

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({
    status,
    contentType: 'application/json',
    body: JSON.stringify(body),
  });
}

export async function mockLogin(page: Page, roles: string[]) {
  await page.route('**/api/auth/login', (route) =>
    json(route, { token: 'fake-jwt-token' }),
  );

  await page.route('**/api/auth/me', (route) =>
    json(route, {
      id: 1,
      name: 'Admin User',
      phone: '+21622000000',
      roles,
      isVerified: true,
    }),
  );
}

export async function loginAsAdmin(page: Page) {
  await mockLogin(page, ['ROLE_ADMIN']);
  await page.goto('/login');
  await page.getByLabel('Phone').fill('+21622000000');
  await page.getByLabel('Password').fill('secret1234');
  await page.getByRole('button', { name: 'Sign in' }).click();
}

export async function mockStats(page: Page, overrides: Record<string, number> = {}) {
  await page.route('**/api/admin/stats', (route) =>
    json(route, {
      restaurants: 3,
      deliveryZones: 2,
      couriers: 5,
      totalOrders: 42,
      activeOrders: 4,
      ...overrides,
    }),
  );
}

export function courier(id: number, overrides: Record<string, unknown> = {}) {
  return {
    id,
    name: `Courier ${id}`,
    phone: `+2162200000${id}`,
    roles: ['ROLE_LIVREUR'],
    verified: true,
    isActive: true,
    createdAt: '2026-01-01T00:00:00+00:00',
    updatedAt: '2026-01-01T00:00:00+00:00',
    ...overrides,
  };
}
