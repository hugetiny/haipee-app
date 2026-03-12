import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken } from '../utils/apiProviders';

/**
 * OpenAI API Provider Tests
 * Tests direct API connectivity and response validation
 */
const provider = API_PROVIDERS.find(p => p.name === 'OpenAI')!;

test.describe('OpenAI Provider', () => {
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

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.length).toBeGreaterThan(0);

    // Check for expected models
    const modelIds = data.data.map((m: any) => m.id);
    expect(modelIds.some((id: string) => id.includes('gpt'))).toBeTruthy();
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
        temperature: 0.7,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);
    expect(data.choices[0].message.content).toBeDefined();

    console.log(`✅ OpenAI response: ${data.choices[0].message.content.substring(0, 100)}...`);
  });

  test('handles authentication errors', async ({ request }) => {
    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer invalid-token',
      },
      data: {
        model: provider.testModel,
        messages: [{ role: 'user', content: 'test' }],
      },
    });

    expect(response.status()).toBe(401);
  });
});
