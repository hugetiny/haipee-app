/**
 * Crash Analyzer
 *
 * Analyzes crash logs for patterns and suggests fixes.
 */

import * as fs from 'fs';
import * as path from 'path';
import { log } from './logger.ts';

const CRASH_LOG_PATH = path.join(process.env.HOME || '', '.haipee/crash.log');
const BINARY_LOG_PATH = './ai-loop-logs/tauri-binary.log';

export interface CrashAnalysis {
  hasCrashed: boolean;
  crashCount: number;
  lastCrashTime: number | null;
  crashPatterns: CrashPattern[];
  suggestedFixes: CrashFix[];
  crashLog: string | null;
  binaryLog: string | null;
}

export interface CrashPattern {
  name: string;
  pattern: string;
  count: number;
  lastSeen: number;
}

export interface CrashFix {
  pattern: string;
  fix: string;
  confidence: number;
}

// Known crash patterns and their fixes
const KNOWN_CRASH_PATTERNS: Array<{
  pattern: RegExp;
  name: string;
  fix: string;
  confidence: number;
}> = [
  {
    pattern: /panicked at ['"](.+?)['"]/,
    name: 'Rust panic',
    fix: 'Check for unwrap() calls on None/Err values. Add proper error handling with match or if let.',
    confidence: 0.7,
  },
  {
    pattern: /segmentation fault|SIGSEGV/i,
    name: 'Segmentation fault',
    fix: 'Memory access violation. Check for null pointer dereferences or buffer overflows.',
    confidence: 0.5,
  },
  {
    pattern: /out of memory|OOM/i,
    name: 'Out of memory',
    fix: 'Memory leak detected. Check for unreleased resources or large allocations.',
    confidence: 0.6,
  },
  {
    pattern: /database.*locked|SQLITE_BUSY/i,
    name: 'Database lock',
    fix: 'Database is locked. Check for long-running transactions or connection pooling issues.',
    confidence: 0.8,
  },
  {
    pattern: /permission denied|EACCES/i,
    name: 'Permission denied',
    fix: 'File system permission error. Check file/directory permissions and ownership.',
    confidence: 0.7,
  },
  {
    pattern: /address already in use|EADDRINUSE/i,
    name: 'Port in use',
    fix: 'Port is already in use. Kill conflicting process or use a different port.',
    confidence: 0.9,
  },
  {
    pattern: /connection refused|ECONNREFUSED/i,
    name: 'Connection refused',
    fix: 'Cannot connect to service. Check if the service is running and accessible.',
    confidence: 0.8,
  },
  {
    pattern: /thread .* panicked/i,
    name: 'Thread panic',
    fix: 'A thread panicked. Check for panics in spawned tasks or async operations.',
    confidence: 0.6,
  },
  {
    pattern: /stack overflow/i,
    name: 'Stack overflow',
    fix: 'Stack overflow detected. Check for infinite recursion or very deep call stacks.',
    confidence: 0.7,
  },
  {
    pattern: /double free|corrupted size/i,
    name: 'Memory corruption',
    fix: 'Memory corruption detected. Check for use-after-free or double-free errors.',
    confidence: 0.5,
  },
];

export class CrashAnalyzer {
  private crashCount = 0;
  private lastCrashTime: number | null = null;
  private patterns: Map<string, CrashPattern> = new Map();

  /**
   * Analyze crash logs
   */
  analyze(): CrashAnalysis {
    const crashLog = this.readCrashLog();
    const binaryLog = this.readBinaryLog();

    // Analyze crash log
    if (crashLog) {
      this.analyzeLog(crashLog);
    }

    // Analyze binary log
    if (binaryLog) {
      this.analyzeLog(binaryLog);
    }

    // Find suggested fixes
    const suggestedFixes = this.getSuggestedFixes();

    return {
      hasCrashed: this.crashCount > 0,
      crashCount: this.crashCount,
      lastCrashTime: this.lastCrashTime,
      crashPatterns: Array.from(this.patterns.values()),
      suggestedFixes,
      crashLog: crashLog?.substring(0, 5000) || null,
      binaryLog: binaryLog?.substring(0, 5000) || null,
    };
  }

  /**
   * Check if a crash has occurred
   */
  hasRecentCrash(maxAgeMs: number = 60_000): boolean {
    if (!this.lastCrashTime) return false;
    return Date.now() - this.lastCrashTime < maxAgeMs;
  }

  /**
   * Get the most likely crash cause
   */
  getLikelyCrashCause(): string | null {
    const patterns = Array.from(this.patterns.values());
    if (patterns.length === 0) return null;

    // Sort by count and return the most common
    patterns.sort((a, b) => b.count - a.count);
    return patterns[0].name;
  }

  /**
   * Read crash log file
   */
  private readCrashLog(): string | null {
    try {
      if (fs.existsSync(CRASH_LOG_PATH)) {
        return fs.readFileSync(CRASH_LOG_PATH, 'utf-8');
      }
    } catch {
      // Ignore read errors
    }
    return null;
  }

  /**
   * Read binary log file
   */
  private readBinaryLog(): string | null {
    try {
      if (fs.existsSync(BINARY_LOG_PATH)) {
        return fs.readFileSync(BINARY_LOG_PATH, 'utf-8');
      }
    } catch {
      // Ignore read errors
    }
    return null;
  }

  /**
   * Analyze a log for crash patterns
   */
  private analyzeLog(logContent: string): void {
    const lines = logContent.split('\n');

    for (const line of lines) {
      // Check for crash indicators
      if (line.includes('panicked') || line.includes('crash') || line.includes('SIGSEGV')) {
        this.crashCount++;
        this.lastCrashTime = Date.now();
      }

      // Match known patterns
      for (const knownPattern of KNOWN_CRASH_PATTERNS) {
        if (knownPattern.pattern.test(line)) {
          const existing = this.patterns.get(knownPattern.name);
          if (existing) {
            existing.count++;
            existing.lastSeen = Date.now();
          } else {
            this.patterns.set(knownPattern.name, {
              name: knownPattern.name,
              pattern: knownPattern.pattern.source,
              count: 1,
              lastSeen: Date.now(),
            });
          }
        }
      }
    }
  }

  /**
   * Get suggested fixes for detected patterns
   */
  private getSuggestedFixes(): CrashFix[] {
    const fixes: CrashFix[] = [];

    for (const [name, pattern] of this.patterns) {
      const knownPattern = KNOWN_CRASH_PATTERNS.find(p => p.name === name);
      if (knownPattern) {
        fixes.push({
          pattern: name,
          fix: knownPattern.fix,
          confidence: knownPattern.confidence,
        });
      }
    }

    // Sort by confidence
    return fixes.sort((a, b) => b.confidence - a.confidence);
  }

  /**
   * Reset crash tracking
   */
  reset(): void {
    this.crashCount = 0;
    this.lastCrashTime = null;
    this.patterns.clear();
  }

  /**
   * Clear crash log files
   */
  clearLogs(): void {
    try {
      if (fs.existsSync(CRASH_LOG_PATH)) {
        fs.writeFileSync(CRASH_LOG_PATH, '', 'utf-8');
      }
      if (fs.existsSync(BINARY_LOG_PATH)) {
        fs.writeFileSync(BINARY_LOG_PATH, '', 'utf-8');
      }
      this.reset();
      log('info', 'Crash logs cleared');
    } catch (error) {
      log('warn', 'Failed to clear crash logs', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}

// Singleton instance
let analyzerInstance: CrashAnalyzer | null = null;

export function getCrashAnalyzer(): CrashAnalyzer {
  if (!analyzerInstance) {
    analyzerInstance = new CrashAnalyzer();
  }
  return analyzerInstance;
}

/**
 * Format crash analysis for prompt
 */
export function formatCrashAnalysisForPrompt(analysis: CrashAnalysis): string {
  if (!analysis.hasCrashed) {
    return 'No crashes detected.';
  }

  let output = `## Crash Analysis\n`;
  output += `- **Crash count**: ${analysis.crashCount}\n`;

  if (analysis.lastCrashTime) {
    const ago = Math.round((Date.now() - analysis.lastCrashTime) / 1000);
    output += `- **Last crash**: ${ago}s ago\n`;
  }

  if (analysis.crashPatterns.length > 0) {
    output += '\n### Detected Crash Patterns\n';
    for (const pattern of analysis.crashPatterns) {
      output += `- **${pattern.name}**: ${pattern.count} occurrences\n`;
    }
  }

  if (analysis.suggestedFixes.length > 0) {
    output += '\n### Suggested Fixes\n';
    for (const fix of analysis.suggestedFixes.slice(0, 3)) {
      output += `- **${fix.pattern}** (${(fix.confidence * 100).toFixed(0)}% confidence):\n`;
      output += `  ${fix.fix}\n`;
    }
  }

  return output;
}
