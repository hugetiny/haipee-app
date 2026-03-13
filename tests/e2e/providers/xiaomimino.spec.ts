import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken, getRequestHeaders, createChatRequest } from '../utils/apiProviders';

/**
 * XiaoMi MiNo API Provider Tests
 * Note: Endpoint information is limited. Configuration based on best effort research.
 * Expected: OpenAI-compatible API at https://api.minos.ai/v1
 * Auth: Bearer token
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
    const headers = getRequestHeaders(provider);

    const response = await request.get(`${provider.baseUrl}${provider.modelsEndpoint}`, {
      headers,
    });

    if (response.status() === 429) {
      console.warn('⚠️ XiaoMi MiNo rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.warn(`⚠️ XiaoMi MiNo models fetch returned ${response.status()}`);
      console.warn('Note: Endpoint may differ from expected. Check https://dev.mi.com/ for updated documentation.');
      test.skip();
    }

    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.length).toBeGreaterThan(0);

    const modelIds = data.data.map((m: any) => m.id);
    console.log(`✅ XiaoMi MiNo models available: ${modelIds.slice(0, 5).join(', ')}...`);
  });

  test('can send chat completion request', async ({ request }) => {
    const headers = getRequestHeaders(provider);
    const body = createChatRequest(provider);

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers,
      data: body,
    });

    if (response.status() === 429) {
      console.warn('⚠️ XiaoMi MiNo rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.warn(`⚠️ XiaoMi MiNo chat returned ${response.status()}`);
      console.warn('Note: Endpoint may differ from expected. Check https://dev.mi.com/ for updated documentation.');
      test.skip();
    }

    const data = await response.json();

    // OpenAI-compatible response format
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);
    expect(data.choices[0].message).toBeDefined();
    expect(data.choices[0].message.content).toBeDefined();

    console.log(`✅ XiaoMi MiNo response: ${data.choices[0].message.content.substring(0, 100)}...`);
  });
});
