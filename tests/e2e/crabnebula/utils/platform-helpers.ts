/**
 * Platform Helpers for E2E Tests
 *
 * Provides platform detection and conditional test execution
 */

/// <reference types="@wdio/globals/types" />

export type Platform = 'macos' | 'windows' | 'linux';

/**
 * Get current platform
 */
export async function getPlatform(): Promise<Platform> {
  return browser.execute(() => {
    // Try modern API first (navigator.userAgentData)
    const nav = navigator as any;
    if (nav.userAgentData?.platform) {
      const platform = nav.userAgentData.platform;
      if (platform.includes('Mac')) return 'macos';
      if (platform.includes('Windows')) return 'windows';
      return 'linux';
    }
    // Fallback to userAgent string for broader compatibility
    const ua = navigator.userAgent;
    if (ua.includes('Mac')) return 'macos';
    if (ua.includes('Windows')) return 'windows';
    return 'linux';
  });
}

/**
 * Check if running on macOS
 */
export async function isMacOS(): Promise<boolean> {
  const platform = await getPlatform();
  return platform === 'macos';
}

/**
 * Check if running on Windows
 */
export async function isWindows(): Promise<boolean> {
  const platform = await getPlatform();
  return platform === 'windows';
}

/**
 * Check if running on Linux
 */
export async function isLinux(): Promise<boolean> {
  const platform = await getPlatform();
  return platform === 'linux';
}

/**
 * Skip test if not on specified platform
 * Returns true if test should be skipped
 */
export async function skipIfNotPlatform(expectedPlatform: Platform): Promise<boolean> {
  const current = await getPlatform();
  if (current !== expectedPlatform) {
    console.log(`Skipping test: expected ${expectedPlatform}, running on ${current}`);
    return true;
  }
  return false;
}

/**
 * Get platform-specific keyboard modifier
 */
export async function getModifierKey(): Promise<string> {
  const isMac = await isMacOS();
  return isMac ? 'Meta' : 'Control';
}

/**
 * Check if running in headless mode
 */
export async function isHeadless(): Promise<boolean> {
  return browser.execute(() => {
    // Check for common headless indicators
    const nav = navigator as any;
    return nav.webdriver === true ||
           /HeadlessChrome/.test(navigator.userAgent);
  });
}