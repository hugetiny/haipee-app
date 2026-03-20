/**
 * IPC Fix Strategy
 *
 * Handles test failures caused by Tauri IPC command issues.
 */

import { BaseFixStrategy } from './strategy-base.ts';
import type { TestFailure, FixResult, FixContext } from '../types.ts';
import { buildEnhancedFixPrompt } from '../context-builder.ts';
import { log } from '../logger.ts';

export class IpcFixStrategy extends BaseFixStrategy {
  readonly name = 'ipc-fix';
  readonly priority = 15;  // Higher priority for IPC issues

  canHandle(failure: TestFailure): boolean {
    // Check if failure is related to Tauri IPC
    const errorLower = failure.errorMessage.toLowerCase();
    const stackLower = (failure.stackTrace || '').toLowerCase();

    return (
      failure.type === 'network-error' ||
      errorLower.includes('invoke') ||
      errorLower.includes('ipc') ||
      errorLower.includes('tauri') ||
      stackLower.includes('invoke') ||
      stackLower.includes('__tauri__')
    );
  }

  async execute(failure: TestFailure, context: FixContext): Promise<FixResult> {
    this.logExecution(failure, 'Analyzing IPC failure');

    // Analyze IPC trace for clues
    const failedIpcCalls = context.diagnostics.ipcCalls.filter(c => !c.success);
    const slowIpcCalls = context.diagnostics.ipcCalls.filter(c => c.duration > 5000);

    // Build enhanced prompt
    const prompt = await buildEnhancedFixPrompt(failure);

    // Add IPC-specific analysis
    const enhancedPrompt = `${prompt}

## IPC-Specific Analysis

This failure is related to Tauri IPC commands.

### Failed IPC Calls (${failedIpcCalls.length}):
${failedIpcCalls.slice(0, 5).map(call =>
  `- **${call.command}**: ${call.error || 'Unknown error'} (${call.duration}ms)`
).join('\n')}

### Slow IPC Calls (${slowIpcCalls.length}):
${slowIpcCalls.slice(0, 3).map(call =>
  `- **${call.command}**: ${call.duration}ms`
).join('\n')}

### Common IPC Issues:

1. **Command not registered**: The Tauri command isn't in invoke_handler
   - Check lib.rs for the command registration
   - Verify command name matches exactly

2. **Permission denied**: Missing capability in capabilities/
   - Check src-tauri/capabilities/ for required permissions
   - Add the command to the appropriate capability file

3. **Type mismatch**: Rust and TypeScript types don't align
   - Verify Rust command signature matches frontend expectations
   - Check serialization/deserialization

4. **Command panic**: Rust code panics during execution
   - Check src-tauri logs for panic messages
   - Look for unwrap() calls that might fail

5. **Timeout**: Command takes too long to execute
   - Check for blocking operations in async context
   - Look for database locks or file system issues

6. **Return value issues**: Command returns unexpected format
   - Verify Result type usage in Rust
   - Check error handling and propagation

### Fix Approach:
1. Identify which IPC command is failing from the trace above
2. Check the Rust implementation in src-tauri/src/commands/
3. Verify the command is properly registered in lib.rs
4. Check capabilities if permission-related
5. Look for panics or unwraps in the Rust code
6. Verify TypeScript type definitions match Rust types

Make the minimal fix needed. This could be in:
- Rust command implementation (src-tauri/src/commands/)
- Command registration (src-tauri/src/lib.rs)
- Capabilities (src-tauri/capabilities/)
- Frontend IPC call (src/)
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
          // If we modified Rust files, we should rebuild
          const rustFiles = filesModified.filter(f => f.endsWith('.rs'));
          if (rustFiles.length > 0) {
            log('info', 'Rust files modified - rebuild may be needed for next test run');
          }

          resolve(this.success(filesModified, `Fixed IPC issue in ${filesModified.join(', ')}`));
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
