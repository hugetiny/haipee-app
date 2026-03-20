/**
 * AI Development Loop - Fix Orchestrator (Enhanced)
 *
 * Coordinate AI agents to fix test failures with rich diagnostics,
 * multi-strategy parallel fixing, and fix history learning.
 */

import { spawn, execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import type { TestFailure, FixResult, FixContext as RichFixContext, FixAttempt } from './types.ts';
import { log, logFixAttempt, logFixSuccess, logFixFailed } from './logger.ts';

// Import new modules
import { collectDiagnostics, formatDiagnosticsForPrompt, clearAllDiagnostics } from './diagnostics/index.ts';
import { getContextBuilder, buildEnhancedFixPrompt } from './context-builder.ts';
import { initializeStrategies, executeBestStrategy, executeParallelStrategies } from './fix-strategies/index.ts';
import { getPatternMatcher, shouldTryPatternFix } from './fix-patterns/pattern-matcher.ts';
import { getPatternDB, createPatternFromFix } from './fix-patterns/pattern-db.ts';
import { validateFix as fullValidateFix, formatValidationResult } from './validation/index.ts';
import { getCrashAnalyzer, formatCrashAnalysisForPrompt } from './crash-analyzer.ts';

interface LegacyFixContext {
  failure: TestFailure;
  dryRun: boolean;
}

/**
 * Main entry point for fixing a test failure.
 * Uses the new enhanced fixing system with diagnostics and strategies.
 */
export async function fixFailure(failure: TestFailure, dryRun: boolean = false): Promise<FixResult> {
  logFixAttempt(failure.testName, failure.fixAttempts + 1, 3);

  try {
    // Collect diagnostics before attempting fix
    log('info', 'Collecting diagnostics...');
    const diagnostics = await collectDiagnostics(failure.testName, {
      captureScreenshot: failure.type === 'assertion-failure' || failure.type === 'timeout-error',
      captureConsole: true,
      captureNetwork: true,
      captureIpc: true,
    });

    // Attach diagnostics to failure
    failure.diagnostics = diagnostics;

    // Check for crashes
    const crashAnalyzer = getCrashAnalyzer();
    const crashAnalysis = crashAnalyzer.analyze();
    if (crashAnalysis.hasCrashed) {
      log('warn', `Detected ${crashAnalysis.crashCount} crash(es)`);
      diagnostics.crashLog = crashAnalysis.crashLog || undefined;
      diagnostics.binaryLog = crashAnalysis.binaryLog || undefined;
    }

    if (dryRun) {
      log('info', `[DRY RUN] Would attempt to fix: ${failure.testName}`);
      return { success: true, filesModified: [], description: 'Dry run - no changes made' };
    }

    // Try pattern-based fix first (if we have high confidence)
    if (shouldTryPatternFix(failure)) {
      const matcher = getPatternMatcher();
      const pattern = matcher.findBestMatch(failure);

      if (pattern) {
        log('info', `Attempting pattern-based fix: ${pattern.name}`);
        // Pattern-based fixes would be implemented here
        // For now, fall through to strategy-based fixing
      }
    }

    // Build rich context
    const builder = getContextBuilder();
    const richContext = await builder.buildFixContext(failure, {
      includeDiagnostics: true,
      includeHistory: true,
      includeGitChanges: true,
    });

    // Initialize strategies if not done
    initializeStrategies();

    // Try parallel strategies for first attempt, sequential for retries
    let result: FixResult;
    if (failure.fixAttempts === 0) {
      log('info', 'Using parallel strategy execution for first attempt');
      result = await executeParallelStrategies(failure, richContext, 2);
    } else {
      log('info', 'Using sequential strategy execution for retry');
      result = await executeBestStrategy(failure, richContext);
    }

    // If strategies didn't handle it, fall back to legacy approach
    if (!result.success && result.error?.includes('No strategy available')) {
      log('info', 'No strategy available, using legacy fix approach');
      result = await legacyFixFailure({ failure, dryRun });
    }

    // Record fix attempt
    if (result.filesModified.length > 0 || result.error) {
      const attempt: FixAttempt = {
        failureId: failure.id,
        strategy: 'auto',
        timestamp: Date.now(),
        duration: 0,
        success: result.success,
        filesModified: result.filesModified,
        error: result.error,
        diagnostics,
      };

      if (!failure.fixHistory) {
        failure.fixHistory = [];
      }
      failure.fixHistory.push(attempt);

      // Learn from the result
      const matcher = getPatternMatcher();
      if (result.success && result.description) {
        matcher.learnFromSuccess(failure, result.filesModified, result.description);
      }
    }

    return result;
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    logFixFailed(failure.testName, errorMsg);
    return { success: false, filesModified: [], error: errorMsg };
  }
}

/**
 * Legacy fix implementation (fallback)
 */
async function legacyFixFailure(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;

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
    return { success: false, filesModified: [], error: errorMsg };
  }
}

