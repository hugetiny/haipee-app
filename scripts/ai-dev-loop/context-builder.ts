/**
 * Context Builder Module
 *
 * Builds rich fix context for AI agents by combining diagnostics,
 * history, and codebase information.
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';
import type {
  TestFailure,
  FixContext,
  DiagnosticData,
  FixAttempt,
  FixPattern,
  GitDiff,
} from './types.ts';
import { collectDiagnostics, formatDiagnosticsForPrompt } from './diagnostics/index.ts';
import { log } from './logger.ts';

export interface ContextBuilder {
  buildFixContext(failure: TestFailure, options?: ContextBuildOptions): Promise<FixContext>;
  formatContextForPrompt(context: FixContext): string;
  getRelatedFiles(filePath: string): string[];
  getRecentGitChanges(since?: string): GitDiff[];
  findSimilarFailures(failure: TestFailure, history: FixAttempt[]): FixAttempt[];
}

export interface ContextBuildOptions {
  includeDiagnostics?: boolean;
  includeHistory?: boolean;
  includeGitChanges?: boolean;
  maxRelatedFiles?: number;
  maxGitChanges?: number;
  diagnosticOptions?: {
    captureScreenshot?: boolean;
    captureConsole?: boolean;
    captureNetwork?: boolean;
    captureIpc?: boolean;
  };
}

const DEFAULT_OPTIONS: ContextBuildOptions = {
  includeDiagnostics: true,
  includeHistory: true,
  includeGitChanges: true,
  maxRelatedFiles: 5,
  maxGitChanges: 10,
  diagnosticOptions: {
    captureScreenshot: true,
    captureConsole: true,
    captureNetwork: true,
    captureIpc: true,
  },
};

class ContextBuilderImpl implements ContextBuilder {
  /**
   * Build a complete fix context for a test failure
   */
  async buildFixContext(
    failure: TestFailure,
    options: ContextBuildOptions = {}
  ): Promise<FixContext> {
    const opts = { ...DEFAULT_OPTIONS, ...options };
    log('info', `Building fix context for: ${failure.testName}`);

    // Collect diagnostics
    let diagnostics: DiagnosticData = {
      screenshots: [],
      consoleLogs: [],
      networkRequests: [],
      ipcCalls: [],
      collectedAt: Date.now(),
    };

    if (opts.includeDiagnostics) {
      try {
        diagnostics = await collectDiagnostics(failure.testName, opts.diagnosticOptions);
      } catch (error) {
        log('warn', 'Failed to collect diagnostics', {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    // Get related files
    const relatedFiles = this.getRelatedFiles(failure.filePath);

    // Get recent git changes
    let recentChanges: GitDiff[] = [];
    if (opts.includeGitChanges) {
      recentChanges = this.getRecentGitChanges('HEAD~10');
      if (opts.maxGitChanges) {
        recentChanges = recentChanges.slice(0, opts.maxGitChanges);
      }
    }

    // Get related tests
    const relatedTests = this.findRelatedTests(failure.filePath);

    // Build history context
    const history = {
      previousFixAttempts: failure.fixHistory || [],
      similarFailures: [],
      successfulFixPatterns: this.getSuccessfulPatterns(failure.type),
    };

    const context: FixContext = {
      failure,
      diagnostics,
      history,
      codebase: {
        testFile: failure.filePath,
        sourceFiles: failure.context?.sourceFiles || [],
        recentChanges,
        relatedTests,
      },
    };

    return context;
  }

  /**
   * Format a fix context into a prompt-friendly string
   */
  formatContextForPrompt(context: FixContext): string {
    let output = '';

    // Failure information
    output += '## Failure Information\n';
    output += `- **Test**: ${context.failure.testName}\n`;
    output += `- **File**: ${context.failure.filePath}\n`;
    output += `- **Error Type**: ${context.failure.type}\n`;
    output += `- **Fix Attempts**: ${context.failure.fixAttempts}\n`;
    output += `- **Error**: ${context.failure.errorMessage}\n`;

    if (context.failure.stackTrace) {
      output += '\n### Stack Trace\n```\n';
      output += context.failure.stackTrace.substring(0, 1000);
      output += '\n```\n';
    }
    output += '\n';

    // Diagnostic data
    if (this.hasDiagnostics(context.diagnostics)) {
      output += '## Diagnostic Data\n';
      output += formatDiagnosticsForPrompt(context.diagnostics);
      output += '\n';
    }

    // Codebase context
    output += '## Codebase Context\n';

    // Test file
    const testContent = this.readFileContent(context.failure.filePath);
    if (testContent) {
      output += `### Test File: ${context.failure.filePath}\n`;
      output += '```typescript\n';
      output += testContent.substring(0, 2000);
      output += '\n```\n\n';
    }

    // Source files
    if (context.codebase.sourceFiles.length > 0) {
      output += '### Related Source Files\n';
      for (const file of context.codebase.sourceFiles.slice(0, 3)) {
        const content = this.readFileContent(file);
        if (content) {
          output += `#### ${file}\n`;
          output += '```typescript\n';
          output += content.substring(0, 1500);
          output += '\n```\n\n';
        }
      }
    }

    // Recent git changes
    if (context.codebase.recentChanges.length > 0) {
      output += '### Recent Git Changes\n';
      for (const change of context.codebase.recentChanges.slice(0, 5)) {
        output += `#### ${change.filePath} (+${change.additions}/-${change.deletions})\n`;
        output += '```diff\n';
        output += change.patch.substring(0, 500);
        output += '\n```\n\n';
      }
    }

    // History context
    if (context.history.previousFixAttempts.length > 0) {
      output += '## Previous Fix Attempts\n';
      for (const attempt of context.history.previousFixAttempts.slice(0, 3)) {
        output += `- **Strategy**: ${attempt.strategy}\n`;
        output += `- **Result**: ${attempt.success ? 'Success' : 'Failed'}\n`;
        if (attempt.error) {
          output += `- **Error**: ${attempt.error}\n`;
        }
        output += '\n';
      }
    }

    if (context.history.successfulFixPatterns.length > 0) {
      output += '## Successful Fix Patterns\n';
      for (const pattern of context.history.successfulFixPatterns.slice(0, 3)) {
        output += `- **${pattern.name}**: ${pattern.solution}\n`;
        output += `  Success rate: ${pattern.successCount}/${pattern.successCount + pattern.failureCount}\n`;
        output += '\n';
      }
    }

    // Related tests
    if (context.codebase.relatedTests.length > 0) {
      output += '## Related Tests\n';
      for (const test of context.codebase.relatedTests.slice(0, 5)) {
        output += `- ${test}\n`;
      }
      output += '\n';
    }

    return output;
  }

  /**
   * Get related files for a test file
   */
  getRelatedFiles(filePath: string): string[] {
    const relatedFiles: string[] = [];

    if (!fs.existsSync(filePath)) {
      return relatedFiles;
    }

    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const importRegex = /import\s+.*?\s+from\s+['"](.+?)['"];?/g;
      let match;

      while ((match = importRegex.exec(content)) !== null) {
        const importPath = match[1];
        if (importPath.startsWith('.') || importPath.startsWith('/')) {
          const resolvedBase = path.resolve(path.dirname(filePath), importPath);
          const extensions = ['', '.ts', '.tsx', '.js', '.jsx'];
          for (const ext of extensions) {
            const resolved = resolvedBase + ext;
            if (fs.existsSync(resolved) && !resolved.includes('.test.') && !resolved.includes('.spec.')) {
              relatedFiles.push(resolved);
              break;
            }
          }
        }
      }
    } catch (error) {
      // Ignore read errors
    }

    // Also check for files in the same directory
    try {
      const dir = path.dirname(filePath);
      const files = fs.readdirSync(dir);
      for (const file of files) {
        const fullPath = path.join(dir, file);
        if (
          file.endsWith('.ts') ||
          file.endsWith('.tsx') ||
          file.endsWith('.js') ||
          file.endsWith('.jsx')
        ) {
          if (fullPath !== filePath && !file.includes('.test.') && !file.includes('.spec.')) {
            relatedFiles.push(fullPath);
          }
        }
      }
    } catch (error) {
      // Ignore read errors
    }

    return [...new Set(relatedFiles)].slice(0, 10);
  }

  /**
   * Get recent git changes
   */
  getRecentGitChanges(since: string = 'HEAD~10'): GitDiff[] {
    const changes: GitDiff[] = [];

    try {
      // Get list of changed files
      const diffStat = execSync(`git diff --stat ${since}..HEAD`, {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'ignore'],
      });

      // Parse file stats
      const fileLines = diffStat.split('\n').filter(line => line.includes('|'));
      for (const line of fileLines) {
        const match = line.match(/^(.+?)\s+\|\s+(\d+)\s+([+\-]*)/);
        if (match) {
          const filePath = match[1].trim();
          const changesStr = match[3] || '';
          const additions = (changesStr.match(/\+/g) || []).length;
          const deletions = (changesStr.match(/-/g) || []).length;

          // Get the actual diff for this file
          try {
            const patch = execSync(`git diff ${since}..HEAD -- "${filePath}"`, {
              encoding: 'utf-8',
              stdio: ['pipe', 'pipe', 'ignore'],
            }).substring(0, 2000);  // Limit patch size

            changes.push({
              filePath,
              additions,
              deletions,
              patch,
            });
          } catch {
            // Ignore errors getting individual file diff
          }
        }
      }
    } catch (error) {
      log('debug', 'Failed to get git changes', {
        error: error instanceof Error ? error.message : String(error),
      });
    }

    return changes;
  }

  /**
   * Find tests related to a file
   */
  private findRelatedTests(filePath: string): string[] {
    const relatedTests: string[] = [];

    // Extract the module/component name from the file path
    const baseName = path.basename(filePath, path.extname(filePath));
    const dirName = path.dirname(filePath);

    // Look for test files that might test this module
    const testPatterns = [
      `${baseName}.test.ts`,
      `${baseName}.test.tsx`,
      `${baseName}.spec.ts`,
      `${baseName}.spec.tsx`,
    ];

    // Check tests directory
    const testsDir = path.join(process.cwd(), 'tests');
    if (fs.existsSync(testsDir)) {
      this.searchForTestFiles(testsDir, baseName, relatedTests);
    }

    // Check same directory
    for (const pattern of testPatterns) {
      const testPath = path.join(dirName, pattern);
      if (fs.existsSync(testPath)) {
        relatedTests.push(testPath);
      }
    }

    return [...new Set(relatedTests)].slice(0, 5);
  }

  /**
   * Recursively search for test files
   */
  private searchForTestFiles(dir: string, baseName: string, results: string[]): void {
    try {
      const entries = fs.readdirSync(dir, { withFileTypes: true });

      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);

        if (entry.isDirectory() && !entry.name.startsWith('.') && entry.name !== 'node_modules') {
          this.searchForTestFiles(fullPath, baseName, results);
        } else if (entry.isFile() && (entry.name.includes('.test.') || entry.name.includes('.spec.'))) {
          // Check if this test file references the base name
          try {
            const content = fs.readFileSync(fullPath, 'utf-8');
            if (content.includes(baseName)) {
              results.push(fullPath);
            }
          } catch {
            // Ignore read errors
          }
        }
      }
    } catch {
      // Ignore directory read errors
    }
  }

  /**
   * Get successful fix patterns for a failure type
   */
  private getSuccessfulPatterns(failureType: string): FixPattern[] {
    // Load patterns from the fix-patterns directory
    const patternsDir = path.join(process.cwd(), 'scripts/ai-dev-loop/fix-patterns/patterns');
    const patterns: FixPattern[] = [];

    if (!fs.existsSync(patternsDir)) {
      return patterns;
    }

    try {
      const files = fs.readdirSync(patternsDir);
      for (const file of files) {
        if (file.endsWith('.json')) {
          try {
            const content = fs.readFileSync(path.join(patternsDir, file), 'utf-8');
            const pattern: FixPattern = JSON.parse(content);
            if (pattern.failureType === failureType || pattern.failureType === 'unknown') {
              patterns.push(pattern);
            }
          } catch {
            // Ignore parse errors
          }
        }
      }
    } catch {
      // Ignore directory read errors
    }

    // Sort by confidence
    return patterns.sort((a, b) => b.confidence - a.confidence);
  }

  /**
   * Find similar failures in history
   */
  findSimilarFailures(failure: TestFailure, history: FixAttempt[]): FixAttempt[] {
    return history
      .filter(attempt => {
        // Same file
        if (attempt.failureId.includes(path.basename(failure.filePath))) {
          return true;
        }
        // Similar error message
        if (failure.errorMessage && attempt.error) {
          const failureWords = failure.errorMessage.toLowerCase().split(/\s+/);
          const attemptWords = attempt.error.toLowerCase().split(/\s+/);
          const commonWords = failureWords.filter(w => attemptWords.includes(w));
          return commonWords.length >= 3;
        }
        return false;
      })
      .sort((a, b) => b.timestamp - a.timestamp);
  }

  /**
   * Check if diagnostics have any data
   */
  private hasDiagnostics(diagnostics: DiagnosticData): boolean {
    return (
      diagnostics.screenshots.length > 0 ||
      diagnostics.consoleLogs.length > 0 ||
      diagnostics.networkRequests.length > 0 ||
      diagnostics.ipcCalls.length > 0 ||
      diagnostics.appState !== undefined
    );
  }

  /**
   * Read file content safely
   */
  private readFileContent(filePath: string): string | null {
    try {
      if (fs.existsSync(filePath)) {
        return fs.readFileSync(filePath, 'utf-8');
      }
    } catch {
      // Ignore read errors
    }
    return null;
  }
}

