/**
 * Validation Module Index
 *
 * Central export point for all validation modules.
 */

export { getRegressionChecker, type RegressionChecker } from './regression-checker.ts';
export { getCodeQualityCheck, checkModifiedFiles, type CodeQualityCheck } from './code-quality-check.ts';

import type { TestFailure, ValidationResult } from '../types.ts';
import { getRegressionChecker } from './regression-checker.ts';
import { checkModifiedFiles } from './code-quality-check.ts';
import { log } from '../logger.ts';

/**
 * Run full validation after a fix
 */
export async function validateFix(
  failure: TestFailure,
  modifiedFiles: string[]
): Promise<ValidationResult> {
  log('info', `Validating fix for: ${failure.testName}`);

  const checker = getRegressionChecker();

  // Check for regressions
  const regressionResult = await checker.checkRegressions(failure, modifiedFiles);

  // Check code quality
  const qualityResult = checkModifiedFiles(modifiedFiles);

  // Combine issues
  const allIssues = [
    ...regressionResult.issues,
    ...qualityResult.issues.map(issue => ({
      ...issue,
      severity: issue.severity as 'error' | 'warning' | 'info',
    })),
  ];

  return {
    passed: regressionResult.passed && qualityResult.score >= 0.7,
    regressionTests: regressionResult.regressionTests,
    relatedTestsPassed: regressionResult.relatedTestsPassed,
    codeQualityScore: qualityResult.score,
    issues: allIssues,
  };
}

/**
 * Format validation result for logging
 */
export function formatValidationResult(result: ValidationResult): string {
  let output = '';

  output += `Validation ${result.passed ? 'PASSED' : 'FAILED'}\n`;
  output += `- Code Quality Score: ${(result.codeQualityScore * 100).toFixed(0)}%\n`;
  output += `- Related Tests: ${result.relatedTestsPassed ? 'PASS' : 'FAIL'}\n`;
  output += `- Regressions: ${result.regressionTests.filter(r => !r.passed).length} failed\n`;

  if (result.issues.length > 0) {
    output += '\nIssues:\n';
    for (const issue of result.issues.slice(0, 10)) {
      output += `  [${issue.severity.toUpperCase()}] ${issue.message}`;
      if (issue.file) output += ` (${issue.file}${issue.line ? `:${issue.line}` : ''})`;
      output += '\n';
    }
    if (result.issues.length > 10) {
      output += `  ... and ${result.issues.length - 10} more issues\n`;
    }
  }

  return output;
}