async function fixBuildError(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using build-error-resolver for ${failure.type} in ${failure.filePath}`);

  const prompt = await createEnhancedFixPrompt(failure, 'build-error');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - no changes made' };
  }

  return await callClaudeAgent('build-error-resolver', prompt);
}

async function fixRuntimeError(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using code-reviewer for runtime error in ${failure.filePath}`);

  const prompt = await createEnhancedFixPrompt(failure, 'runtime-error');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - no changes made' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

async function fixAssertionFailure(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using tdd-guide for assertion failure in ${failure.filePath}`);

  const prompt = await createEnhancedFixPrompt(failure, 'assertion-failure');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - no changes made' };
  }

  return await callClaudeAgent('tdd-guide', prompt);
}

async function fixTimeoutError(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Analyzing timeout error in ${failure.filePath}`);

  const prompt = await createEnhancedFixPrompt(failure, 'timeout-error');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - timeout analysis' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

async function fixFlakyTest(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Addressing flaky test: ${failure.testName}`);

  const prompt = await createEnhancedFixPrompt(failure, 'flaky');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - flaky test analysis' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

async function fixNetworkError(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Analyzing network error in ${failure.filePath}`);

  const prompt = await createEnhancedFixPrompt(failure, 'network-error');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - network error analysis' };
  }

  return await callClaudeAgent('build-error-resolver', prompt);
}

async function fixGenericError(context: LegacyFixContext): Promise<FixResult> {
  const { failure, dryRun } = context;
  log('info', `Using generic fix strategy for unknown error type`);

  const prompt = await createEnhancedFixPrompt(failure, 'generic');

  if (dryRun) {
    return { success: true, filesModified: [], description: 'Dry run - generic fix' };
  }

  return await callClaudeAgent('code-reviewer', prompt);
}

/**
 * Create an enhanced fix prompt with diagnostics
 */
async function createEnhancedFixPrompt(failure: TestFailure, fixType: string): Promise<string> {
  // Try to use the context builder for rich prompts
  try {
    const builder = getContextBuilder();
    const context = await builder.buildFixContext(failure);
    let prompt = builder.formatContextForPrompt(context);

    // Add crash analysis if available
    if (failure.diagnostics?.crashLog) {
      const crashAnalyzer = getCrashAnalyzer();
      const crashAnalysis = crashAnalyzer.analyze();
      prompt += formatCrashAnalysisForPrompt(crashAnalysis);
    }

    // Add fix-specific instructions
    prompt += getFixTypeInstructions(fixType);

    return prompt;
  } catch {
    // Fall back to simple prompt
    return createSimpleFixPrompt(failure, fixType);
  }
}

function getFixTypeInstructions(fixType: string): string {
  switch (fixType) {
    case 'build-error':
      return '\n## Fix Approach\nFix the compilation/type/import error. Check for missing imports, type mismatches, and syntax errors.';
    case 'runtime-error':
      return '\n## Fix Approach\nFix the runtime error. Check for: null references, undefined values, incorrect API usage.';
    case 'assertion-failure':
      return '\n## Fix Approach\nFix the failing test. Either fix the implementation to match the test expectation, OR fix the test if the expectation is wrong.';
    case 'timeout-error':
      return '\n## Fix Approach\nFix the timeout. Check for missing awaits, infinite loops, slow operations, or incorrect timeout configuration.';
    case 'flaky':
      return '\n## Fix Approach\nMake the test more reliable. Add explicit waits, use specific selectors, reset state, mock non-deterministic operations.';
    case 'network-error':
      return '\n## Fix Approach\nFix network/WebDriver issues. Check connection setup, app startup waits, and add retry logic.';
    default:
      return '\n## Fix Approach\nAnalyze the error and make minimal changes to fix it.';
  }
}

