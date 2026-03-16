/**
 * AI Development Loop - Fix Orchestrator
 * Coordinate AI agents to fix test failures
 */

import { spawn } from 'child_process';
import * as fs from 'fs';
import type { TestFailure, FixResult } from './types.ts';
import { log, logFixAttempt, logFixSuccess, logFixFailed } from './logger.ts';

interface FixContext {
  failure: TestFailure;
  dryRun: boolean;
}

export async function fixFailure(failure: TestFailure, dryRun: boolean = false): Promise<FixResult> {
  logFixAttempt(failure.testName, failure.fixAttempts + 1, 3);

  const context: FixContext = { failure, dryRun };

  try {
    switch (failure.type) {
      case 'build-error':
      case 'type-error':
      case 'import-error':
        return await fixBuildError(context);
      case 'runtime-error':
        return await fixRuntimeError(context);
      case 'assertion-failure':
        return await fixAssertionFailure(context);
      case 'timeout-error':
        return await fixTimeoutError(context);
      case 'flaky':
        return await fixFlakyTest(context);
      case 'network-error':
        return await fixNetworkError(context);
      default:
        return await fixGenericError(context);
    }
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    logFixFailed(failure.testName, errorMsg);
    return { success: false, filesModified: [], error: errorMsg };
  }
}

async function fixBuildError(context: FixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using build-error-resolver for ${failure.type} in ${failure.filePath}`);

  const prompt = createFixPrompt(failure, 'build-error');

  if (dryRun) {
    log('info', `[DRY RUN] Would call build-error-resolver for: ${failure.testName}`);
    return { success: true, filesModified: [], description: 'Dry run - no changes made' };
  }

  return await callClaudeAgent('build-error-resolver', prompt);
}

async function fixRuntimeError(context: FixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using code-reviewer for runtime error in ${failure.filePath}`);

  const prompt = createFixPrompt(failure, 'runtime-error');

  if (dryRun) {
    log('info', `[DRY RUN] Would call code-reviewer for: ${failure.testName}`);
    return { success: true, filesModified: [], description: 'Dry run - no changes made' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

async function fixAssertionFailure(context: FixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using tdd-guide for assertion failure in ${failure.filePath}`);

  const prompt = createFixPrompt(failure, 'assertion-failure');

  if (dryRun) {
    log('info', `[DRY RUN] Would call tdd-guide for: ${failure.testName}`);
    return { success: true, filesModified: [], description: 'Dry run - no changes made' };
  }

  return await callClaudeAgent('tdd-guide', prompt);
}

async function fixTimeoutError(context: FixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Analyzing timeout error in ${failure.filePath}`);

  const prompt = `Fix the timeout error in this test.

Test: ${failure.testName}
File: ${failure.filePath}
Error: ${failure.errorMessage}

Check for:
1. Missing 'await' on async operations
2. Infinite loops or recursion
3. Slow operations that need optimization
4. Test timeout configuration that needs adjustment

Make minimal changes to fix the timeout.`;

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - timeout analysis' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

async function fixFlakyTest(context: FixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Addressing flaky test: ${failure.testName}`);

  const prompt = `This test is flaky (non-deterministic). Make it more reliable.

Test: ${failure.testName}
File: ${failure.filePath}

Common fixes for flaky tests:
1. Add explicit waits instead of setTimeout
2. Use more specific selectors (data-testid instead of CSS)
3. Reset state between test runs
4. Mock non-deterministic operations (timers, random, dates)
5. Wait for network requests to complete
6. Increase timeout for slow operations

Make minimal changes to improve stability.`;

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - flaky test analysis' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

async function fixNetworkError(context: FixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Analyzing network error in ${failure.filePath}`);

  const prompt = `Fix this network error in the E2E test.

Test: ${failure.testName}
File: ${failure.filePath}
Error: ${failure.errorMessage}

This appears to be a network/WebDriver error. Check:
1. WebDriver connection setup
2. Tauri app startup waits
3. Network mocking configuration
4. Retry logic for transient failures

Make minimal changes to improve reliability.`;

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - network error analysis' };
  }

  return await callClaudeAgent('build-error-resolver', prompt);
}

