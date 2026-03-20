/**
 * Fix Patterns Module Index
 *
 * Central export point for fix pattern database and matching.
 */

export { getPatternDB, createPatternFromFix, type PatternDB } from './pattern-db.ts';
export { getPatternMatcher, shouldTryPatternFix, applyPatternFix, type PatternMatcher } from './pattern-matcher.ts';

import type { TestFailure, FixAttempt, FixPattern } from '../types.ts';
import { getPatternDB, createPatternFromFix } from './pattern-db.ts';
import { getPatternMatcher } from './pattern-matcher.ts';
import { log } from '../logger.ts';

/**
 * Record a successful fix and learn from it
 */
export function recordSuccessfulFix(
  failure: TestFailure,
  filesModified: string[],
  solution: string
): void {
  const matcher = getPatternMatcher();
  matcher.learnFromSuccess(failure, filesModified, solution);
  log('info', `Recorded successful fix pattern for: ${failure.testName}`);
}

/**
 * Record a failed fix attempt
 */
export function recordFailedFix(failure: TestFailure, patternId: string): void {
  const matcher = getPatternMatcher();
  matcher.learnFromFailure(failure, patternId);
  log('debug', `Recorded failed fix attempt for: ${failure.testName}`);
}

/**
 * Get all learned patterns
 */
export function getAllPatterns(): FixPattern[] {
  const db = getPatternDB();
  return db.getPatterns();
}

/**
 * Get patterns for a specific failure type
 */
export function getPatternsForType(failureType: string): FixPattern[] {
  const db = getPatternDB();
  return db.getPatterns(failureType as any);
}

/**
 * Clean up old patterns
 */
export function cleanupPatterns(maxAgeDays: number = 90): void {
  const db = getPatternDB();
  db.cleanup(maxAgeDays * 24 * 60 * 60 * 1000);
}

/**
 * Get pattern statistics
 */
export function getPatternStats(): {
  totalPatterns: number;
  byType: Record<string, number>;
  avgConfidence: number;
  totalSuccesses: number;
  totalFailures: number;
} {
  const db = getPatternDB();
  const patterns = db.getPatterns();

  const byType: Record<string, number> = {};
  let totalConfidence = 0;
  let totalSuccesses = 0;
  let totalFailures = 0;

  for (const pattern of patterns) {
    byType[pattern.failureType] = (byType[pattern.failureType] || 0) + 1;
    totalConfidence += pattern.confidence;
    totalSuccesses += pattern.successCount;
    totalFailures += pattern.failureCount;
  }

  return {
    totalPatterns: patterns.length,
    byType,
    avgConfidence: patterns.length > 0 ? totalConfidence / patterns.length : 0,
    totalSuccesses,
    totalFailures,
  };
}
