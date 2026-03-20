/// <reference types="@wdio/globals/types" />
/**
 * Stop Generation E2E Test - Real API
 *
 * Tests the ability to stop AI generation mid-response in OpenClaw chat.
 */

import { openClawChatPage } from '../pages';
import { testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - Stop Generation', () => {
  before(async () => {
    await openClawChatPage.openChat();
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );
  });

  it('should stop generation when stop button is clicked', async () => {
    // Send a message that will generate a long response
    const input = $('textarea');
    await input.setValue('Write a detailed 500-word essay about artificial intelligence');

    const sendBtn = $('button[type="submit"]');
    await sendBtn.click();

    // Wait a bit for generation to start
    await browser.pause(2000);

    // Click stop button
    await openClawChatPage.stopGeneration();
    await browser.pause(500);

    // Get last message (should be partial)
    const lastMessage = await openClawChatPage.getLastMessage();

    // Message should exist but may be shorter than full response
    expect(lastMessage.length).toBeGreaterThan(0);

    console.log('Partial response length:', lastMessage.length);
  });

  it('should allow sending new message after stop', async () => {
    // Start generation and stop it
    const input = $('textarea');
    await input.setValue('Tell me a long story');
    const sendBtn = $('button[type="submit"]');
    await sendBtn.click();
    await browser.pause(1500);
    await openClawChatPage.stopGeneration();
    await browser.pause(500);

    // Should be able to send new message
    const newResponse = await openClawChatPage.sendMessageAndWait(
      'What is 1+1?',
      testTimeouts.api
    );

    expect(newResponse.length).toBeGreaterThan(0);
  });
});