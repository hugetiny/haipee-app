/**
 * Fix Strategies Module Index
 *
 * Central export point for all fix strategies and the strategy runner.
 */

export { BaseFixStrategy, StrategyRunner, getStrategyRunner } from './strategy-base.ts';
export { AssertionFixStrategy } from './assertion-fix.ts';
export { TimeoutFixStrategy } from './timeout-fix.ts';
export { IpcFixStrategy } from './ipc-fix.ts';

import type { FixStrategy } from './strategy-base.ts';
import { getStrategyRunner } from './strategy-base.ts';
import { AssertionFixStrategy } from './assertion-fix.ts';
import { TimeoutFixStrategy } from './timeout-fix.ts';
import { IpcFixStrategy } from './ipc-fix.ts';
import type { TestFailure, FixResult, FixContext } from '../types.ts';
import { log } from '../logger.ts';

/**
 * Initialize all strategies
 */
export function initializeStrategies(): void {
  const runner = getStrategyRunner();

  // Register strategies in priority order
  runner.register(new IpcFixStrategy());      // Priority 15 - IPC issues first
  runner.register(new AssertionFixStrategy()); // Priority 20 - Common assertion failures
  runner.register(new TimeoutFixStrategy());   // Priority 25 - Timeout issues

  log('info', 'Fix strategies initialized');
}

/**
 * Execute the best strategy for a failure
 */
export async function executeBestStrategy(
  failure: TestFailure,
  context: FixContext
): Promise<FixResult> {
  const runner = getStrategyRunner();

  // Ensure strategies are initialized
  if (runner.getApplicableStrategies(failure).length === 0) {
    initializeStrategies();
  }

  return await runner.executeBest(failure, context);
}

/**
 * Execute strategies in parallel for faster fixing
 */
export async function executeParallelStrategies(
  failure: TestFailure,
  context: FixContext,
  maxParallel: number = 2
): Promise<FixResult> {
  const runner = getStrategyRunner();

  // Ensure strategies are initialized
  if (runner.getApplicableStrategies(failure).length === 0) {
    initializeStrategies();
  }

  return await runner.executeParallel(failure, context, maxParallel);
}
