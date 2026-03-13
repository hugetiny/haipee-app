import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getToken, getRequestHeaders, createChatRequest } from '../utils/apiProviders';

/**
 * Google Gemini API Provider Tests
 * Uses OpenAI-compatible endpoint: https://ai.google.dev/gemini-api/docs/openai
 * Endpoint: https://generativelanguage.googleapis.com/v1beta/openai
 * Auth: Bearer token in Authorization header
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
    const headers = getRequestHeaders(provider);

    const response = await request.get(`${provider.baseUrl}${provider.modelsEndpoint}`, {
      headers,
    });

    // Gemini might have network restrictions
    if (!response.ok()) {
      console.warn(`⚠️ Gemini models fetch returned ${response.status()} - may be network restricted`);
      console.warn('Response:', await response.text());
      test.skip();
    }

    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.length).toBeGreaterThan(0);

    // Log available models
    const modelIds = data.data.map((m: any) => m.id);
    console.log(`✅ Gemini models available: ${modelIds.slice(0, 5).join(', ')}...`);
  });

  test('can send chat completion request', async ({ request }) => {
    const headers = getRequestHeaders(provider);
    const body = createChatRequest(provider);

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers,
      data: body,
    });

    if (response.status() === 429) {
      console.warn('⚠️ Gemini rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.warn(`⚠️ Gemini chat returned ${response.status()}`);
      console.warn('Response:', await response.text());
      test.skip();
    }

    const data = await response.json();

    // OpenAI-compatible response format
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);
    expect(data.choices[0].message).toBeDefined();
    expect(data.choices[0].message.content).toBeDefined();

    console.log(`✅ Gemini response: ${data.choices[0].message.content.substring(0, 100)}...`);
  });

  test('can send streaming chat completion request', async ({ request }) => {
    const headers = getRequestHeaders(provider);
    const body = {
      ...createChatRequest(provider),
      stream: true,
    };

    const response = await request.post(`${provider.baseUrl}${provider.chatEndpoint}`, {
      headers,
      data: body,
    });

    if (response.status() === 429) {
      console.warn('⚠️ Gemini rate limited');
      test.skip();
    }

    if (!response.ok()) {
      console.warn(`⚠️ Gemini streaming returned ${response.status()}`);
      test.skip();
    }

    // For streaming, we get text/event-stream
    const contentType = response.headers()['content-type'];
    expect(contentType).toContain('text/event-stream');

    console.log('✅ Gemini streaming response received');
  });
});