async function fixGenericError(context: FixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using generic fix strategy for unknown error type`);

  const prompt = createFixPrompt(failure, 'generic');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - generic fix' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

function createFixPrompt(failure: TestFailure, fixType: string): string {
  let specificInstructions = '';

  switch (fixType) {
    case 'build-error':
      specificInstructions = 'Fix the compilation/type/import error. Check for missing imports, type mismatches, and syntax errors.';
      break;
    case 'runtime-error':
      specificInstructions = 'Fix the runtime error. Check for: null references, undefined values, incorrect API usage.';
      break;
    case 'assertion-failure':
      specificInstructions = 'Fix the failing test. Either fix the implementation to match the test expectation, OR fix the test if the expectation is wrong.';
      break;
    default:
      specificInstructions = 'Analyze the error and make minimal changes to fix it.';
  }

  const fileContent = getFileContent(failure.filePath);
  const relatedContent = failure.context?.relatedFiles
    ?.slice(0, 3)
    .map((f) => `\n=== ${f} ===\n${getFileContent(f)}`)
    .join('\n') || '';

  return `Fix this test failure.

Test: ${failure.testName}
File: ${failure.filePath}
Error: ${failure.errorMessage}
Type: ${failure.type}

${specificInstructions}

${fileContent ? `\n=== TEST FILE ===\n${fileContent.substring(0, 3000)}` : ''}
${relatedContent ? `\n=== RELATED FILES ===\n${relatedContent.substring(0, 3000)}` : ''}

Instructions:
1. Make minimal changes to fix the issue
2. Follow existing code patterns
3. Ensure TypeScript types are correct
4. Do not modify test files unless the test itself is wrong
5. After fixing, run the test to verify

Provide a brief description of the changes made.`;
}

function getFileContent(filePath: string): string {
  try {
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, 'utf-8');
    }
  } catch {
    // Ignore read errors
  }
  return '';
}

/**
 * Call Claude Code agent using the Skill system
 */
async function callClaudeAgent(agentName: string, prompt: string): Promise<FixResult> {
  log('info', `Calling agent: ${agentName}`);

  try {
    // In this environment, we use the Skill tool to invoke agents
    // The skill will write files directly to fix the issue

    // Save prompt for debugging
    const promptFile = `./ai-loop-logs/agent-prompt-${Date.now()}.txt`;
    fs.writeFileSync(promptFile, `Agent: ${agentName}\n\n${prompt}`);
    log('info', `Agent prompt saved to: ${promptFile}`);

    // For now, we return a placeholder indicating the agent needs to be called
    // In production, this would invoke the actual skill
    log('info', `Agent ${agentName} would be called with prompt (${prompt.length} chars)`);

    // Simulate agent execution - in real implementation, this would:
    // 1. Call the skill: skill "${agentName}" with the prompt
    // 2. Wait for the agent to complete file modifications
    // 3. Check which files were modified

    return {
      success: false,
      filesModified: [],
      error: `Agent ${agentName} invocation requires manual execution. Prompt saved to ${promptFile}. Run: skill "${agentName}" "$(cat ${promptFile})"`,
    };

  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    log('error', `Agent call failed: ${errorMsg}`);
    return { success: false, filesModified: [], error: errorMsg };
  }
}

export async function validateFix(failure: TestFailure): Promise<boolean> {
  log('info', `Validating fix for: ${failure.testName}`);

  const { runSingleTest } = await import('./test-runner.ts');
  const result = await runSingleTest(failure.filePath, 120000);

  if (result.passed) {
    logFixSuccess(failure.testName);
    return true;
  }

  logFixFailed(failure.testName, 'Test still failing after fix');
  return false;
}

export function rollbackChanges(): void {
  log('info', 'Rolling back changes...');

  try {
    const { execSync } = require('child_process');
    execSync('git checkout -- .', { stdio: 'ignore' });
    log('info', 'Changes rolled back successfully');
  } catch (error) {
    log('error', 'Failed to rollback changes', {
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
