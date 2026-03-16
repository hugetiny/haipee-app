/**
 * AI Development Loop - Main Loop
 */

import type { LoopConfig, Checkpoint, TestFailure, ResolvedFailure, SkippedFailure, RunStats } from './types.ts';
import { initLogger, log, logSection, logProgress, logAlert } from './logger.ts';
import { generateRunId, getGitCommit, createCheckpoint, saveCheckpoint, loadCheckpoint, shouldCreateCheckpoint, createGitSnapshot } from './checkpoint.ts';
import { runTestLayer, shouldSkipLayer } from './test-runner.ts';
import { parseVitestFailures, parsePlaywrightFailures, detectFlakyTests } from './failure-parser.ts';
import { fixFailure, validateFix, rollbackChanges } from './fix-orchestrator.ts';

const DEFAULT_CONFIG: LoopConfig = {
  maxDurationHours: 10,
  checkpointIntervalMinutes: 30,
  maxFixAttempts: 3,
  dryRun: false,
  layers: [
    { name: 'unit', command: 'bun vitest run', timeout: 120000, priority: 1 },
    { name: 'integration', command: 'bun vitest run tests/integration', timeout: 300000, priority: 2 },
    { name: 'e2e', command: 'bun playwright test', timeout: 900000, priority: 3 },
  ],
};

interface LoopState {
  runId: string;
  startTime: number;
  iteration: number;
  lastCheckpointTime: number;
  testResults: Checkpoint['testResults'];
  pendingFailures: TestFailure[];
  resolvedFailures: ResolvedFailure[];
  skippedFailures: SkippedFailure[];
  stats: RunStats;
}

export async function runAutonomousLoop(config: Partial<LoopConfig> = {}): Promise<void> {
  const fullConfig = { ...DEFAULT_CONFIG, ...config };
  const runId = fullConfig.resumeFrom
    ? (loadCheckpoint(fullConfig.resumeFrom)?.runId || generateRunId())
    : generateRunId();

  initLogger(runId);

  logSection('AI Development Loop Starting');
  log('info', `Run ID: ${runId}`);
  log('info', `Git commit: ${getGitCommit()}`);
  log('info', `Max duration: ${fullConfig.maxDurationHours} hours`);
  log('info', `Dry run: ${fullConfig.dryRun}`);

  let state: LoopState;

  if (fullConfig.resumeFrom) {
    const checkpoint = loadCheckpoint(fullConfig.resumeFrom);
    if (checkpoint) {
      state = restoreStateFromCheckpoint(checkpoint, runId);
      log('info', `Resumed from checkpoint: iteration ${state.iteration}`);
    } else {
      state = createInitialState(runId);
    }
  } else {
    state = createInitialState(runId);
    createGitSnapshot(runId);
  }

  setupGracefulShutdown(state);

  try {
    while (shouldContinue(state, fullConfig)) {
      state.iteration++;
      logSection(`Iteration ${state.iteration}`);
      log('info', `Elapsed: ${formatDuration(Date.now() - state.startTime)}`);

      if (shouldCreateCheckpoint(state.lastCheckpointTime, fullConfig.checkpointIntervalMinutes)) {
        await saveCurrentCheckpoint(state);
        state.lastCheckpointTime = Date.now();
      }

      await runTestIterations(state, fullConfig);

      if (state.pendingFailures.length > 0) {
        await processFailures(state, fullConfig);
      } else {
        log('info', 'No pending failures - all tests passing!');
      }

      updateStats(state);

      const totalTests =
        state.testResults.unit.passed + state.testResults.unit.failed +
        state.testResults.integration.passed + state.testResults.integration.failed +
        state.testResults.e2e.passed + state.testResults.e2e.failed;
      const totalPassed =
        state.testResults.unit.passed + state.testResults.integration.passed + state.testResults.e2e.passed;
      const totalFailed =
        state.testResults.unit.failed + state.testResults.integration.failed + state.testResults.e2e.failed;

      logProgress(state.iteration, totalTests, totalPassed, totalFailed);
      await sleep(5000);
    }

    await saveCurrentCheckpoint(state);

    logSection('AI Development Loop Completed');
    log('info', `Total iterations: ${state.iteration}`);
    log('info', `Total duration: ${formatDuration(Date.now() - state.startTime)}`);
    log('info', `Fixes applied: ${state.stats.fixesApplied}`);
    log('info', `Fixes failed: ${state.stats.fixesFailed}`);
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    logAlert(`Loop crashed: ${errorMsg}`);
    await saveCurrentCheckpoint(state);
    throw error;
  }
}

