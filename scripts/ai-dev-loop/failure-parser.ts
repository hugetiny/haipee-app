/**
 * AI Development Loop - Failure Parser
 */

import * as fs from 'fs';
import type { TestFailure, FailureType, FailureContext } from './types.ts';
import { log } from './logger.ts';

export function parseVitestFailures(output: string): TestFailure[] {
  const failures: TestFailure[] = [];
  const lines = output.split('\n');

  // Parse Vitest failure format
  let currentFile: string | null = null;
  let currentTest: string | null = null;
  let errorBuffer: string[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Match FAIL line
    const failMatch = line.match(/FAIL\s+(.+?)(?:\s+\[|$)/);
    if (failMatch) {
      currentFile = failMatch[1].trim();
      continue;
    }

    // Match test name (❯ symbol)
    const testMatch = line.match(/❯\s+(.+?)(?:\s+\d+ms)?$/);
    if (testMatch && currentFile) {
      // Save previous failure if exists
      if (currentTest && errorBuffer.length > 0) {
        failures.push(createFailure(currentFile, currentTest, errorBuffer.join('\n')));
      }
      currentTest = testMatch[1].trim();
      errorBuffer = [];
      continue;
    }

    // Collect error details
    if (currentTest && line.trim() && !line.includes('⎯')) {
      errorBuffer.push(line);
    }
  }

  // Don't forget the last failure
  if (currentFile && currentTest && errorBuffer.length > 0) {
    failures.push(createFailure(currentFile, currentTest, errorBuffer.join('\n')));
  }

  return failures;
}

export function parsePlaywrightFailures(output: string): TestFailure[] {
  const failures: TestFailure[] = [];

  // Playwright failure pattern
  const errorBlocks = output.split(/\[.+?\]\s+.+?\s+→/);

  for (const block of errorBlocks.slice(1)) {
    const lines = block.split('\n');
    const firstLine = lines[0] || '';

    // Extract file and test name
    const parts = firstLine.split('→').map((p) => p.trim());
    if (parts.length >= 2) {
      const testFile = parts[0];
      const testName = parts.slice(1).join(' > ');
      const errorDetails = lines.slice(1).join('\n');

      failures.push(createFailure(testFile, testName, errorDetails));
    }
  }

  return failures;
}

function createFailure(filePath: string, testName: string, errorSection: string): TestFailure {
  const type = classifyErrorType(errorSection);
  const errorMessage = extractErrorMessage(errorSection, type);

  return {
    id: generateFailureId(filePath, testName),
    testName: testName.substring(0, 200),
    filePath: filePath.trim(),
    errorMessage: errorMessage.substring(0, 500),
    stackTrace: errorSection.substring(0, 2000),
    type,
    fixAttempts: 0,
    status: 'pending',
    firstSeen: Date.now(),
    context: buildFailureContext(filePath),
  };
}

function classifyErrorType(errorSection: string): FailureType {
  if (errorSection.includes('Timeout') || errorSection.includes('timed out')) return 'timeout-error';
  if (errorSection.includes('TypeError')) return 'type-error';
  if (errorSection.includes('ReferenceError') || errorSection.includes('is not defined')) return 'runtime-error';
  if (errorSection.includes('Cannot find module') || errorSection.includes('import')) return 'import-error';
  if (errorSection.includes('expect(') || errorSection.includes('Expected:') || errorSection.includes('AssertionError')) return 'assertion-failure';
  if (errorSection.includes('Error:') || errorSection.includes('throw')) return 'runtime-error';
  if (errorSection.includes('WebDriver') || errorSection.includes('ECONNREFUSED')) return 'network-error';
  return 'unknown';
}

function extractErrorMessage(errorSection: string, type: FailureType): string {
  const expectMatch = errorSection.match(/Expected:\s*(.+?)\n\s*Received:\s*(.+?)(?:\n|$)/);
  if (expectMatch) return `Expected: ${expectMatch[1].trim()}, Received: ${expectMatch[2].trim()}`;

  const errorMatch = errorSection.match(/(?:Error|AssertionError):\s*(.+?)(?:\n|$)/);
  if (errorMatch) return errorMatch[1].trim();

  const lines = errorSection.trim().split('\n').filter((l) => l.trim());
  return lines[0]?.substring(0, 200) || 'Unknown error';
}

function buildFailureContext(testFile: string): FailureContext {
  const relatedFiles: string[] = [];

  if (fs.existsSync(testFile)) {
    const content = fs.readFileSync(testFile, 'utf-8');
    const importRegex = /import\s+.*?\s+from\s+['"](.+?)['"];?/g;
    let match;

    while ((match = importRegex.exec(content)) !== null) {
      const importPath = match[1];
      if (importPath.startsWith('.') || importPath.startsWith('/')) {
        const resolvedPath = require('path').resolve(require('path').dirname(testFile), importPath);
        const extensions = ['', '.ts', '.tsx', '.js', '.jsx'];
        for (const ext of extensions) {
          if (fs.existsSync(resolvedPath + ext)) {
            relatedFiles.push(resolvedPath + ext);
            break;
          }
        }
      }
    }
  }

  return { sourceFiles: [], testFile, relatedFiles: [...new Set(relatedFiles)].slice(0, 5) };
}

function generateFailureId(filePath: string, testName: string): string {
  const hash = require('crypto').createHash('md5').update(`${filePath}:${testName}`).digest('hex').substring(0, 8);
  return `fail-${hash}`;
}

export function detectFlakyTests(failures: TestFailure[], history: TestFailure[]): TestFailure[] {
  return failures.map((failure) => {
    const previousRuns = history.filter((h) => h.id === failure.id && h.status !== 'pending');
    if (previousRuns.length >= 3) {
      const passCount = previousRuns.filter((h) => h.status === 'fixed').length;
      const passRate = passCount / previousRuns.length;
      if (passRate > 0.2 && passRate < 0.8) {
        log('warn', `Detected potentially flaky test: ${failure.testName}`, { passRate: `${(passRate * 100).toFixed(0)}%` });
        return { ...failure, type: 'flaky' };
      }
    }
    return failure;
  });
}
