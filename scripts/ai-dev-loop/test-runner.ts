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
    if (config.name === 'unit' || config.name === 'integration') {
      return await runVitestLayer(config, options);
    } else if (config.name === 'e2e') {
      return await runPlaywrightLayer(config, options);
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
  };

  const total = result.passed + result.failed + result.skipped;
  log('info', `${config.name} results: ${result.passed}/${total} passed (${result.failed} failed) in ${result.duration}ms`);

  return result;
}

async function runPlaywrightLayer(config: TestLayerConfig, options: RunOptions): Promise<TestLayerResult> {
  const startTime = Date.now();
  let cmd = 'bun';
  let args = ['playwright', 'test'];

  if (options.targetTest) {
    args.push(options.targetTest);
  } else {
    args.push('tests/e2e/');
  }

  log('info', `Executing: ${cmd} ${args.join(' ')}`);
  const { stdout, exitCode } = await executeCommand(cmd, args, config.timeout);

  const passedMatch = stdout.match(/(\d+) passed/);
  const failedMatch = stdout.match(/(\d+) failed/);
  const skippedMatch = stdout.match(/(\d+) skipped/);
  const timedOutMatch = stdout.match(/(\d+) timed out/);

  const passed = parseInt(passedMatch?.[1] || '0', 10);
  const failed = parseInt(failedMatch?.[1] || '0', 10) + parseInt(timedOutMatch?.[1] || '0', 10);
  const skipped = parseInt(skippedMatch?.[1] || '0', 10);

  const result: TestLayerResult = { passed, failed, skipped, duration: Date.now() - startTime, tests: [] };
  const total = passed + failed + skipped;
  log('info', `${config.name} results: ${passed}/${total} passed (${failed} failed) in ${result.duration}ms`);

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
  const isE2E = testPath.includes('e2e');
  const cmd = isE2E ? 'bunx' : 'bun';
  const args = isE2E ? ['playwright', 'test', testPath] : ['vitest', 'run', testPath];

  try {
    const { stdout, exitCode } = await executeCommand(cmd, args, timeout);
    return { passed: exitCode === 0, output: stdout };
  } catch (error: any) {
    return { passed: false, output: error.message || '' };
  }
}

export function shouldSkipLayer(layer: TestLayerConfig, pendingFailures: TestFailure[]): boolean {
  const higherPriorityFailures = pendingFailures.filter((f) => {
    if (layer.name === 'integration') return f.filePath.includes('unit');
    if (layer.name === 'e2e') return f.filePath.includes('unit') || f.filePath.includes('integration');
    return false;
  });

  if (higherPriorityFailures.length > 0) {
    log('info', `Skipping ${layer.name} tests - ${higherPriorityFailures.length} higher priority failures pending`);
    return true;
  }
  return false;
}
