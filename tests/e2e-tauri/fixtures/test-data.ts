// tests/e2e-tauri/fixtures/test-data.ts
import { testEnv, getTestProviderName } from '../setup/test-env';

export interface TestProvider {
  name: string;
  apiKey: string;
  baseUrl: string;
  model?: string;
}

export function createKimiTestProvider(): TestProvider {
  return {
    name: getTestProviderName(),
    apiKey: testEnv.kimiToken,
    baseUrl: testEnv.kimiEndpoint,
    model: 'moonshot-v1-8k',
  };
}

export const testMessages = {
  simple: 'Hello, this is a test message.',
  code: 'Write a simple hello world function in Python.',
  multiTurn: [
    'What is 2 + 2?',
    'Now multiply that by 3.',
    'What is the result?',
  ],
};

export const testTimeouts = {
  short: 10_000,
  medium: 30_000,
  long: 60_000,
  api: 120_000,
};