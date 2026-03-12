/**
 * API Provider configurations and utilities for E2E testing
 */

export interface ProviderConfig {
  name: string;
  tokenEnvVar: string;
  baseUrl?: string;
  modelsEndpoint?: string;
  chatEndpoint?: string;
  testModel: string;
  testMessage: string;
  expectedResponseContains?: string;
  headers?: Record<string, string>;
}

/**
 * Provider configurations for testing
 * Tokens are loaded from environment variables (.env)
 */
export const API_PROVIDERS: ProviderConfig[] = [
  {
    name: 'NVIDIA NIM',
    tokenEnvVar: 'NVIDIA_TOKEN',
    baseUrl: 'https://integrate.api.nvidia.com',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'meta/llama-3.1-8b-instruct',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'OpenAI',
    tokenEnvVar: 'OPENAI_TOKEN',
    baseUrl: 'https://api.openai.com',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'gpt-4o-mini',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Google Gemini',
    tokenEnvVar: 'GEMINI_TOKEN',
    baseUrl: 'https://generativelanguage.googleapis.com',
    modelsEndpoint: '/v1beta/models',
    chatEndpoint: '/v1beta/models/gemini-2.0-flash:generateContent',
    testModel: 'gemini-2.0-flash',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'OpenCode Zen',
    tokenEnvVar: 'OPENCODE_TOKEN',
    baseUrl: 'https://opencode.ai',
    modelsEndpoint: '', // Zen uses model-specific endpoints, no models list
    chatEndpoint: '/zen/v1/chat/completions',
    testModel: 'minimax-m2.5-free', // Free model via Zen
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token}', // OpenAI-compatible format
    },
  },
  {
    name: 'Kilo Code',
    tokenEnvVar: 'KILO_TOKEN',
    baseUrl: 'https://api.kilocode.ai',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'kilo-default',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'XiaoMi MiNo',
    tokenEnvVar: 'XIAOMIMINO_TOKEN',
    baseUrl: 'https://api.minos.ai',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'mino-default',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Huawei',
    tokenEnvVar: 'HUAWEI_TOKEN',
    baseUrl: 'https://api.huaweicloud.com',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'huawei-default',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Cloudflare',
    tokenEnvVar: 'CLOUDFLARE_API_TOKEN',
    baseUrl: 'https://api.cloudflare.com',
    modelsEndpoint: '/client/v4/ai/models',
    chatEndpoint: '/client/v4/ai/run/@cf/meta/llama-2-7b-chat-int8',
    testModel: '@cf/meta/llama-2-7b-chat-int8',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Poe',
    tokenEnvVar: 'POE_TOKEN',
    baseUrl: 'https://api.poe.com',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'claude-3-sonnet',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
];

/**
 * Check if a provider has a valid token configured
 */
export function hasValidToken(provider: ProviderConfig): boolean {
  const token = process.env[provider.tokenEnvVar];
  return !!token && token.length > 10;
}

/**
 * Get the API token for a provider
 */
export function getToken(provider: ProviderConfig): string | undefined {
  return process.env[provider.tokenEnvVar];
}

/**
 * Get active providers (those with valid tokens)
 */
export function getActiveProviders(): ProviderConfig[] {
  return API_PROVIDERS.filter(hasValidToken);
}

/**
 * Create chat completion request body
 */
export function createChatRequest(provider: ProviderConfig): Record<string, unknown> {
  return {
    model: provider.testModel,
    messages: [
      { role: 'user', content: provider.testMessage },
    ],
    max_tokens: 50,
    temperature: 0.7,
  };
}

/**
 * Get request headers for a provider
 */
export function getRequestHeaders(provider: ProviderConfig): Record<string, string> {
  const token = getToken(provider);
  return {
    ...provider.headers,
    Authorization: `Bearer ${token}`,
  };
}
