/**
 * External Dependencies Checker for Tauri E2E Tests
 *
 * Checks for external dependencies (API tokens, WebDAV, etc.)
 * and provides skip patterns for tests that require them.
 */

/// <reference types="@wdio/globals/types" />

import { invokeIPC } from './test-helpers';

export interface ExternalDependency {
  name: string;
  envVar: string;
  available: boolean;
  skipReason?: string;
}

/**
 * Check if an environment variable is set
 */
export async function hasEnvVar(envVar: string): Promise<boolean> {
  const result = await invokeIPC<string>('get_env_var', { name: envVar });
  return result !== null && result.length > 0;
}

/**
 * Check all API token dependencies
 */
export async function checkApiTokenDependencies(): Promise<ExternalDependency[]> {
  const deps: ExternalDependency[] = [
    { name: 'NVIDIA', envVar: 'NVIDIA_TOKEN', available: false },
    { name: 'OpenAI', envVar: 'OPENAI_TOKEN', available: false },
    { name: 'Gemini', envVar: 'GEMINI_TOKEN', available: false },
    { name: 'OpenCode', envVar: 'OPENCODE_TOKEN', available: false },
    { name: 'Kilo', envVar: 'KILO_TOKEN', available: false },
    { name: 'Cloudflare', envVar: 'CLOUDFLARE_API_TOKEN', available: false },
    { name: 'Poe', envVar: 'POE_TOKEN', available: false },
    { name: 'XiaoMi MiNo', envVar: 'XIAOMIMINO_TOKEN', available: false },
    { name: 'Kimi', envVar: 'KIMI_TOKEN', available: false },
  ];

  for (const dep of deps) {
    dep.available = await hasEnvVar(dep.envVar);
    if (!dep.available) {
      dep.skipReason = `${dep.envVar} not set`;
    }
  }

  return deps;
}

/**
 * Check WebDAV dependency
 */
export async function checkWebDAVDependency(): Promise<ExternalDependency> {
  const url = await invokeIPC<string>('get_env_var', { name: 'TEST_WEBDAV_URL' });
  return {
    name: 'WebDAV',
    envVar: 'TEST_WEBDAV_URL',
    available: url !== null && url.length > 0,
    skipReason: url ? undefined : 'TEST_WEBDAV_URL not set',
  };
}

/**
 * Check OpenClaw Gateway dependency
 */
export async function checkOpenClawGatewayDependency(): Promise<ExternalDependency> {
  const gateway = await invokeIPC<string>('get_env_var', { name: 'TEST_OPENCLAW_GATEWAY' });
  return {
    name: 'OpenClaw Gateway',
    envVar: 'TEST_OPENCLAW_GATEWAY',
    available: gateway !== null && gateway.length > 0,
    skipReason: gateway ? undefined : 'TEST_OPENCLAW_GATEWAY not set',
  };
}

/**
 * Get all external dependencies status
 */
export async function getAllDependencies(): Promise<{
  apiTokens: ExternalDependency[];
  webdav: ExternalDependency;
  openclawGateway: ExternalDependency;
}> {
  const [apiTokens, webdav, openclawGateway] = await Promise.all([
    checkApiTokenDependencies(),
    checkWebDAVDependency(),
    checkOpenClawGatewayDependency(),
  ]);

  return { apiTokens, webdav, openclawGateway };
}

/**
 * Check if any API token is available for testing
 */
export async function hasAnyApiToken(): Promise<boolean> {
  const deps = await checkApiTokenDependencies();
  return deps.some((dep) => dep.available);
}

/**
 * Get available API providers
 */
export async function getAvailableApiProviders(): Promise<string[]> {
  const deps = await checkApiTokenDependencies();
  return deps.filter((dep) => dep.available).map((dep) => dep.name);
}

/**
 * Skip test if no API tokens available
 * Use with describe.skipIf()
 */
export function shouldSkipApiTests(): Promise<boolean> {
  return hasAnyApiToken().then((has) => !has);
}

/**
 * Skip test if WebDAV not available
 */
export function shouldSkipWebDAVTests(): Promise<boolean> {
  return checkWebDAVDependency().then((dep) => !dep.available);
}

/**
 * Skip test if OpenClaw Gateway not available
 */
export function shouldSkipOpenClawGatewayTests(): Promise<boolean> {
  return checkOpenClawGatewayDependency().then((dep) => !dep.available);
}

/**
 * Log available dependencies for debugging
 */
export async function logDependencyStatus(): Promise<void> {
  const deps = await getAllDependencies();

  console.log('\n[Dependencies Status]');
  console.log('API Tokens:');
  for (const dep of deps.apiTokens) {
    console.log(`  ${dep.name}: ${dep.available ? '✓' : '✗'} ${dep.skipReason || ''}`);
  }
  console.log(`WebDAV: ${deps.webdav.available ? '✓' : '✗'} ${deps.webdav.skipReason || ''}`);
  console.log(`OpenClaw Gateway: ${deps.openclawGateway.available ? '✓' : '✗'} ${deps.openclawGateway.skipReason || ''}`);
}