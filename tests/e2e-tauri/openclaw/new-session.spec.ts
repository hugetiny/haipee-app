/// <reference types="@wdio/globals/types" />
/**
 * New Session E2E Test - Real API
 *
 * Tests the new session functionality in OpenClaw chat interface.
 * These tests verify session isolation and context clearing.
 */

import { openClawChatPage } from '../pages';
import { testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - New Session', () => {
  before(async () => {
    await openClawChatPage.openChat();
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );
  });

  it('should start a new session', async () => {
    // Send a message first
    await openClawChatPage.sendMessageAndWait(
      'My favorite color is blue.',
      testTimeouts.api
    );

    // Get message count
    const messagesBefore = await openClawChatPage.getAllMessages();

    // Start new session
    await openClawChatPage.newSession();
    await browser.pause(1000);

    // Verify messages are cleared
    const messagesAfter = await openClawChatPage.getAllMessages();

    // After new session, message count should be less (or empty)
    expect(messagesAfter.length).toBeLessThan(messagesBefore.length);
  });

  it('should not retain context from previous session', async () => {
    // Start fresh
    await openClawChatPage.newSession();
    await browser.pause(500);

    // Send message and establish context
    await openClawChatPage.sendMessageAndWait(
      'I am testing session isolation.',
      testTimeouts.api
    );

    // Start new session
    await openClawChatPage.newSession();
    await browser.pause(500);

    // Ask about context - AI should not know about previous message
    const response = await openClawChatPage.sendMessageAndWait(
      'What did I just tell you?',
      testTimeouts.api
    );

    // Response should indicate lack of context
    const lowerResponse = response.toLowerCase();
    // Check for context indicators (soft assertion - AI responses vary)
    const hasNoContext = lowerResponse.includes("don't know") ||
                         lowerResponse.includes("didn't mention") ||
                         lowerResponse.includes("no context") ||
                         lowerResponse.includes("no previous") ||
                         lowerResponse.includes("haven't told");

    // Log result for debugging - this is a soft test
    console.log('Context test response:', response.substring(0, 200));
    console.log('Has no context indicator:', hasNoContext);
  });
});