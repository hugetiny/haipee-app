/**
 * AI Development Loop - Test Runner
 */

import { spawn } from 'child_process';
import type { TestLayerResult, TestLayerConfig, TestFailure } from './types.ts';
import { log, logSection } from './logger.ts';

interface RunOptions {
  targetTest?: string;
}

export async function runTestLayer(config: TestLayerConfig, options: RunOptions = {}): Promise<TestLayerResult> {
  logSection(`Running ${config.name} tests`);

  const startTime = Date.now();

  try {
    if (config.name === 'unit') {
      return await runVitestLayer(config, options);
    } else if (config.name === 'integration') {
      return await runIntegrationLayer(config, options);
    } else if (config.name === 'e2e') {
      return await runE2ELayer(config);
    }
    throw new Error(`Unknown test layer: ${config.name}`);
  } catch (error) {
    log('error', `Failed to run ${config.name} tests`, {
      error: error instanceof Error ? error.message : String(error),
    });
    return { passed: 0, failed: 0, skipped: 0, duration: Date.now() - startTime, tests: [] };
  }
}

async function runVitestLayer(config: TestLayerConfig, options: RunOptions): Promise<TestLayerResult> {
  const startTime = Date.now();
  let cmd = 'bun';
  let args = ['vitest', 'run', '--reporter=verbose'];

  if (options.targetTest) {
    args.push(options.targetTest);
  } else if (config.name === 'unit') {
    args.push('tests/components', 'tests/hooks', 'tests/utils');
  } else if (config.name === 'integration') {
    args.push('tests/integration');
  }

  log('info', `Executing: ${cmd} ${args.join(' ')}`);
  const { stdout, exitCode } = await executeCommand(cmd, args, config.timeout);

  const passedMatch = stdout.match(/(\d+) passed/);
  const failedMatch = stdout.match(/(\d+) failed/);
  const skippedMatch = stdout.match(/(\d+) skipped/);

  const result: TestLayerResult = {
    passed: parseInt(passedMatch?.[1] || '0', 10),
    failed: parseInt(failedMatch?.[1] || '0', 10),
    skipped: parseInt(skippedMatch?.[1] || '0', 10),
    duration: Date.now() - startTime,
    tests: [],
    rawOutput: stdout,
  };

  const total = result.passed + result.failed + result.skipped;
  log('info', `${config.name} results: ${result.passed}/${total} passed (${result.failed} failed) in ${result.duration}ms`);

  return result;
}

async function runIntegrationLayer(config: TestLayerConfig, options: RunOptions): Promise<TestLayerResult> {
  const startTime = Date.now();

  // Run Rust backend tests first
  log('info', 'Executing: cargo test --manifest-path src-tauri/Cargo.toml -- --test-output immediate');
  const cargoResult = await executeCommand(
    'cargo',
    ['test', '--manifest-path', 'src-tauri/Cargo.toml', '--', '--test-output', 'immediate'],
    Math.floor(config.timeout * 0.5), // half the budget for cargo
  );

  const cargoResultMatch = cargoResult.stdout.match(/test result:.*?(\d+) passed;\s*(\d+) failed/);
  const cargoIgnoredMatch = cargoResult.stdout.match(/(\d+) ignored/);
  const cargoPassed = parseInt(cargoResultMatch?.[1] || '0', 10);
  const cargoFailed = parseInt(cargoResultMatch?.[2] || '0', 10);
  const cargoSkipped = parseInt(cargoIgnoredMatch?.[1] || '0', 10);
  log('info', `rust (cargo): ${cargoPassed}/${cargoPassed + cargoFailed} passed (${cargoFailed} failed)`);

  // Run JS integration tests
  const vitestArgs = ['vitest', 'run', '--reporter=verbose'];
  if (options.targetTest) {
    vitestArgs.push(options.targetTest);
  } else {
    vitestArgs.push('tests/integration');
  }
  log('info', `Executing: bun ${vitestArgs.join(' ')}`);
  const vitestResult = await executeCommand('bun', vitestArgs, Math.floor(config.timeout * 0.5));

  const vitestPassedMatch = vitestResult.stdout.match(/(\d+) passed/);
  const vitestFailedMatch = vitestResult.stdout.match(/(\d+) failed/);
  const vitestSkippedMatch = vitestResult.stdout.match(/(\d+) skipped/);
  const vitestPassed = parseInt(vitestPassedMatch?.[1] || '0', 10);
  const vitestFailed = parseInt(vitestFailedMatch?.[1] || '0', 10);
  const vitestSkipped = parseInt(vitestSkippedMatch?.[1] || '0', 10);
  log('info', `js (vitest):  ${vitestPassed}/${vitestPassed + vitestFailed} passed (${vitestFailed} failed)`);

  const result: TestLayerResult = {
    passed: cargoPassed + vitestPassed,
    failed: cargoFailed + vitestFailed,
    skipped: cargoSkipped + vitestSkipped,
    duration: Date.now() - startTime,
    tests: [],
    rawOutput: `=== CARGO ===\n${cargoResult.stdout}\n=== VITEST ===\n${vitestResult.stdout}`,
  };

  const total = result.passed + result.failed + result.skipped;
  log('info', `integration total: ${result.passed}/${total} passed (${result.failed} failed) in ${result.duration}ms`);

  return result;
}

