// tests/e2e-tauri/setup/test-env.ts
import { config } from 'dotenv';
import { resolve } from 'path';

// Load .env.test
config({ path: resolve(process.cwd(), '.env.test') });

export const testEnv = {
  kimiEndpoint: process.env.TEST_KIMI_ENDPOINT || '',
  kimiToken: process.env.TEST_KIMI_TOKEN || '',
  providerPrefix: process.env.TEST_PROVIDER_PREFIX || 'test-',
  sessionPrefix: process.env.TEST_SESSION_PREFIX || 'test-session-',
};

export function getTestProviderName(): string {
  return `${testEnv.providerPrefix}${Date.now()}`;
}