async function runTestIterations(state: LoopState, config: LoopConfig): Promise<void> {
  const sortedLayers = [...config.layers].sort((a, b) => a.priority - b.priority);

  for (const layer of sortedLayers) {
    if (shouldSkipLayer(layer, state.pendingFailures)) continue;

    log('info', `Running ${layer.name} tests...`);
    const result = await runTestLayer(layer, { targetTest: config.targetTest });
    state.testResults[layer.name] = result;

    if (result.failed > 0) {
      log('info', `${result.failed} tests failed in ${layer.name} layer`);
      // Simplified: we don't re-run to get output, just track that failures exist
      // In a full implementation, we'd capture and parse the actual failure details
    }
  }
}

async function processFailures(state: LoopState, config: LoopConfig): Promise<void> {
  log('info', `Processing ${state.pendingFailures.length} pending failures`);

  const sortedFailures = [...state.pendingFailures].sort((a, b) => {
    if (a.fixAttempts !== b.fixAttempts) return a.fixAttempts - b.fixAttempts;
    return a.firstSeen - b.firstSeen;
  });

  for (const failure of sortedFailures) {
    if (failure.status === 'fixed' || failure.status === 'skipped') continue;

    if (failure.fixAttempts >= config.maxFixAttempts) {
      logAlert(`Max fix attempts exceeded for: ${failure.testName}`);
      failure.status = 'manual-required';
      state.skippedFailures.push({
        failureId: failure.id,
        testName: failure.testName,
        reason: `Max ${config.maxFixAttempts} fix attempts exceeded`,
        skippedAt: Date.now(),
      });
      state.pendingFailures = state.pendingFailures.filter((f) => f.id !== failure.id);
      continue;
    }

    failure.status = 'fixing';
    failure.fixAttempts++;
    failure.lastAttempt = Date.now();

    if (config.dryRun) {
      log('info', `[DRY RUN] Would attempt to fix: ${failure.testName}`);
      continue;
    }

    const fixResult = await fixFailure(failure, config.dryRun);

    if (fixResult.success) {
      const isValid = await validateFix(failure);

      if (isValid) {
        failure.status = 'fixed';
        state.resolvedFailures.push({
          failureId: failure.id,
          testName: failure.testName,
          resolution: 'fixed',
          fixAttempts: failure.fixAttempts,
          resolvedAt: Date.now(),
          fixDescription: fixResult.description,
        });
        state.pendingFailures = state.pendingFailures.filter((f) => f.id !== failure.id);
        state.stats.fixesApplied++;
        log('info', `✅ Fixed: ${failure.testName}`);
      } else {
        log('warn', `Fix validation failed for: ${failure.testName}`);
        rollbackChanges();
        failure.status = 'pending';
        state.stats.fixesFailed++;
      }
    } else {
      log('error', `Failed to generate fix for: ${failure.testName}`, { error: fixResult.error });

      if (failure.fixAttempts >= config.maxFixAttempts) {
        failure.status = 'manual-required';
        state.skippedFailures.push({
          failureId: failure.id,
          testName: failure.testName,
          reason: `Fix generation failed: ${fixResult.error}`,
          skippedAt: Date.now(),
        });
        state.pendingFailures = state.pendingFailures.filter((f) => f.id !== failure.id);
      } else {
        failure.status = 'pending';
      }
      state.stats.fixesFailed++;
    }

    await sleep(2000);
  }
}