function executeCommand(cmd: string, args: string[], timeout: number): Promise<{ stdout: string; exitCode: number }> {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, CI: 'true' } });

    let stdout = '';
    let killed = false;

    const timeoutId = setTimeout(() => {
      killed = true;
      child.kill('SIGTERM');
      log('warn', `Command timed out after ${timeout}ms, killed`);
    }, timeout);

    child.stdout?.on('data', (data) => { stdout += data.toString(); });
    child.stderr?.on('data', (data) => { stdout += data.toString(); });

    child.on('close', (code) => {
      clearTimeout(timeoutId);
      resolve({ stdout, exitCode: killed ? 124 : (code || 0) });
    });

    child.on('error', (err) => {
      clearTimeout(timeoutId);
      resolve({ stdout, exitCode: 1 });
    });
  });
}

export async function runSingleTest(testPath: string, timeout: number = 120000): Promise<{ passed: boolean; output: string }> {
  log('info', `Running single test: ${testPath}`);
  const isTauriE2E = testPath.includes('e2e/');
  const cmd = isTauriE2E ? 'bunx' : 'bun';
  const wdioConf = process.env.CN_API_KEY || process.platform !== 'darwin'
    ? 'wdio.crabnebula.conf.ts'
    : 'wdio.conf.ts';
  const args = isTauriE2E ? ['wdio', 'run', wdioConf, '--spec', testPath] : ['vitest', 'run', testPath];

  try {
    const { stdout, exitCode } = await executeCommand(cmd, args, timeout);
    return { passed: exitCode === 0, output: stdout };
  } catch (error: any) {
    return { passed: false, output: error.message || '' };
  }
}

async function runE2ELayer(config: TestLayerConfig): Promise<TestLayerResult> {
  const startTime = Date.now();

  // Import process manager for crash detection
  const { getProcessManager } = await import('./tauri-process-manager.ts');
  const pm = getProcessManager();

  // Import crash analyzer for enhanced crash detection
  const { getCrashAnalyzer, formatCrashAnalysisForPrompt } = await import('./crash-analyzer.ts');
  const crashAnalyzer = getCrashAnalyzer();

  // Check if process is alive before running tests
  const wasAlive = pm.isAlive();
  if (!wasAlive) {
    log('warn', 'Tauri process not alive, WDIO will start it via onPrepare hook');
  }

  const cmd = 'bunx';
  const args = ['wdio', 'run', config.command.includes('crabnebula') ? 'wdio.crabnebula.conf.ts' : 'wdio.conf.ts'];

  log('info', `Executing: ${cmd} ${args.join(' ')}`);
  const { stdout, exitCode } = await executeCommand(cmd, args, config.timeout);

  // Check if process crashed during tests
  const isAliveNow = pm.isAlive();
  if (wasAlive && !isAliveNow) {
    log('error', 'Tauri process crashed during E2E tests!');

    // Capture crash info
    const crashLog = pm.getCrashLog();
    if (crashLog) {
      log('info', 'Crash log captured', { crashLog: crashLog.slice(-500) });
    }

    const binaryLog = pm.getBinaryLog();
    if (binaryLog) {
      log('info', 'Binary log (last 500 chars)', { log: binaryLog.slice(-500) });
    }

    // Analyze crash with crash analyzer
    const crashAnalysis = crashAnalyzer.analyze();
    if (crashAnalysis.hasCrashed) {
      log('info', `Crash analysis: ${crashAnalysis.crashCount} crash(es) detected`);
      if (crashAnalysis.suggestedFixes.length > 0) {
        log('info', 'Suggested fixes:');
        for (const fix of crashAnalysis.suggestedFixes.slice(0, 3)) {
          log('info', `  - ${fix.pattern}: ${fix.fix}`);
        }
      }
    }
  }

  // WebdriverIO spec-reporter output: "X passing", "X failing", "X pending"
  const passedMatch = stdout.match(/(\d+)\s+passing/);
  const failedMatch = stdout.match(/(\d+)\s+failing/);
  const skippedMatch = stdout.match(/(\d+)\s+pending/);

  let passed = parseInt(passedMatch?.[1] || '0', 10);
  let failed = parseInt(failedMatch?.[1] || '0', 10);
  const skipped = parseInt(skippedMatch?.[1] || '0', 10);

  // If process crashed, mark remaining tests as failed
  if (!isAliveNow && (passed + failed + skipped === 0)) {
    log('warn', 'No test results found, process may have crashed before tests ran');
    failed = 1; // Count as at least one failure for crash detection
  }

  const result: TestLayerResult = {
    passed,
    failed,
    skipped,
    duration: Date.now() - startTime,
    tests: [],
    rawOutput: stdout + (isAliveNow ? '' : '\n[PROCESS CRASH DETECTED]\n'),
  };

  const total = passed + failed + skipped;
  log('info', `e2e results: ${passed}/${total} passed (${failed} failed) in ${result.duration}ms`);

  // Reset restart count on successful iteration
  if (failed === 0) {
    pm.resetRestartCount();
  }

  return result;
}

function getFailureLayer(failure: TestFailure): 'unit' | 'integration' | 'e2e' {
  const fp = failure.filePath.replace(/\\/g, '/');
  if (fp.includes('/e2e/')) return 'e2e';
  if (fp.includes('/integration/') || fp.includes('src-tauri') || fp.endsWith('.rs')) return 'integration';
  return 'unit';
}

export function shouldSkipLayer(layer: TestLayerConfig, pendingFailures: TestFailure[]): boolean {
  // unit and integration always run
  if (layer.name === 'unit' || layer.name === 'integration') return false;

  const blockers = pendingFailures.filter((f) => {
    const failureLayer = getFailureLayer(f);
    // Skip e2e if integration layer has failures (broken backend / API = unreliable binary)
    if (layer.name === 'e2e') return failureLayer === 'integration' || failureLayer === 'unit';
    return false;
  });

  if (blockers.length > 0) {
    log('info', `Skipping ${layer.name} tests — ${blockers.length} higher-priority failures pending`);
    return true;
  }
  return false;
}