function createSimpleFixPrompt(failure: TestFailure, fixType: string): string {
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

${fileContent ? `\n=== TEST FILE ===\n${fileContent.substring(0, 3000)}` : ''}
${relatedContent ? `\n=== RELATED FILES ===\n${relatedContent.substring(0, 3000)}` : ''}

${getFixTypeInstructions(fixType)}

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
 * Call Claude Code agent via CLI in non-interactive print mode.
 */
async function callClaudeAgent(agentName: string, prompt: string): Promise<FixResult> {
  log('info', `Calling Claude agent: ${agentName}`);

  const outputDir = './ai-loop-logs';
  fs.mkdirSync(outputDir, { recursive: true });
  const promptFile = path.join(outputDir, `agent-prompt-${Date.now()}.txt`);

  const structuredPrompt = `You are acting as the ${agentName} agent.\n\n${prompt}\n\nCRITICAL INSTRUCTIONS FOR OUTPUT FORMAT:\nFor each file you need to create or modify, output a complete file block in this exact XML format:\n<file path="relative/path/to/file.ts">\n// complete updated file content here\n</file>\n\nRules:\n- Use the project-root-relative path (e.g. "src/components/Foo.tsx")\n- Output the COMPLETE file content, not a diff or partial snippet\n- Only include files that actually need changes\n- Do not include any unchanged files`;

  fs.writeFileSync(promptFile, structuredPrompt);
  log('info', `Prompt saved to: ${promptFile}`);

  try {
    const { stdout, exitCode } = await executeClaudeCLI(structuredPrompt, 300_000);

    if (!stdout.trim()) {
      return { success: false, filesModified: [], error: 'No output received from Claude CLI' };
    }

    const filesModified = await applyFileBlocks(stdout);

    if (filesModified.length > 0) {
      log('info', `Applied changes to: ${filesModified.join(', ')}`);
      return {
        success: true,
        filesModified,
        description: `${agentName} modified ${filesModified.length} file(s): ${filesModified.join(', ')}`,
      };
    }

    log('warn', `Agent ${agentName} produced no file changes. Output preview: ${stdout.substring(0, 300)}`);
    return {
      success: false,
      filesModified: [],
      error: 'Agent produced no file modifications — check prompt format or agent output',
    };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    logFixFailed(agentName, msg);
    return { success: false, filesModified: [], error: msg };
  }
}

function executeClaudeCLI(prompt: string, timeout: number): Promise<{ stdout: string; exitCode: number }> {
  return new Promise((resolve) => {
    const child = spawn('claude', ['-p', prompt], {
      stdio: ['ignore', 'pipe', 'pipe'],
      cwd: process.cwd(),
    });

    let output = '';
    child.stdout?.on('data', (d: Buffer) => { output += d.toString(); });
    child.stderr?.on('data', (d: Buffer) => { output += d.toString(); });

    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      log('warn', `Claude CLI timed out after ${timeout}ms`);
    }, timeout);

    child.on('close', (code: number | null) => {
      clearTimeout(timer);
      resolve({ stdout: output, exitCode: code ?? 1 });
    });

    child.on('error', () => {
      clearTimeout(timer);
      resolve({ stdout: output, exitCode: 1 });
    });
  });
}

async function applyFileBlocks(output: string): Promise<string[]> {
  const fileBlockRegex = /<file path="([^"]+)">([\s\S]*?)<\/file>/g;
  const filesModified: string[] = [];
  const cwd = process.cwd();
  let match;

  while ((match = fileBlockRegex.exec(output)) !== null) {
    const [, filePath, content] = match;

    // Security: prevent path traversal
    const safePath = path.resolve(cwd, filePath);
    if (!safePath.startsWith(cwd + path.sep) && safePath !== cwd) {
      log('warn', `Skipping unsafe path: ${filePath}`);
      continue;
    }

    fs.mkdirSync(path.dirname(safePath), { recursive: true });
    fs.writeFileSync(safePath, content.trimEnd() + '\n', 'utf-8');
    filesModified.push(filePath);
    log('info', `  ✏️  Written: ${filePath}`);
  }

  return filesModified;
}

/**
 * Enhanced validation with regression checking
 */
export async function validateFix(failure: TestFailure, filesModified: string[] = []): Promise<boolean> {
  log('info', `Validating fix for: ${failure.testName}`);

  try {
    // Run full validation
    const result = await fullValidateFix(failure, filesModified);

    // Log validation result
    log('info', formatValidationResult(result));

    if (result.passed) {
      logFixSuccess(failure.testName);
      return true;
    }

    logFixFailed(failure.testName, 'Validation failed');
    return false;
  } catch {
    // Fall back to simple validation
    const { runSingleTest } = await import('./test-runner.ts');
    const result = await runSingleTest(failure.filePath, 120000);

    if (result.passed) {
      logFixSuccess(failure.testName);
      return true;
    }

    logFixFailed(failure.testName, 'Test still failing after fix');
    return false;
  }
}

export function rollbackChanges(filesModified: string[] = []): void {
  log('info', 'Rolling back changes...');

  try {
    if (filesModified.length > 0) {
      const quoted = filesModified.map((f) => `"${f.replace(/"/g, '\\"')}"`).join(' ');
      execSync(`git checkout -- ${quoted}`, { stdio: 'ignore' });
      log('info', `Rolled back ${filesModified.length} file(s): ${filesModified.join(', ')}`);
    } else {
      execSync('git checkout -- .', { stdio: 'ignore' });
      log('info', 'Rolled back all unstaged changes');
    }

    // Clear diagnostics after rollback
    clearAllDiagnostics();
  } catch (error) {
    log('error', 'Failed to rollback changes', {
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