// Singleton instance
let builderInstance: ContextBuilder | null = null;

export function getContextBuilder(): ContextBuilder {
  if (!builderInstance) {
    builderInstance = new ContextBuilderImpl();
  }
  return builderInstance;
}

/**
 * Build an enhanced fix prompt with full context
 */
export async function buildEnhancedFixPrompt(
  failure: TestFailure,
  options?: ContextBuildOptions
): Promise<string> {
  const builder = getContextBuilder();
  const context = await builder.buildFixContext(failure, options);

  let prompt = `You are a test failure fix expert. Analyze the following test failure and provide a minimal, targeted fix.\n\n`;
  prompt += builder.formatContextForPrompt(context);
  prompt += `\n## Fix Requirements\n`;
  prompt += `1. Analyze the root cause of the failure (don't just fix surface symptoms)\n`;
  prompt += `2. If screenshots are provided, consider the visual state of the UI\n`;
  prompt += `3. Check for IPC or network errors that might indicate backend issues\n`;
  prompt += `4. Make minimal changes - fix only what's broken\n`;
  prompt += `5. Ensure the fix follows existing code patterns\n`;
  prompt += `6. Consider if previous fix attempts suggest a different approach\n`;
  prompt += `7. After fixing, verify the change won't break related tests\n`;
  prompt += `\n## Output Format\n`;
  prompt += `For each file you modify, output a complete file block:\n`;
  prompt += `<file path="relative/path/to/file.ts">\n`;
  prompt += `// complete updated file content here\n`;
  prompt += `</file>\n`;

  return prompt;
}
