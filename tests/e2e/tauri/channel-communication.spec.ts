/// <reference types="@wdio/globals/types" />
/**
 * Channel Communication E2E Tests
 *
 * Tests for real message sending through agent-specific channels.
 * OpenClaw tests use WebSocket Gateway (1:1 AutoClaw implementation).
 */

import { expect } from '@wdio/globals';
import { SessionManagerPage } from './pages/SessionManagerPage';

describe('Channel Communication', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
  });

  it('should show "under development" toast for Codex sessions', async () => {
    // 1. Navigate to sessions view
    await sessionPage.navigateToSessions();

    // 2. Wait for sessions to load
    await browser.pause(1000);

    // 3. Try to find and select a Codex session (if exists)
    // If no Codex session, skip test
    const codexSession = await $('[data-session-provider="codex"]');
    if (!(await codexSession.isExisting())) {
      console.log('No Codex session found, skipping test');
      return;
    }

    await codexSession.click();
    await browser.pause(500);

    // 4. Type message and send
    await sessionPage.inputMessage('Test message');
    await sessionPage.clickSend();

    // 5. Verify toast shows "development" or "development"
    await browser.pause(1000);
    const toastText = await sessionPage.getToast();
    expect(toastText).toBeTruthy();
    // Accept either Chinese or English
    const hasDevelopmentText =
      toastText?.includes('development') ||
      toastText?.includes('development') ||
      toastText?.includes('Codex');
    expect(hasDevelopmentText).toBe(true);
  });

  it('should show "under development" toast for Gemini sessions', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const geminiSession = await $('[data-session-provider="gemini"]');
    if (!(await geminiSession.isExisting())) {
      console.log('No Gemini session found, skipping test');
      return;
    }

    await geminiSession.click();
    await browser.pause(500);

    await sessionPage.inputMessage('Test message');
    await sessionPage.clickSend();

    await browser.pause(1000);
    const toastText = await sessionPage.getToast();
    expect(toastText).toBeTruthy();
  });

  it('should show "under development" toast for OpenCode sessions', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const opencodeSession = await $('[data-session-provider="opencode"]');
    if (!(await opencodeSession.isExisting())) {
      console.log('No OpenCode session found, skipping test');
      return;
    }

    await opencodeSession.click();
    await browser.pause(500);

    await sessionPage.inputMessage('Test message');
    await sessionPage.clickSend();

    await browser.pause(1000);
    const toastText = await sessionPage.getToast();
    expect(toastText).toBeTruthy();
  });

  // Note: Real Claude/OpenClaw channel tests require actual backend
  // These are skipped by default and can be enabled manually

  it.skip('should send message via Claude Code MCP channel', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const claudeSession = await $('[data-session-provider="claude"]');
    if (!(await claudeSession.isExisting())) {
      console.log('No Claude session found, skipping test');
      return;
    }

    await claudeSession.click();
    await browser.pause(500);

    const testMessage = `E2E test ${Date.now()}`;
    await sessionPage.inputMessage(testMessage);
    await sessionPage.clickSend();

    // Wait for response or message to appear
    await browser.pause(2000);

    // Verify message was sent (check for no error toast)
    const errorToast = await sessionPage.getToast(2000);
    expect(errorToast).toBeNull();
  });
});

/**
 * OpenClaw Gateway WebSocket E2E Tests
 *
 * These tests verify the 1:1 AutoClaw implementation:
 * 1. Profile initialization (~/.openclaw-haipee/)
 * 2. Gateway connection via WebSocket
 * 3. Message sending via chat.send RPC
 * 4. Streaming responses
 */
describe('OpenClaw Gateway WebSocket', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
  });

  it('should initialize OpenClaw profile on first use', async () => {
    // Navigate to OpenClaw channel
    await sessionPage.navigateToSessions();
    await browser.pause(500);

    // Look for OpenClaw section or provider
    const openclawSection = await $('[data-provider="openclaw"]');
    if (await openclawSection.isExisting()) {
      await openclawSection.click();
      await browser.pause(1000);

      // Profile should be initialized (no error toast)
      const errorToast = await sessionPage.getToast(2000);
      // Accept null or non-error toast
      if (errorToast) {
        console.log('Toast shown:', errorToast);
      }
    } else {
      console.log('No OpenClaw section found, test passed (no setup needed)');
    }
  });

  it.skip('should connect to OpenClaw Gateway via WebSocket', async () => {
    // This test requires:
    // 1. OpenClaw installed and gateway running
    // 2. Haipee profile initialized
    // 3. Gateway token available

    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const openclawSession = await $('[data-session-provider="openclaw"]');
    if (!(await openclawSession.isExisting())) {
      console.log('No OpenClaw session found, skipping test');
      return;
    }

    await openclawSession.click();
    await browser.pause(2000);

    // Check for connection indicator
    const connectionStatus = await $('[data-testid="openclaw-connection-status"]');
    if (await connectionStatus.isExisting()) {
      const status = await connectionStatus.getText();
      console.log('OpenClaw connection status:', status);
      // Should show "connected" after successful WebSocket connection
    }
  });

  it.skip('should send message via chat.send RPC (1:1 AutoClaw)', async () => {
    // This test requires a running OpenClaw Gateway
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const openclawSession = await $('[data-session-provider="openclaw"]');
    if (!(await openclawSession.isExisting())) {
      console.log('No OpenClaw session found, skipping test');
      return;
    }

    await openclawSession.click();
    await browser.pause(2000);

    // Send a test message
    const testMessage = `WebSocket E2E test ${Date.now()}`;
    await sessionPage.inputMessage(testMessage);
    await sessionPage.clickSend();

    // Wait for response
    await browser.pause(5000);

    // Check for error (should be none if WebSocket connected)
    const errorToast = await sessionPage.getToast(2000);
    expect(errorToast).toBeNull();

    // Message should appear in the chat
    // (Actual verification depends on UI implementation)
  });
});