import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken } from '../utils/apiProviders';

/**
 * OpenCode Zen API Provider Tests
 * Zen uses OpenAI-compatible format with model-specific endpoints
 * Free model: minimax-m2.5-free @ https://opencode.ai/zen/v1/chat/completions
 */
const provider = API_PROVIDERS.find(p => p.name === 'OpenCode Zen')!;

test.describe('OpenCode Zen Provider', () => {
  test.beforeEach(async () => {
    test.skip(!hasValidToken(provider), `Skipping: ${provider.tokenEnvVar} not configured`);
  });

  test('API token is configured', async () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
  });

  test('Zen endpoint is reachable', async ({ request }) => {
    const token = getToken(provider);

    // Quick check - Zen doesn't have a models endpoint
    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      data: {
        model: provider.testModel,
        messages: [{ role: 'user', content: 'Hi' }],
        max_tokens: 5,
      },
    });

    // Accept 200 (success) or 429 (rate limit) - both mean endpoint exists
    expect([200, 201, 429].includes(response.status())).toBeTruthy();
  });

  test('can send chat completion request', async ({ request }) => {
    const token = getToken(provider);

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      data: {
        model: provider.testModel,
        messages: [
          { role: 'user', content: provider.testMessage },
        ],
        max_tokens: 50,
        temperature: 0.7,
      },
    });

    if (response.status() === 429) {
      console.warn('⚠️ OpenCode Zen rate limited - this is normal for free tier');
      test.skip();
    }

    if (!response.ok()) {
      const errorText = await response.text();
      console.log('Error response:', errorText.substring(0, 200));
    }

    expect(response.ok()).toBeTruthy();
    const data = await response.json();

    // Verify OpenAI-compatible response structure
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);

    // Content may be null in some edge cases, check message exists
    expect(data.choices[0].message).toBeDefined();

    const content = data.choices[0].message.content;
    if (content) {
      console.log(`✅ OpenCode Zen response: ${content.substring(0, 100)}...`);
    } else {
      console.log('⚠️ Response received but content is empty');
    }
  });
});
