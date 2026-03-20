/**
 * Fix Pattern Database
 *
 * Stores and retrieves learned fix patterns for faster future fixes.
 */

import * as fs from 'fs';
import * as path from 'path';
import { createHash } from 'crypto';
import type { FixPattern, FailureType, TestFailure } from '../types.ts';
import { log } from '../logger.ts';

const PATTERNS_DIR = './scripts/ai-dev-loop/fix-patterns/patterns';
const PATTERN_INDEX = path.join(PATTERNS_DIR, '_index.json');

// Ensure patterns directory exists
if (!fs.existsSync(PATTERNS_DIR)) {
  fs.mkdirSync(PATTERNS_DIR, { recursive: true });
}

export interface PatternDB {
  getPatterns(failureType?: FailureType): FixPattern[];
  getPattern(id: string): FixPattern | null;
  savePattern(pattern: FixPattern): void;
  updatePatternStats(id: string, success: boolean): void;
  findMatchingPatterns(errorMessage: string, failureType: FailureType): FixPattern[];
  cleanup(maxAge?: number): void;
}

interface PatternIndex {
  patterns: PatternIndexEntry[];
  lastUpdated: number;
}

interface PatternIndexEntry {
  id: string;
  name: string;
  failureType: string;
  filePath: string;
  confidence: number;
  lastUsed: number;
}

class PatternDBImpl implements PatternDB {
  private patterns: Map<string, FixPattern> = new Map();
  private loaded = false;

