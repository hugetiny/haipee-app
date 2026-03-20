/**
 * Regression Checker
 *
 * Verifies that a fix doesn't break previously passing tests.
 */

import { spawn } from 'child_process';
import type { TestFailure, ValidationResult, RegressionResult } from '../types.ts';
import { log } from '../logger.ts';

export interface RegressionChecker {
  checkRegressions(failure: TestFailure, modifiedFiles: string[]): Promise<ValidationResult>;
  runRelatedTests(testFilePath: string): Promise<RegressionResult[]>;
}

class RegressionCheckerImpl implements RegressionChecker {
  /**
   * Check for regressions after a fix
   */
  async checkRegressions(failure: TestFailure, modifiedFiles: string[]): Promise<ValidationResult> {
    log('info', `Checking for regressions after fix for: ${failure.testName}`);

    const issues: ValidationResult['issues'] = [];
    const regressionTests: RegressionResult[] = [];

    // Run the fixed test first
    const fixedTestResult = await this.runSingleTest(failure.filePath);
    regressionTests.push(fixedTestResult);

    if (!fixedTestResult.passed) {
      issues.push({
        severity: 'error',
        message: 'The fix did not resolve the original test failure',
        file: failure.filePath,
      });
    }

    // Run related tests
    const relatedResults = await this.runRelatedTests(failure.filePath);
    regressionTests.push(...relatedResults);

    const relatedTestsPassed = relatedResults.every(r => r.passed);
    if (!relatedTestsPassed) {
      const failedRelated = relatedResults.filter(r => !r.passed);
      for (const result of failedRelated) {
        issues.push({
          severity: 'error',
          message: `Related test now failing: ${result.testName}`,
        });
      }
    }

    // Check code quality
    const codeQualityScore = await this.checkCodeQuality(modifiedFiles);

    return {
      passed: fixedTestResult.passed && relatedTestsPassed,
      regressionTests,
      relatedTestsPassed,
      codeQualityScore,
      issues,
    };
  }

  /**
   * Run tests related to a file
   */
  async runRelatedTests(testFilePath: string): Promise<RegressionResult[]> {
    const results: RegressionResult[] = [];

    // Find test files in the same directory
    const fs = await import('fs');
    const path = await import('path');

    try {
      const dir = path.dirname(testFilePath);
      const files = fs.readdirSync(dir);

      for (const file of files) {
        const fullPath = path.join(dir, file);

        // Skip the original test file
        if (fullPath === testFilePath) continue;

        // Only run test files
        if (!file.includes('.test.') && !file.includes('.spec.')) continue;

        const result = await this.runSingleTest(fullPath);
        results.push(result);
      }
    } catch (error) {
      log('warn', 'Failed to find related tests', {
        error: error instanceof Error ? error.message : String(error),
      });
    }

    return results;
  }

  /**
   * Run a single test file
   */
  private async runSingleTest(testPath: string): Promise<RegressionResult> {
    const startTime = Date.now();

    return new Promise((resolve) => {
      const isE2E = testPath.includes('e2e');
      const cmd = isE2E ? 'bunx' : 'bun';
      const args = isE2E
        ? ['playwright', 'test', testPath, '--reporter=line']
        : ['vitest', 'run', testPath, '--reporter=verbose'];

      const child = spawn(cmd, args, {
        stdio: ['ignore', 'pipe', 'pipe'],
        cwd: process.cwd(),
        env: { ...process.env, CI: 'true' },
      });

      let output = '';

      child.stdout?.on('data', (data: Buffer) => { output += data.toString(); });
      child.stderr?.on('data', (data: Buffer) => { output += data.toString(); });

      const timer = setTimeout(() => {
        child.kill('SIGTERM');
        resolve({
          testName: testPath,
          passed: false,
          duration: Date.now() - startTime,
          error: 'Test timed out',
        });
      }, 60_000);

      child.on('close', (code) => {
        clearTimeout(timer);
        const duration = Date.now() - startTime;

        resolve({
          testName: testPath,
          passed: code === 0,
          duration,
          error: code !== 0 ? output.substring(0, 500) : undefined,
        });
      });

      child.on('error', (err) => {
        clearTimeout(timer);
        resolve({
          testName: testPath,
          passed: false,
          duration: Date.now() - startTime,
          error: err.message,
        });
      });
    });
  }

  /**
   * Check code quality of modified files
   */
  private async checkCodeQuality(modifiedFiles: string[]): Promise<number> {
    if (modifiedFiles.length === 0) return 1.0;

    let totalScore = 0;
    let fileCount = 0;

    for (const file of modifiedFiles) {
      if (!file.endsWith('.ts') && !file.endsWith('.tsx')) continue;

      const score = await this.checkFileQuality(file);
      totalScore += score;
      fileCount++;
    }

    return fileCount > 0 ? totalScore / fileCount : 1.0;
  }

  /**
   * Check quality of a single file
   */
  private async checkFileQuality(filePath: string): Promise<number> {
    const fs = await import('fs');

    try {
      if (!fs.existsSync(filePath)) return 0.5;

      const content = fs.readFileSync(filePath, 'utf-8');
      let score = 1.0;

      // Check for common issues
      if (content.includes('TODO')) score -= 0.1;
      if (content.includes('FIXME')) score -= 0.1;
      if (content.includes('console.log')) score -= 0.05;
      if (content.includes('any')) score -= 0.05;  // Type 'any' usage
      if (content.length > 5000) score -= 0.1;     // Large files
      if (content.split('\n').length > 300) score -= 0.1;  // Long files

      return Math.max(0, score);
    } catch {
      return 0.5;
    }
  }
}

// Singleton instance
let checkerInstance: RegressionChecker | null = null;

export function getRegressionChecker(): RegressionChecker {
  if (!checkerInstance) {
    checkerInstance = new RegressionCheckerImpl();
  }
  return checkerInstance;
}
