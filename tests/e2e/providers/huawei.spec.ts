import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken } from '../utils/apiProviders';

/**
 * Huawei Cloud API Provider Tests
 */
const provider = API_PROVIDERS.find(p => p.name === 'Huawei')!;

test.describe('Huawei Provider', () => {
  test.beforeEach(async () => {
    test.skip(!hasValidToken(provider), `Skipping: ${provider.tokenEnvVar} not configured`);
  });

  test('API token is configured', async () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
  });

  test('can fetch available models', async ({ request }) => {
    const token = getToken(provider)!;

    const response = await request.get(`${provider.baseUrl}${provider.modelsEndpoint}`, {
      headers: {
        'X-Auth-Token': token,
      },
    });

    if (!response.ok()) {
      console.warn(`⚠️ Huawei models fetch returned ${response.status()}`);
      test.skip();
    }

    const data = await response.json();
    expect(data.data || data.models).toBeDefined();
  });

  test('can send chat completion request', async ({ request }) => {
    const token = getToken(provider)!;

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        'X-Auth-Token': token,
      },
      data: {
        model: provider.testModel,
        messages: [
          { role: 'user', content: provider.testMessage },
        ],
        max_tokens: 50,
      },
    });

    if (response.status() === 429) {
      console.warn('⚠️ Huawei rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.log('Response status:', response.status());
      const errorBody = await response.text();
      console.log('Error:', errorBody.substring(0, 200));
    }

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.choices || data.result).toBeDefined();

    const content = data.choices?.[0]?.message?.content || data.result?.text || '(empty)';
    console.log(`✅ Huawei response: ${content.substring(0, 100)}...`);
  });
});
