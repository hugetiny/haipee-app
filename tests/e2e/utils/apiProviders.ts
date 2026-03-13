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
    // Gemini OpenAI-compatible endpoint: https://ai.google.dev/gemini-api/docs/openai
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
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
    // Kilo.ai Gateway - OpenAI-compatible API
    // https://kilo.ai/docs
    baseUrl: 'https://api.kilocode.ai/v1',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
    testModel: 'gpt-4o-mini',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'XiaoMi MiNo',
    tokenEnvVar: 'XIAOMIMINO_TOKEN',
    // Note: XiaoMi MiNo API endpoint information is limited
    // Endpoint may differ from this configuration
    // See: https://dev.mi.com/ or Xiaomi AI documentation
    baseUrl: 'https://api.minos.ai/v1',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
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
    // Huawei Cloud Pangu AI - Regional endpoints
    // Documentation: https://support.huaweicloud.com/pangulm/
    // Note: Requires regional endpoint configuration
    // OpenAI-compatible endpoint format
    baseUrl: 'https://pangu.huaweicloud.com/v1',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
    testModel: 'pangu-llm',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Cloudflare',
    tokenEnvVar: 'CLOUDFLARE_API_TOKEN',
    // Cloudflare Workers AI OpenAI-compatible endpoint
    // Requires CLOUDFLARE_ACCOUNT_ID env var for the account ID
    // https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/
    baseUrl: 'https://api.cloudflare.com/client/v4/accounts',
    modelsEndpoint: '', // No standard models endpoint in OpenAI-compatible mode
    chatEndpoint: '/ai/v1/chat/completions',
    testModel: '@cf/meta/llama-3.1-8b-instruct',
    testMessage: 'Hello, this is a test message from Haipee E2E tests.',
    expectedResponseContains: '',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Poe',
    tokenEnvVar: 'POE_TOKEN',
    // Poe API - OpenAI-compatible endpoint
    // Documentation: https://creator.poe.com/docs/external-applications/openai-compatible-api
    // Get API key: https://poe.com/api/keys
    baseUrl: 'https://api.poe.com/v1',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
    testModel: 'Claude-Sonnet-4',
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