function shouldContinue(state: LoopState, config: LoopConfig): boolean {
  const elapsedHours = (Date.now() - state.startTime) / (1000 * 60 * 60);

  if (elapsedHours >= config.maxDurationHours) {
    log('info', `Max duration (${config.maxDurationHours}h) reached, stopping loop`);
    return false;
  }

  const allTestsPassing =
    state.testResults.unit.failed === 0 &&
    state.testResults.integration.failed === 0 &&
    state.testResults.e2e.failed === 0;

  const noPendingFailures = state.pendingFailures.length === 0;

  if (state.iteration > 3 && allTestsPassing && noPendingFailures) {
    log('info', 'All tests passing consistently, stopping loop');
    return false;
  }

  return true;
}

async function saveCurrentCheckpoint(state: LoopState): Promise<void> {
  const checkpoint = createCheckpoint(
    state.runId,
    state.iteration,
    state.startTime,
    state.testResults,
    state.pendingFailures,
    state.resolvedFailures,
    state.skippedFailures,
    state.stats
  );
  saveCheckpoint(checkpoint);
}

function createInitialState(runId: string): LoopState {
  return {
    runId,
    startTime: Date.now(),
    iteration: 0,
    lastCheckpointTime: Date.now(),
    testResults: {
      unit: { passed: 0, failed: 0, skipped: 0, duration: 0, tests: [] },
      integration: { passed: 0, failed: 0, skipped: 0, duration: 0, tests: [] },
      e2e: { passed: 0, failed: 0, skipped: 0, duration: 0, tests: [] },
    },
    pendingFailures: [],
    resolvedFailures: [],
    skippedFailures: [],
    stats: {
      totalTestsRun: 0, totalTestsPassed: 0, totalTestsFailed: 0,
      fixesApplied: 0, fixesFailed: 0, fixSuccessRate: 0, averageFixTime: 0,
    },
  };
}

function restoreStateFromCheckpoint(checkpoint: Checkpoint, runId: string): LoopState {
  return {
    runId,
    startTime: checkpoint.startTime,
    iteration: checkpoint.iteration,
    lastCheckpointTime: Date.now(),
    testResults: checkpoint.testResults,
    pendingFailures: checkpoint.pendingFailures,
    resolvedFailures: checkpoint.resolvedFailures,
    skippedFailures: checkpoint.skippedFailures,
    stats: checkpoint.stats,
  };
}

function updateStats(state: LoopState): void {
  const totalTests =
    state.testResults.unit.passed + state.testResults.unit.failed +
    state.testResults.integration.passed + state.testResults.integration.failed +
    state.testResults.e2e.passed + state.testResults.e2e.failed;
  const totalPassed =
    state.testResults.unit.passed + state.testResults.integration.passed + state.testResults.e2e.passed;
  const totalFailed =
    state.testResults.unit.failed + state.testResults.integration.failed + state.testResults.e2e.failed;

  state.stats.totalTestsRun = totalTests;
  state.stats.totalTestsPassed = totalPassed;
  state.stats.totalTestsFailed = totalFailed;

  const totalFixes = state.stats.fixesApplied + state.stats.fixesFailed;
  state.stats.fixSuccessRate = totalFixes > 0 ? state.stats.fixesApplied / totalFixes : 0;
}

function setupGracefulShutdown(state: LoopState): void {
  const shutdownHandler = async () => {
    log('info', 'Shutdown signal received, saving checkpoint...');
    await saveCurrentCheckpoint(state);
    process.exit(0);
  };

  process.on('SIGINT', shutdownHandler);
  process.on('SIGTERM', shutdownHandler);
}

function formatDuration(ms: number): string {
  const hours = Math.floor(ms / (1000 * 60 * 60));
  const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
  const seconds = Math.floor((ms % (1000 * 60)) / 1000);

  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes}m ${seconds}s`;
  return `${seconds}s`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
