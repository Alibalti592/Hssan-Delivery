import { defineConfig, devices } from '@playwright/test';

// e2e tests never talk to a real backend — every test mocks `**/api/**`
// with page.route() before navigating, so no backend/database is needed
// to run this suite, in dev or in CI. See e2e/mockApi.ts for the pattern.
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: 'http://127.0.0.1:5173',
    trace: 'retain-on-failure',
    // A pre-installed sandbox Chromium (see CLAUDE-facing tooling docs) can
    // sit under a different revision than what this @playwright/test
    // version would otherwise download — point at it directly when set,
    // rather than fetching a second copy. CI has no such preinstall and
    // instead runs `npx playwright install --with-deps chromium`, so this
    // is unset there and has no effect.
    launchOptions: process.env.PLAYWRIGHT_EXECUTABLE_PATH
      ? { executablePath: process.env.PLAYWRIGHT_EXECUTABLE_PATH }
      : {},
  },
  webServer: {
    command: 'npm run dev -- --port 5173 --strictPort',
    url: 'http://127.0.0.1:5173',
    reuseExistingServer: !process.env.CI,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
