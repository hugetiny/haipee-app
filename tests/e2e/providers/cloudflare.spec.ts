import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken, createChatRequest } from '../utils/apiProviders';

/**
 * Cloudflare Workers AI Provider Tests
 * Uses OpenAI-compatible endpoint: https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/
 * Endpoint: https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/v1
 * Auth: Bearer token in Authorization header
 * Requires: CLOUDFLARE_ACCOUNT_ID environment variable
 */
const provider = API_PROVIDERS.find(p => p.name === 'Cloudflare')!;

// Helper to build Cloudflare URL with account ID
function getCloudflareBaseUrl(): string | null {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  if (!accountId) return null;
  return `${provider.baseUrl}/${accountId}`;
}

test.describe('Cloudflare Provider', () => {
  test.beforeEach(async () => {
    test.skip(!hasValidToken(provider), `Skipping: ${provider.tokenEnvVar} not configured`);
  });

  test('API token is configured', async () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
  });

  test('CLOUDFLARE_ACCOUNT_ID is configured', async () => {
    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
    if (!accountId) {
      console.warn('⚠️ CLOUDFLARE_ACCOUNT_ID not set');
      console.warn('💡 Get your Account ID from: https://dash.cloudflare.com/');
      test.skip();
    }
    expect(accountId).toBeDefined();
    expect(accountId!.length).toBeGreaterThan(10);
  });

  test('can send chat completion request (OpenAI-compatible)', async ({ request }) => {
    const token = getToken(provider)!;
    const baseUrl = getCloudflareBaseUrl();

    if (!baseUrl) {
      console.warn('⚠️ CLOUDFLARE_ACCOUNT_ID not set, skipping AI test');
      test.skip();
    }

    const body = createChatRequest(provider);

    const response = await request.post(`${baseUrl}${provider.chatEndpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      data: body,
    });

    if (response.status() === 429) {
      console.warn('⚠️ Cloudflare rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.log('Response status:', response.status());
      const errorBody = await response.text();
      console.log('Error:', errorBody.substring(0, 500));
    }

    expect(response.ok()).toBeTruthy();
    const data = await response.json();

    // OpenAI-compatible response format
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);
    expect(data.choices[0].message).toBeDefined();
    expect(data.choices[0].message.content).toBeDefined();

    const content = data.choices[0].message.content;
    console.log(`✅ Cloudflare response: ${content.substring(0, 100)}...`);
  });

  test('can verify token by listing accounts', async ({ request }) => {
    const token = getToken(provider)!;

    const response = await request.get(`${provider.baseUrl}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    // This will likely 404 since we need the full path
    // But it helps verify the token format
    console.log(`Token verification status: ${response.status()}`);

    // Try listing accounts endpoint
    const accountsResponse = await request.get('https://api.cloudflare.com/client/v4/accounts', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (accountsResponse.status() === 403) {
      console.warn('⚠️ Cloudflare token may not have account list permission');
      console.warn('This is OK if token has AI-specific permissions');
      test.skip();
    }

    if (!accountsResponse.ok()) {
      console.warn(`⚠️ Account list returned ${accountsResponse.status()}`);
      test.skip();
    }

    const data = await accountsResponse.json();
    expect(data.success).toBe(true);
    expect(data.result).toBeDefined();

    if (data.result.length > 0) {
      console.log(`✅ Found ${data.result.length} Cloudflare accounts`);
      console.log(`   Account IDs: ${data.result.map((a: any) => a.id).join(', ')}`);
      console.log('💡 Set CLOUDFLARE_ACCOUNT_ID in .env to test AI inference');
    }
  });
});
