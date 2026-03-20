/**
 * Timeout Fix Strategy
 *
 * Handles test failures caused by timeouts.
 */

import { BaseFixStrategy } from './strategy-base.ts';
import type { TestFailure, FixResult, FixContext } from '../types.ts';
import { buildEnhancedFixPrompt } from '../context-builder.ts';
import { log } from '../logger.ts';

export class TimeoutFixStrategy extends BaseFixStrategy {
  readonly name = 'timeout-fix';
  readonly priority = 25;

  canHandle(failure: TestFailure): boolean {
    return failure.type === 'timeout-error';
  }

  async execute(failure: TestFailure, context: FixContext): Promise<FixResult> {
    this.logExecution(failure, 'Analyzing timeout failure');

    // Check diagnostics for clues
    const hasNetworkErrors = context.diagnostics.networkRequests.some(
      r => r.error || (r.status && r.status >= 400)
    );
    const hasConsoleErrors = context.diagnostics.consoleLogs.some(l => l.level === 'error');
    const failedIpcCalls = context.diagnostics.ipcCalls.filter(c => !c.success);

    // Build enhanced prompt
    const prompt = await buildEnhancedFixPrompt(failure);

    // Add timeout-specific analysis
    const enhancedPrompt = `${prompt}

## Timeout-Specific Analysis

This test is timing out. The timeout could be caused by:

${hasNetworkErrors ? '⚠️ **Network errors detected** - API calls are failing or slow' : ''}
${hasConsoleErrors ? '⚠️ **Console errors detected** - JavaScript errors might be blocking execution' : ''}
${failedIpcCalls.length > 0 ? `⚠️ **IPC failures detected** - ${failedIpcCalls.length} Tauri commands failed` : ''}

### Common Timeout Causes:

1. **Missing await**: Async operations not properly awaited
   - Look for Promise-returning functions without await
   - Check for fire-and-forget patterns

2. **Element not found**: Waiting for DOM element that never appears
   - Selector might be wrong
   - Element might not be rendered due to conditional logic
   - Component might have changed

3. **Network/API delays**: Slow or failing network requests
   - Add retry logic for transient failures
   - Increase timeout for slow endpoints
   - Mock external services in tests

4. **Infinite loop/recursion**: Code never terminates
   - Check loop conditions
   - Verify recursion base cases

5. **WebDriver connection**: Lost connection to Tauri app
   - Check if app crashed
   - Verify WebDriver session is active

6. **Race condition**: Timing-dependent behavior
   - Add explicit waits instead of relying on fixed delays
   - Use waitFor patterns

### Fix Approach:
1. First, determine WHY the timeout occurs (check diagnostics above)
2. If network/IPC related, add retry logic or increase timeouts
3. If element-related, verify selectors and add proper waits
4. If async-related, ensure all promises are properly awaited
5. Consider if test timeout configuration needs adjustment

Make the minimal fix needed. Consider both test and implementation fixes.
`;

    return await this.callClaudeForFix(enhancedPrompt, failure);
  }

  private async callClaudeForFix(prompt: string, failure: TestFailure): Promise<FixResult> {
    const { spawn } = await import('child_process');
    const fs = await import('fs');
    const path = await import('path');

    const outputDir = './ai-loop-logs';
    fs.mkdirSync(outputDir, { recursive: true });

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
        resolve(this.failure('Claude CLI timed out'));
      }, 300_000);

      child.on('close', async (code: number | null) => {
        clearTimeout(timer);

        if (!output.trim()) {
          resolve(this.failure('No output from Claude CLI'));
          return;
        }

        const filesModified = await this.applyFileBlocks(output);

        if (filesModified.length > 0) {
          resolve(this.success(filesModified, `Fixed timeout issue in ${filesModified.join(', ')}`));
        } else {
          resolve(this.failure('No file modifications found in output'));
        }
      });

      child.on('error', (err) => {
        clearTimeout(timer);
        resolve(this.failure(err.message));
      });
    });
  }

  private async applyFileBlocks(output: string): Promise<string[]> {
    const fs = await import('fs');
    const path = await import('path');

    const fileBlockRegex = /<file path="([^"]+)">([\s\S]*?)<\/file>/g;
    const filesModified: string[] = [];
    const cwd = process.cwd();
    let match;

    while ((match = fileBlockRegex.exec(output)) !== null) {
      const [, filePath, content] = match;

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
}
