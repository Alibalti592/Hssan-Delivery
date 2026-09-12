import { test, expect } from '@playwright/test';
import { loginAsAdmin, mockStats, courier } from './mockApi';

test('pages through the couriers list with Prev/Next', async ({ page }) => {
  await mockStats(page);

  await page.route('**/api/admin/couriers?**', (route) => {
    const url = new URL(route.request().url());
    const requestedPage = Number(url.searchParams.get('page') ?? '1');

    const body =
      requestedPage === 2
        ? { items: [courier(3, { name: 'Courier Three' })], meta: { page: 2, limit: 2, total: 3, pages: 2 } }
        : {
            items: [
              courier(1, { name: 'Courier One' }),
              courier(2, { name: 'Courier Two' }),
            ],
            meta: { page: 1, limit: 2, total: 3, pages: 2 },
          };

    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) });
  });

  await loginAsAdmin(page);
  await page.goto('/couriers');

  await expect(page.getByText('Courier One')).toBeVisible();
  await expect(page.getByText('Courier Two')).toBeVisible();
  await expect(page.getByText('Page 1 of 2 (3 total)')).toBeVisible();

  const prevButton = page.getByRole('button', { name: '← Prev' });
  await expect(prevButton).toBeDisabled();

  await page.getByRole('button', { name: 'Next →' }).click();

  await expect(page.getByText('Courier Three')).toBeVisible();
  await expect(page.getByText('Courier One')).not.toBeVisible();
  await expect(page.getByText('Page 2 of 2 (3 total)')).toBeVisible();
});
