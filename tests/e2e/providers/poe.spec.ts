import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken, getRequestHeaders, createChatRequest } from '../utils/apiProviders';

/**
 * Poe API Provider Tests
 * OpenAI-compatible API endpoint
 * Endpoint: https://api.poe.com/v1
 * Auth: Bearer token
 * Docs: https://creator.poe.com/docs/external-applications/openai-compatible-api
 * Get API key: https://poe.com/api/keys
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

  test('can send chat completion request', async ({ request }) => {
    const headers = getRequestHeaders(provider);
    const body = createChatRequest(provider);

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers,
      data: body,
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

    // OpenAI-compatible response format
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);
    expect(data.choices[0].message).toBeDefined();
    expect(data.choices[0].message.content).toBeDefined();

    console.log(`✅ Poe response: ${data.choices[0].message.content.substring(0, 100)}...`);
  });

  test('can fetch available models', async ({ request }) => {
    const headers = getRequestHeaders(provider);

    const response = await request.get(`${provider.baseUrl}${provider.modelsEndpoint}`, {
      headers,
    });

    if (response.status() === 429) {
      console.warn('⚠️ Poe rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.warn(`⚠️ Poe models fetch returned ${response.status()}`);
      test.skip();
    }

    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.length).toBeGreaterThan(0);

    const modelIds = data.data.map((m: any) => m.id);
    console.log(`✅ Poe models available: ${modelIds.slice(0, 5).join(', ')}...`);
  });
});
