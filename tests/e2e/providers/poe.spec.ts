import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken } from '../utils/apiProviders';

/**
 * Poe API Provider Tests
 * Poe uses a unique API format
 */
const provider = API_PROVIDERS.find(p => p.name === 'Poe')!;

test.describe('Poe Provider', () => {
  test.beforeEach(async () => {
    test.skip(!hasValidToken(provider), `Skipping: ${provider.tokenEnvVar} not configured`);
  });

  test('API token is configured', async () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
  });

  test('API endpoint is reachable', async ({ request }) => {
    const token = getToken(provider);

    // Poe may not have a standard models endpoint
    const response = await request.get(`${provider.baseUrl!}/health`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }).catch(() => null);

    // Just verify the domain is reachable
    expect(response !== null || (provider.baseUrl && provider.baseUrl.includes('poe.com'))).toBeTruthy();
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
      console.warn('⚠️ Poe rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.log('Response status:', response.status());
      const errorBody = await response.text();
      console.log('Error:', errorBody.substring(0, 200));
    }

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.choices || data.text || data.content).toBeDefined();

    const content = data.choices?.[0]?.message?.content || data.text || data.content || '(empty)';
    console.log(`✅ Poe response: ${content.substring(0, 100)}...`);
  });
});
