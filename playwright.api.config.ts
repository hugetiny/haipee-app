import { defineConfig, devices } from '@playwright/test';
import { config } from 'dotenv';

// Load environment variables from .env file
config();

/**
 * Playwright configuration for API-only E2E testing
 * No web server needed - tests use request fixture directly
 */
export default defineConfig({
  testDir: './tests/e2e/providers',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 1,
  workers: 1,
  reporter: [
    ['line'],
    ['html', { outputFolder: 'playwright-api-report' }],
    ['json', { outputFile: 'playwright-api-results.json' }],
  ],
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'api-tests',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // No web server - tests use request fixture directly
});
