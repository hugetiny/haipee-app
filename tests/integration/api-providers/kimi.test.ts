/**
 * Kimi Coding API Provider Tests
 *
 * Note: Kimi Coding API only allows requests from Coding Agents
 * (Kimi CLI, Claude Code, Roo Code, Kilo Code, etc.)
 * Direct API calls are blocked with "access_terminated_error"
 */

import { describe, test, expect } from 'vitest';
import { API_PROVIDERS, getToken } from './utils';

const provider = API_PROVIDERS.find(p => p.name === 'Kimi Coding')!;

// Skip all tests - Kimi Coding blocks non-Agent requests
describe.skip('Kimi Coding Provider', () => {
  test('API token is configured', () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
  });

  test('can fetch available models', async () => {
    const token = getToken(provider);
    const url = `${provider.baseUrl}${provider.modelsEndpoint}`;

    const response = await fetch(url, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    });

    expect(response.ok).toBe(true);
    const data = await response.json();
    expect(data.data).toBeDefined();
  });

  test('can send chat completion request', async () => {
    const token = getToken(provider);
    const url = `${provider.baseUrl}${provider.chatEndpoint}`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        model: provider.testModel,
        messages: [{ role: 'user', content: provider.testMessage }],
        max_tokens: 50,
        stream: false,
      }),
    });

    expect(response.ok).toBe(true);
    const data = await response.json();
    expect(data.choices).toBeDefined();
    expect(data.choices.length).toBeGreaterThan(0);
    expect(data.choices[0].message.content).toBeDefined();

    console.log(`✅ Kimi Coding response: ${data.choices[0].message.content.substring(0, 100)}...`);
  });
});