import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken } from '../utils/apiProviders';

/**
 * Cloudflare Workers AI Provider Tests
 * Note: Cloudflare requires ACCOUNT_ID in the URL
 * Format: https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/run/{MODEL}
 */
const provider = API_PROVIDERS.find(p => p.name === 'Cloudflare')!;

test.describe('Cloudflare Provider', () => {
  test.beforeEach(async () => {
    test.skip(!hasValidToken(provider), `Skipping: ${provider.tokenEnvVar} not configured`);
  });

  test('API token is configured', async () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
  });

  test('AI endpoint with account ID', async ({ request }) => {
    const token = getToken(provider)!;

    // Get account ID from env or skip
    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
    if (!accountId) {
      console.warn('⚠️ CLOUDFLARE_ACCOUNT_ID not set, skipping AI test');
      test.skip();
    }

    const model = '@cf/meta/llama-2-7b-chat-int8';
    const response = await request.post(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${model}`,
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        data: {
          messages: [
            { role: 'user', content: provider.testMessage },
          ],
        },
      }
    );

    if (response.status() === 429) {
      console.warn('⚠️ Cloudflare rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.log('Response status:', response.status());
      const errorBody = await response.text();
      console.log('Error:', errorBody.substring(0, 200));
    }

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.success).toBe(true);
    expect(data.result).toBeDefined();

    const content = data.result?.response || '(empty)';
    console.log(`✅ Cloudflare response: ${content.substring(0, 100)}...`);
  });

  test('can list accounts (verify token)', async ({ request }) => {
    const token = getToken(provider)!;

    const response = await request.get('https://api.cloudflare.com/client/v4/accounts', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (response.status() === 403) {
      console.warn('⚠️ Cloudflare token may not have account list permission');
      test.skip();
    }

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.success).toBe(true);
    expect(data.result).toBeDefined();

    if (data.result.length > 0) {
      console.log(`Found ${data.result.length} Cloudflare accounts`);
      console.log(`First account ID: ${data.result[0].id}`);
      console.log('💡 Set CLOUDFLARE_ACCOUNT_ID in .env to test AI inference');
    }
  });
});
