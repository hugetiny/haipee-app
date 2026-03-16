/**
 * AI Development Loop - Checkpoint System
 */

import * as fs from 'fs';
import * as path from 'path';
import type { Checkpoint } from './types.ts';
import { log, logCheckpointSaved } from './logger.ts';

const CHECKPOINT_DIR = './ai-loop-logs/checkpoints';

if (!fs.existsSync(CHECKPOINT_DIR)) {
  fs.mkdirSync(CHECKPOINT_DIR, { recursive: true });
}

export function generateRunId(): string {
  return `run-${Date.now()}`;
}

export function getGitCommit(): string {
  try {
    const { execSync } = require('child_process');
    return execSync('git rev-parse --short HEAD', { encoding: 'utf-8' }).trim();
  } catch {
    return 'unknown';
  }
}

export function createCheckpoint(
  runId: string,
  iteration: number,
  startTime: number,
  testResults: Checkpoint['testResults'],
  pendingFailures: Checkpoint['pendingFailures'],
  resolvedFailures: Checkpoint['resolvedFailures'],
  skippedFailures: Checkpoint['skippedFailures'],
  stats: Checkpoint['stats']
): Checkpoint {
  return {
    timestamp: Date.now(),
    runId,
    gitCommit: getGitCommit(),
    iteration,
    startTime,
    duration: Date.now() - startTime,
    testResults,
    pendingFailures,
    resolvedFailures,
    skippedFailures,
    stats,
  };
}

export function saveCheckpoint(checkpoint: Checkpoint): string {
  const filename = `checkpoint-${checkpoint.runId}-${checkpoint.iteration}.json`;
  const filepath = path.join(CHECKPOINT_DIR, filename);

  fs.writeFileSync(filepath, JSON.stringify(checkpoint, null, 2));
  logCheckpointSaved(filepath);

  const latestPath = path.join(CHECKPOINT_DIR, 'latest.json');
  fs.writeFileSync(latestPath, JSON.stringify(checkpoint, null, 2));

  return filepath;
}

export function loadCheckpoint(checkpointPath: string): Checkpoint | null {
  try {
    const fullPath = checkpointPath.startsWith('/')
      ? checkpointPath
      : path.join(CHECKPOINT_DIR, checkpointPath);

    if (!fs.existsSync(fullPath)) {
      log('error', `Checkpoint not found: ${fullPath}`);
      return null;
    }

    const content = fs.readFileSync(fullPath, 'utf-8');
    const checkpoint: Checkpoint = JSON.parse(content);

    log('info', `📂 Loaded checkpoint: ${checkpointPath}`, {
      iteration: checkpoint.iteration,
      duration: Math.round(checkpoint.duration / 1000 / 60) + 'min',
      pendingFailures: checkpoint.pendingFailures.length,
    });

    return checkpoint;
  } catch (error) {
    log('error', `Failed to load checkpoint: ${checkpointPath}`, {
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

export function loadLatestCheckpoint(): Checkpoint | null {
  const latestPath = path.join(CHECKPOINT_DIR, 'latest.json');
  if (fs.existsSync(latestPath)) {
    return loadCheckpoint('latest.json');
  }
  return null;
}

export function listCheckpoints(): string[] {
  try {
    return fs
      .readdirSync(CHECKPOINT_DIR)
      .filter((f) => f.startsWith('checkpoint-') && f.endsWith('.json'))
      .sort()
      .reverse();
  } catch {
    return [];
  }
}

export function shouldCreateCheckpoint(lastCheckpointTime: number, intervalMinutes: number): boolean {
  return Date.now() - lastCheckpointTime > intervalMinutes * 60 * 1000;
}

export function createGitSnapshot(runId: string): void {
  try {
    const { execSync } = require('child_process');
    const snapshotName = `ai-loop-snapshot-${runId}`;

    const status = execSync('git status --porcelain', { encoding: 'utf-8' });

    if (status.trim()) {
      execSync('git add -A');
      execSync(`git stash push -m "${snapshotName}"`);
      log('info', `💾 Git snapshot created: ${snapshotName}`);
    } else {
      log('info', 'No uncommitted changes, skipping git snapshot');
    }
  } catch (error) {
    log('warn', 'Failed to create git snapshot', {
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
