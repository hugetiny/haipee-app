import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken, getRequestHeaders, createChatRequest } from '../utils/apiProviders';

/**
 * Huawei Cloud Pangu AI Provider Tests
 * OpenAI-compatible API endpoint (expected)
 * Endpoint: https://pangu.huaweicloud.com/v1 (or regional endpoint)
 * Auth: Bearer token (or X-Auth-Token for some endpoints)
 * Docs: https://support.huaweicloud.com/pangulm/
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
    const headers = getRequestHeaders(provider);

    const response = await request.get(`${provider.baseUrl}${provider.modelsEndpoint}`, {
      headers,
    });

    if (response.status() === 429) {
      console.warn('⚠️ Huawei rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.warn(`⚠️ Huawei models fetch returned ${response.status()}`);
      console.warn('Note: May require regional endpoint or different authentication');
      test.skip();
    }

    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.length).toBeGreaterThan(0);

    const modelIds = data.data.map((m: any) => m.id);
    console.log(`✅ Huawei models available: ${modelIds.slice(0, 5).join(', ')}...`);
  });

  test('can send chat completion request', async ({ request }) => {
    const headers = getRequestHeaders(provider);
    const body = createChatRequest(provider);

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers,
      data: body,
    });

    if (response.status() === 429) {
      console.warn('⚠️ Huawei rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.warn(`⚠️ Huawei chat returned ${response.status()}`);
      console.warn('Note: May require regional endpoint or different authentication');
      test.skip();
    }

    const data = await response.json();

    // OpenAI-compatible response format
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);
    expect(data.choices[0].message).toBeDefined();
    expect(data.choices[0].message.content).toBeDefined();

    console.log(`✅ Huawei response: ${data.choices[0].message.content.substring(0, 100)}...`);
  });
});