  /**
   * Load patterns from disk
   */
  private loadPatterns(): void {
    if (this.loaded) return;

    try {
      if (fs.existsSync(PATTERN_INDEX)) {
        const indexContent = fs.readFileSync(PATTERN_INDEX, 'utf-8');
        const index: PatternIndex = JSON.parse(indexContent);

        for (const entry of index.patterns) {
          try {
            const patternPath = path.join(PATTERNS_DIR, entry.filePath);
            if (fs.existsSync(patternPath)) {
              const patternContent = fs.readFileSync(patternPath, 'utf-8');
              const pattern: FixPattern = JSON.parse(patternContent);
              this.patterns.set(pattern.id, pattern);
            }
          } catch (error) {
            log('warn', `Failed to load pattern: ${entry.id}`, {
              error: error instanceof Error ? error.message : String(error),
            });
          }
        }
      }

      // Also load any patterns not in the index
      const files = fs.readdirSync(PATTERNS_DIR);
      for (const file of files) {
        if (file.endsWith('.json') && !file.startsWith('_')) {
          try {
            const content = fs.readFileSync(path.join(PATTERNS_DIR, file), 'utf-8');
            const pattern: FixPattern = JSON.parse(content);
            if (!this.patterns.has(pattern.id)) {
              this.patterns.set(pattern.id, pattern);
            }
          } catch {
            // Ignore parse errors
          }
        }
      }

      this.loaded = true;
      log('debug', `Loaded ${this.patterns.size} fix patterns`);
    } catch (error) {
      log('warn', 'Failed to load fix patterns', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Get all patterns, optionally filtered by type
   */
  getPatterns(failureType?: FailureType): FixPattern[] {
    this.loadPatterns();

    let patterns = Array.from(this.patterns.values());

    if (failureType) {
      patterns = patterns.filter(p => p.failureType === failureType || p.failureType === 'unknown');
    }

    // Sort by confidence
    return patterns.sort((a, b) => b.confidence - a.confidence);
  }

  /**
   * Get a specific pattern by ID
   */
  getPattern(id: string): FixPattern | null {
    this.loadPatterns();
    return this.patterns.get(id) || null;
  }

  /**
   * Save a new pattern
   */
  savePattern(pattern: FixPattern): void {
    this.loadPatterns();

    // Generate ID if not provided
    if (!pattern.id) {
      pattern.id = this.generatePatternId(pattern);
    }

    this.patterns.set(pattern.id, pattern);

    // Save to disk
    const filename = `${pattern.id}.json`;
    const filepath = path.join(PATTERNS_DIR, filename);

    try {
      fs.writeFileSync(filepath, JSON.stringify(pattern, null, 2), 'utf-8');
      this.updateIndex();
      log('info', `Saved fix pattern: ${pattern.name}`);
    } catch (error) {
      log('error', 'Failed to save fix pattern', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Update pattern success/failure statistics
   */
  updatePatternStats(id: string, success: boolean): void {
    this.loadPatterns();

    const pattern = this.patterns.get(id);
    if (!pattern) return;

    if (success) {
      pattern.successCount++;
    } else {
      pattern.failureCount++;
    }

    // Update confidence based on success rate
    const total = pattern.successCount + pattern.failureCount;
    pattern.confidence = total > 0 ? pattern.successCount / total : 0.5;
    pattern.lastUsed = Date.now();

    this.patterns.set(id, pattern);

    // Save updated pattern
    const filename = `${id}.json`;
    const filepath = path.join(PATTERNS_DIR, filename);

    try {
      fs.writeFileSync(filepath, JSON.stringify(pattern, null, 2), 'utf-8');
      this.updateIndex();
    } catch (error) {
      log('error', 'Failed to update pattern stats', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Find patterns matching an error message
   */
  findMatchingPatterns(errorMessage: string, failureType: FailureType): FixPattern[] {
    this.loadPatterns();

    const matches: FixPattern[] = [];
    const errorLower = errorMessage.toLowerCase();

    for (const pattern of this.patterns.values()) {
      // Type must match or be 'unknown'
      if (pattern.failureType !== failureType && pattern.failureType !== 'unknown') {
        continue;
      }

      // Try to match error pattern (regex)
      try {
        const regex = new RegExp(pattern.errorPattern, 'i');
        if (regex.test(errorMessage)) {
          matches.push(pattern);
          continue;
        }
      } catch {
        // Invalid regex, skip pattern matching
      }

      // Fallback: check if pattern keywords appear in error
      const patternWords = pattern.errorPattern.toLowerCase().split(/\s+/);
      const matchingWords = patternWords.filter(w => w.length > 3 && errorLower.includes(w));
      if (matchingWords.length >= 2) {
        matches.push(pattern);
      }
    }

    // Sort by confidence
    return matches.sort((a, b) => b.confidence - a.confidence);
  }

  /**
   * Clean up old patterns
   */
  cleanup(maxAge: number = 90 * 24 * 60 * 60 * 1000): void {
    this.loadPatterns();

    const now = Date.now();
    const toRemove: string[] = [];

    for (const [id, pattern] of this.patterns) {
      // Remove patterns that haven't been used in a while and have low confidence
      if (
        now - pattern.lastUsed > maxAge &&
        pattern.confidence < 0.3 &&
        pattern.successCount + pattern.failureCount < 5
      ) {
        toRemove.push(id);
      }
    }

    for (const id of toRemove) {
      this.patterns.delete(id);
      const filepath = path.join(PATTERNS_DIR, `${id}.json`);
      try {
        if (fs.existsSync(filepath)) {
          fs.unlinkSync(filepath);
        }
      } catch {
        // Ignore delete errors
      }
    }

    if (toRemove.length > 0) {
      this.updateIndex();
      log('info', `Cleaned up ${toRemove.length} old fix patterns`);
    }
  }

  /**
   * Generate a pattern ID from its content
   */
  private generatePatternId(pattern: FixPattern): string {
    const content = `${pattern.failureType}:${pattern.errorPattern}:${pattern.solution}`;
    return createHash('md5').update(content).digest('hex').substring(0, 12);
  }

  /**
   * Update the pattern index file
   */
  private updateIndex(): void {
    const index: PatternIndex = {
      patterns: Array.from(this.patterns.values()).map(p => ({
        id: p.id,
        name: p.name,
        failureType: p.failureType,
        filePath: `${p.id}.json`,
        confidence: p.confidence,
        lastUsed: p.lastUsed,
      })),
      lastUpdated: Date.now(),
    };

    try {
      fs.writeFileSync(PATTERN_INDEX, JSON.stringify(index, null, 2), 'utf-8');
    } catch (error) {
      log('error', 'Failed to update pattern index', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}

// Singleton instance
let dbInstance: PatternDB | null = null;

export function getPatternDB(): PatternDB {
  if (!dbInstance) {
    dbInstance = new PatternDBImpl();
  }
  return dbInstance;
}

/**
 * Create a pattern from a successful fix
 */
export function createPatternFromFix(
  failure: TestFailure,
  filesModified: string[],
  solution: string
): FixPattern {
  return {
    id: '',
    name: `Fix for ${failure.type}: ${failure.testName.substring(0, 50)}`,
    failureType: failure.type,
    errorPattern: extractErrorPattern(failure.errorMessage),
    solution,
    filesModified,
    successCount: 1,
    failureCount: 0,
    lastUsed: Date.now(),
    confidence: 1.0,
  };
}

/**
 * Extract a regex pattern from an error message
 */
function extractErrorPattern(errorMessage: string): string {
  // Remove specific values (numbers, paths, etc.) to create a general pattern
  let pattern = errorMessage
    .replace(/\d+/g, '\\d+')                    // Numbers
    .replace(/["'][^"']*["']/g, '["\'][^"\']*["\']')  // Quoted strings
    .replace(/\/[^\s]+/g, '\\/[^\\s]+')        // Paths
    .replace(/\s+/g, '\\s+')                    // Whitespace
    .substring(0, 200);                         // Limit length

  // Escape special regex characters (except our replacements)
  pattern = pattern.replace(/[.+?^${}()|[\]\\]/g, '\\$&');

  return pattern;
}
