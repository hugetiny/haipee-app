/// <reference types="@wdio/globals/types" />
/**
 * Channel Communication E2E Tests
 *
 * Tests for real message sending through agent-specific channels.
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

  it.skip('should send message via OpenClaw Gateway', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const openclawSession = await $('[data-session-provider="openclaw"]');
    if (!(await openclawSession.isExisting())) {
      console.log('No OpenClaw session found, skipping test');
      return;
    }

    await openclawSession.click();
    await browser.pause(500);

    const testMessage = `E2E test ${Date.now()}`;
    await sessionPage.inputMessage(testMessage);
    await sessionPage.clickSend();

    await browser.pause(2000);

    const errorToast = await sessionPage.getToast(2000);
    expect(errorToast).toBeNull();
  });
});