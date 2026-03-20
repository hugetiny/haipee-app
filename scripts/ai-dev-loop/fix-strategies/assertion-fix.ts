/**
 * Assertion Fix Strategy
 *
 * Handles test failures where assertions don't match expected values.
 */

import { BaseFixStrategy } from './strategy-base.ts';
import type { TestFailure, FixResult, FixContext } from '../types.ts';
import { buildEnhancedFixPrompt } from '../context-builder.ts';
import { log } from '../logger.ts';

export class AssertionFixStrategy extends BaseFixStrategy {
  readonly name = 'assertion-fix';
  readonly priority = 20;

  canHandle(failure: TestFailure): boolean {
    return failure.type === 'assertion-failure';
  }

  async execute(failure: TestFailure, context: FixContext): Promise<FixResult> {
    this.logExecution(failure, 'Analyzing assertion failure');

    // Build enhanced prompt with full context
    const prompt = await buildEnhancedFixPrompt(failure);

    // Add assertion-specific instructions
    const enhancedPrompt = `${prompt}

## Assertion-Specific Analysis

This is an assertion failure. Common causes:
1. **Implementation bug**: The code under test produces wrong output
2. **Test expectation wrong**: The test expects incorrect behavior
3. **Timing issue**: Async operation hasn't completed when assertion runs
4. **State contamination**: Previous test left unexpected state
5. **Data mismatch**: Test data doesn't match current implementation

### For Expected/Received mismatches:
- If Expected and Received are different values, check if the implementation is correct
- If the difference is minor (e.g., formatting, whitespace), consider if test is too strict
- If the difference is significant, the implementation likely needs fixing

### For boolean assertions (expect(...).toBe(true)):
- Trace through the logic to understand why the condition fails
- Check for null/undefined values that might cause false negatives
- Verify async operations are properly awaited

### For array/object assertions:
- Check for missing or extra properties
- Verify order is correct if using toEqual (not toMatchObject)
- Consider if test data has changed

Make the minimal fix needed. If the test expectation is wrong, update the test.
If the implementation is wrong, fix the implementation.
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
          resolve(this.success(filesModified, `Fixed assertion in ${filesModified.join(', ')}`));
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
