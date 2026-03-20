/// <reference types="@wdio/globals/types" />
/**
 * Send Message E2E Test - Real API
 *
 * Tests the send message functionality in OpenClaw chat using real API calls.
 */

import { openClawChatPage } from '../pages';
import { testMessages, testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - Send Message', () => {
  before(async () => {
    await openClawChatPage.openChat();
    // Ensure we're ready for input
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );
  });

  it('should send a message and receive a response', async () => {
    const message = testMessages.simple;

    // Send message and wait for response
    const response = await openClawChatPage.sendMessageAndWait(
      message,
      testTimeouts.api
    );

    // Verify we got a non-empty response
    expect(response.length).toBeGreaterThan(0);

    // Log response for debugging
    console.log('AI Response:', response.substring(0, 100) + '...');
  });

  it('should display user message in chat history', async () => {
    const message = `Test message ${Date.now()}`;

    await openClawChatPage.sendMessageAndWait(message, testTimeouts.api);

    // Get all messages
    const messages = await openClawChatPage.getAllMessages();

    // Verify user message appears
    const found = messages.some((m: string) => m.includes(message));
    expect(found).toBe(true);
  });

  it('should handle special characters in message', async () => {
    const specialMessages = [
      'Test with "quotes"',
      "Test with 'apostrophes'",
      'Test with symbols: @#$%^&*()',
    ];

    for (const msg of specialMessages) {
      const response = await openClawChatPage.sendMessageAndWait(
        msg,
        testTimeouts.api
      );
      expect(response.length).toBeGreaterThan(0);
    }
  });
});