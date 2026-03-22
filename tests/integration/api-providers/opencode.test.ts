/**
 * OpenCode Zen API Provider Tests
 */

import { describe, test, expect } from 'vitest';
import { API_PROVIDERS, getToken, skipIfNoToken } from './utils';

const provider = API_PROVIDERS.find(p => p.name === 'OpenCode Zen')!;

describe.skipIf(skipIfNoToken(provider))('OpenCode Zen Provider', () => {
  test('API token is configured', () => {
    const token = getToken(provider);
    expect(token).toBeDefined();
    expect(token!.length).toBeGreaterThan(10);
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

    console.log(`✅ OpenCode Zen response: ${data.choices[0].message.content.substring(0, 100)}...`);
  });
});