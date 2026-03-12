import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken } from '../utils/apiProviders';

/**
 * XiaoMi MiNo API Provider Tests
 */
const provider = API_PROVIDERS.find(p => p.name === 'XiaoMi MiNo')!;

test.describe('XiaoMi MiNo Provider', () => {
  test.beforeEach(async () => {
    test.skip(!hasValidToken(provider), `Skipping: ${provider.tokenEnvVar} not configured`);
  });

  test('API token is configured', async () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
  });

  test('can fetch available models', async ({ request }) => {
    const token = getToken(provider);

    const response = await request.get(`${provider.baseUrl}${provider.modelsEndpoint}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok()) {
      console.warn(`⚠️ XiaoMi MiNo models fetch returned ${response.status()}`);
      test.skip();
    }

    const data = await response.json();
    expect(data.data || data.models).toBeDefined();
  });

  test('can send chat completion request', async ({ request }) => {
    const token = getToken(provider);

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
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
      console.warn('⚠️ XiaoMi MiNo rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.log('Response status:', response.status());
      const errorBody = await response.text();
      console.log('Error:', errorBody.substring(0, 200));
    }

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);

    console.log(`✅ XiaoMi MiNo response: ${data.choices[0].message.content?.substring(0, 100) || '(empty)'}...`);
  });
});
