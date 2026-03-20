/**
 * Fix Strategy Base
 *
 * Abstract base class and interfaces for fix strategies.
 */

import type { TestFailure, FixResult, FixContext, FixStrategy } from '../types.ts';
import { log } from '../logger.ts';

export { type FixStrategy };

/**
 * Abstract base class for fix strategies
 */
export abstract class BaseFixStrategy implements FixStrategy {
  abstract readonly name: string;
  abstract readonly priority: number;

  /**
   * Check if this strategy can handle the given failure
   */
  abstract canHandle(failure: TestFailure): boolean;

  /**
   * Execute the fix strategy
   */
  abstract execute(failure: TestFailure, context: FixContext): Promise<FixResult>;

  /**
   * Log strategy execution
   */
  protected logExecution(failure: TestFailure, message: string): void {
    log('info', `[${this.name}] ${message}`, {
      test: failure.testName,
      type: failure.type,
    });
  }

  /**
   * Create a successful fix result
   */
  protected success(filesModified: string[], description: string): FixResult {
    return {
      success: true,
      filesModified,
      description,
    };
  }

  /**
   * Create a failed fix result
   */
  protected failure(error: string): FixResult {
    return {
      success: false,
      filesModified: [],
      error,
    };
  }
}

/**
 * Strategy runner that executes strategies in parallel
 */
export class StrategyRunner {
  private strategies: FixStrategy[] = [];

  /**
   * Register a strategy
   */
  register(strategy: FixStrategy): void {
    this.strategies.push(strategy);
    // Sort by priority (lower = higher priority)
    this.strategies.sort((a, b) => a.priority - b.priority);
  }

  /**
   * Get strategies that can handle the failure
   */
  getApplicableStrategies(failure: TestFailure): FixStrategy[] {
    return this.strategies.filter(s => s.canHandle(failure));
  }

  /**
   * Execute the best strategy for a failure
   */
  async executeBest(failure: TestFailure, context: FixContext): Promise<FixResult> {
    const applicable = this.getApplicableStrategies(failure);

    if (applicable.length === 0) {
      log('warn', `No applicable strategy for failure type: ${failure.type}`);
      return {
        success: false,
        filesModified: [],
        error: `No strategy available for failure type: ${failure.type}`,
      };
    }

    // Try strategies in priority order
    for (const strategy of applicable) {
      this.logStrategyAttempt(strategy, failure);

      try {
        const result = await strategy.execute(failure, context);

        if (result.success) {
          log('info', `Strategy "${strategy.name}" succeeded`);
          return result;
        }

        log('warn', `Strategy "${strategy.name}" failed: ${result.error}`);
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        log('error', `Strategy "${strategy.name}" threw error: ${errorMsg}`);
      }
    }

    return {
      success: false,
      filesModified: [],
      error: 'All applicable strategies failed',
    };
  }

  /**
   * Execute multiple strategies in parallel and return the first success
   */
  async executeParallel(
    failure: TestFailure,
    context: FixContext,
    maxParallel: number = 3
  ): Promise<FixResult> {
    const applicable = this.getApplicableStrategies(failure).slice(0, maxParallel);

    if (applicable.length === 0) {
      return {
        success: false,
        filesModified: [],
        error: `No strategy available for failure type: ${failure.type}`,
      };
    }

    log('info', `Executing ${applicable.length} strategies in parallel`);

    // Create promises for all strategies
    const promises = applicable.map(async (strategy) => {
      this.logStrategyAttempt(strategy, failure);
      try {
        const result = await strategy.execute(failure, context);
        return { strategy: strategy.name, result };
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        return {
          strategy: strategy.name,
          result: { success: false, filesModified: [], error: errorMsg } as FixResult,
        };
      }
    });

    // Wait for first success or all failures
    const results = await Promise.allSettled(promises);

    for (const settled of results) {
      if (settled.status === 'fulfilled' && settled.value.result.success) {
        log('info', `Strategy "${settled.value.strategy}" succeeded in parallel execution`);
        return settled.value.result;
      }
    }

    // All failed
    const errors = results
      .filter((r): r is PromiseFulfilledResult<{ strategy: string; result: FixResult }> =>
        r.status === 'fulfilled'
      )
      .map(r => `${r.value.strategy}: ${r.value.result.error}`)
      .join('; ');

    return {
      success: false,
      filesModified: [],
      error: `All parallel strategies failed: ${errors}`,
    };
  }

  /**
   * Log strategy attempt
   */
  private logStrategyAttempt(strategy: FixStrategy, failure: TestFailure): void {
    log('info', `Trying strategy "${strategy.name}" for: ${failure.testName}`, {
      type: failure.type,
      priority: strategy.priority,
    });
  }
}

// Singleton instance
let runnerInstance: StrategyRunner | null = null;

export function getStrategyRunner(): StrategyRunner {
  if (!runnerInstance) {
    runnerInstance = new StrategyRunner();
  }
  return runnerInstance;
}
