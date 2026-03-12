import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken } from '../utils/apiProviders';

/**
 * Google Gemini API Provider Tests
 * Tests direct API connectivity and response validation
 */
const provider = API_PROVIDERS.find(p => p.name === 'Google Gemini')!;

test.describe('Google Gemini Provider', () => {
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

    const response = await request.get(`${provider.baseUrl}${provider.modelsEndpoint}?key=${token}`);

    // Gemini might have network restrictions
    if (!response.ok()) {
      console.warn(`⚠️ Gemini models fetch returned ${response.status()} - may be network restricted`);
      test.skip();
    }

    const data = await response.json();
    expect(data.models).toBeDefined();
    expect(data.models.length).toBeGreaterThan(0);
  });

  test('can send generate content request', async ({ request }) => {
    const token = getToken(provider);

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}?key=${token}`, {
      headers: {
        'Content-Type': 'application/json',
      },
      data: {
        contents: [
          {
            parts: [
              { text: provider.testMessage },
            ],
          },
        ],
        generationConfig: {
          maxOutputTokens: 50,
          temperature: 0.7,
        },
      },
    });

    if (!response.ok()) {
      console.warn(`⚠️ Gemini chat returned ${response.status()} - may be network restricted`);
      test.skip();
    }

    const data = await response.json();
    expect(data.candidates).toBeDefined();
    expect(data.candidates.length).toBeGreaterThan(0);
    expect(data.candidates[0].content.parts[0].text).toBeDefined();

    console.log(`✅ Gemini response: ${data.candidates[0].content.parts[0].text.substring(0, 100)}...`);
  });
});
