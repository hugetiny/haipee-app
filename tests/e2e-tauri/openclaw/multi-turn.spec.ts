/// <reference types="@wdio/globals/types" />
/**
 * Multi-Turn Conversation E2E Test - Real API
 *
 * Tests the OpenClaw agent's ability to maintain context
 * across multiple messages in a conversation.
 */

import { openClawChatPage } from '../pages';
import { testMessages, testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - Multi-Turn Conversation', () => {
  before(async () => {
    await openClawChatPage.openChat();
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );

    // Start a new session for clean state
    await openClawChatPage.newSession();
    await browser.pause(500);
  });

  it('should maintain context across multiple messages', async () => {
    const questions = testMessages.multiTurn;
    const responses: string[] = [];

    for (const question of questions) {
      const response = await openClawChatPage.sendMessageAndWait(
        question,
        testTimeouts.api
      );
      responses.push(response);
      console.log(`Q: ${question}`);
      console.log(`A: ${response.substring(0, 100)}...`);
    }

    // All responses should be non-empty
    expect(responses.every((r: string) => r.length > 0)).toBe(true);

    // Last response should reference the context (result should be 12)
    const lastResponse = responses[responses.length - 1].toLowerCase();
    const hasNumber = lastResponse.includes('12') || lastResponse.includes('twelve');
    expect(hasNumber).toBe(true);
  });

  it('should handle sequential code-related questions', async () => {
    // Start fresh
    await openClawChatPage.newSession();
    await browser.pause(500);

    // First: Ask to create a function
    const response1 = await openClawChatPage.sendMessageAndWait(
      'Create a simple Python function called "greet" that takes a name and returns "Hello, {name}!"',
      testTimeouts.api
    );
    expect(response1.toLowerCase()).toContain('def greet');

    // Second: Ask to modify it
    const response2 = await openClawChatPage.sendMessageAndWait(
      'Now modify it to handle None input by returning "Hello, World!"',
      testTimeouts.api
    );
    expect(response2.length).toBeGreaterThan(0);

    // Third: Ask about the function
    const response3 = await openClawChatPage.sendMessageAndWait(
      'What does the function return when called with greet(None)?',
      testTimeouts.api
    );
    expect(response3.toLowerCase()).toContain('hello');
  });
});