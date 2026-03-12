import { defineConfig } from '@playwright/test';
import { config } from 'dotenv';

// Load environment variables from .env file
config();

/**
 * Playwright configuration for API-only E2E testing
 * Tests make direct HTTP requests without needing a browser or web server
 */
export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 1,
  workers: 4,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'playwright-results.json' }],
  ],
  use: {
    trace: 'on-first-retry',
  },

  // Only run provider tests and summary (no UI tests)
  testMatch: ['**/providers/*.spec.ts', '**/summary.spec.ts'],

  // No web server needed for API tests
  // No global setup/teardown needed
});
