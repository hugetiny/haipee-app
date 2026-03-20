/**
 * Code Quality Check
 *
 * Validates code quality after fixes are applied.
 */

import * as fs from 'fs';
import type { ValidationIssue } from '../types.ts';
import { log } from '../logger.ts';

export interface CodeQualityCheck {
  checkFile(filePath: string): ValidationIssue[];
  checkFiles(filePaths: string[]): ValidationIssue[];
  getQualityScore(issues: ValidationIssue[]): number;
}

class CodeQualityCheckImpl implements CodeQualityCheck {
  /**
   * Check a single file for quality issues
   */
  checkFile(filePath: string): ValidationIssue[] {
    const issues: ValidationIssue[] = [];

    try {
      if (!fs.existsSync(filePath)) {
        return issues;
      }

      const content = fs.readFileSync(filePath, 'utf-8');
      const lines = content.split('\n');

      // Check for common issues
      this.checkForTodos(content, lines, issues, filePath);
      this.checkForConsoleLogs(content, lines, issues, filePath);
      this.checkForAnyType(content, lines, issues, filePath);
      this.checkFileLength(lines, issues, filePath);
      this.checkLineLengths(lines, issues, filePath);
      this.checkForEmptyCatchBlocks(content, lines, issues, filePath);
      this.checkForUnusedImports(content, lines, issues, filePath);

    } catch (error) {
      issues.push({
        severity: 'warning',
        message: `Failed to check file: ${error instanceof Error ? error.message : String(error)}`,
        file: filePath,
      });
    }

    return issues;
  }

  /**
   * Check multiple files
   */
  checkFiles(filePaths: string[]): ValidationIssue[] {
    const allIssues: ValidationIssue[] = [];

    for (const filePath of filePaths) {
      const issues = this.checkFile(filePath);
      allIssues.push(...issues);
    }

    return allIssues;
  }

  /**
   * Calculate a quality score from issues
   */
  getQualityScore(issues: ValidationIssue[]): number {
    if (issues.length === 0) return 1.0;

    let penalty = 0;
    for (const issue of issues) {
      switch (issue.severity) {
        case 'error':
          penalty += 0.2;
          break;
        case 'warning':
          penalty += 0.05;
          break;
        case 'info':
          penalty += 0.01;
          break;
      }
    }

    return Math.max(0, 1 - penalty);
  }

  private checkForTodos(content: string, lines: string[], issues: ValidationIssue[], filePath: string): void {
    const todoRegex = /\/\/\s*TODO|\/\/\s*FIXME|\/\/\s*HACK/gi;
    let match;

    while ((match = todoRegex.exec(content)) !== null) {
      const lineNumber = content.substring(0, match.index).split('\n').length;
      issues.push({
        severity: 'info',
        message: `Found TODO/FIXME comment`,
        file: filePath,
        line: lineNumber,
      });
    }
  }

  private checkForConsoleLogs(content: string, lines: string[], issues: ValidationIssue[], filePath: string): void {
    const consoleRegex = /console\.(log|warn|error|debug)\(/g;
    let match;

    while ((match = consoleRegex.exec(content)) !== null) {
      const lineNumber = content.substring(0, match.index).split('\n').length;
      issues.push({
        severity: 'warning',
        message: `Console statement found (consider removing for production)`,
        file: filePath,
        line: lineNumber,
      });
    }
  }

  private checkForAnyType(content: string, lines: string[], issues: ValidationIssue[], filePath: string): void {
    const anyRegex = /:\s*any\b|as\s+any\b/g;
    let match;

    while ((match = anyRegex.exec(content)) !== null) {
      const lineNumber = content.substring(0, match.index).split('\n').length;
      issues.push({
        severity: 'warning',
        message: `Type 'any' found (consider using a more specific type)`,
        file: filePath,
        line: lineNumber,
      });
    }
  }

  private checkFileLength(lines: string[], issues: ValidationIssue[], filePath: string): void {
    if (lines.length > 500) {
      issues.push({
        severity: 'warning',
        message: `File is very long (${lines.length} lines, consider splitting)`,
        file: filePath,
      });
    }
  }

  private checkLineLengths(lines: string[], issues: ValidationIssue[], filePath: string): void {
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].length > 120) {
        issues.push({
          severity: 'info',
          message: `Line exceeds 120 characters (${lines[i].length})`,
          file: filePath,
          line: i + 1,
        });
        // Only report first few long lines
        if (issues.filter(issue => issue.message.includes('Line exceeds')).length >= 3) {
          break;
        }
      }
    }
  }

  private checkForEmptyCatchBlocks(content: string, lines: string[], issues: ValidationIssue[], filePath: string): void {
    const emptyCatchRegex = /catch\s*\([^)]*\)\s*\{\s*\}/g;
    let match;

    while ((match = emptyCatchRegex.exec(content)) !== null) {
      const lineNumber = content.substring(0, match.index).split('\n').length;
      issues.push({
        severity: 'warning',
        message: `Empty catch block found (errors are being silently ignored)`,
        file: filePath,
        line: lineNumber,
      });
    }
  }

  private checkForUnusedImports(content: string, lines: string[], issues: ValidationIssue[], filePath: string): void {
    // Simple heuristic: check if imported names are used in the file
    const importRegex = /import\s+{([^}]+)}\s+from/g;
    let match;

    while ((match = importRegex.exec(content)) !== null) {
      const imports = match[1].split(',').map(i => i.trim().split(' as ')[0].trim());

      for (const importedName of imports) {
        if (!importedName) continue;

        // Count occurrences (excluding the import line itself)
        const usageCount = (content.match(new RegExp(`\\b${importedName}\\b`, 'g')) || []).length;
        if (usageCount <= 1) {
          const lineNumber = content.substring(0, match.index).split('\n').length;
          issues.push({
            severity: 'info',
            message: `Potentially unused import: ${importedName}`,
            file: filePath,
            line: lineNumber,
          });
        }
      }
    }
  }
}

// Singleton instance
let checkInstance: CodeQualityCheck | null = null;

export function getCodeQualityCheck(): CodeQualityCheck {
  if (!checkInstance) {
    checkInstance = new CodeQualityCheckImpl();
  }
  return checkInstance;
}

/**
 * Quick quality check for modified files
 */
export function checkModifiedFiles(filePaths: string[]): { score: number; issues: ValidationIssue[] } {
  const checker = getCodeQualityCheck();
  const issues = checker.checkFiles(filePaths);
  const score = checker.getQualityScore(issues);

  return { score, issues };
}
