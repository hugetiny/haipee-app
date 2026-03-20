/**
 * Pattern Matcher
 *
 * Matches test failures to known fix patterns.
 */

import type { TestFailure, FixPattern } from '../types.ts';
import { getPatternDB } from './pattern-db.ts';
import { log } from '../logger.ts';

export interface PatternMatcher {
  findBestMatch(failure: TestFailure): FixPattern | null;
  findMatches(failure: TestFailure, minConfidence?: number): FixPattern[];
  learnFromSuccess(failure: TestFailure, filesModified: string[], solution: string): void;
  learnFromFailure(failure: TestFailure, patternId: string): void;
}

class PatternMatcherImpl implements PatternMatcher {
  /**
   * Find the best matching pattern for a failure
   */
  findBestMatch(failure: TestFailure): FixPattern | null {
    const db = getPatternDB();
    const matches = db.findMatchingPatterns(failure.errorMessage, failure.type);

    if (matches.length === 0) {
      return null;
    }

    // Return the highest confidence match
    const best = matches[0];
    log('info', `Found matching pattern: ${best.name} (confidence: ${(best.confidence * 100).toFixed(0)}%)`);

    return best;
  }

  /**
   * Find all matches above a confidence threshold
   */
  findMatches(failure: TestFailure, minConfidence: number = 0.3): FixPattern[] {
    const db = getPatternDB();
    const matches = db.findMatchingPatterns(failure.errorMessage, failure.type);

    return matches.filter(m => m.confidence >= minConfidence);
  }

  /**
   * Learn from a successful fix
   */
  learnFromSuccess(failure: TestFailure, filesModified: string[], solution: string): void {
    const db = getPatternDB();

    // Check if a similar pattern already exists
    const existingMatches = db.findMatchingPatterns(failure.errorMessage, failure.type);

    if (existingMatches.length > 0) {
      // Update existing pattern
      const pattern = existingMatches[0];
      db.updatePatternStats(pattern.id, true);
      log('info', `Updated existing pattern: ${pattern.name}`);
    } else {
      // Create new pattern
      const { createPatternFromFix } = require('./pattern-db.ts');
      const pattern = createPatternFromFix(failure, filesModified, solution);
      db.savePattern(pattern);
      log('info', `Learned new pattern: ${pattern.name}`);
    }
  }

  /**
   * Learn from a failed fix attempt
   */
  learnFromFailure(failure: TestFailure, patternId: string): void {
    const db = getPatternDB();
    db.updatePatternStats(patternId, false);
    log('debug', `Updated pattern stats (failure): ${patternId}`);
  }
}

// Singleton instance
let matcherInstance: PatternMatcher | null = null;

export function getPatternMatcher(): PatternMatcher {
  if (!matcherInstance) {
    matcherInstance = new PatternMatcherImpl();
  }
  return matcherInstance;
}

/**
 * Check if a pattern-based fix should be attempted
 */
export function shouldTryPatternFix(failure: TestFailure): boolean {
  // Don't try pattern fix for first attempt - let AI reason through it
  if (failure.fixAttempts === 0) {
    return false;
  }

  // On subsequent attempts, check if we have a pattern
  const matcher = getPatternMatcher();
  const match = matcher.findBestMatch(failure);

  if (!match) {
    return false;
  }

  // Only use pattern if confidence is high enough
  if (match.confidence < 0.5) {
    return false;
  }

  // Check if pattern has enough history
  const totalAttempts = match.successCount + match.failureCount;
  if (totalAttempts < 3) {
    return false;
  }

  log('info', `Will try pattern-based fix: ${match.name} (confidence: ${(match.confidence * 100).toFixed(0)}%)`);
  return true;
}

/**
 * Apply a pattern-based fix
 */
export async function applyPatternFix(
  failure: TestFailure,
  pattern: FixPattern
): Promise<boolean> {
  const fs = await import('fs');
  const path = await import('path');
  const { execSync } = await import('child_process');

  log('info', `Applying pattern fix: ${pattern.name}`);

  try {
    // For each file in the pattern, try to apply the fix
    for (const file of pattern.filesModified) {
      if (!fs.existsSync(file)) {
        log('warn', `Pattern file not found: ${file}`);
        continue;
      }

      // Read current file content
      const currentContent = fs.readFileSync(file, 'utf-8');

      // The pattern's solution contains the fix description
      // We would need to store the actual fix content in the pattern
      // For now, log that we would apply it
      log('info', `Would apply fix to: ${file}`);
    }

    return true;
  } catch (error) {
    log('error', 'Failed to apply pattern fix', {
      error: error instanceof Error ? error.message : String(error),
    });
    return false;
  }
}
