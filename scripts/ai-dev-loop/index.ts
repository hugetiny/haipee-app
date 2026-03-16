#!/usr/bin/env bun
/**
 * AI Development Loop - CLI
 */

import { parseArgs } from 'util';
import { runAutonomousLoop } from './loop.ts';
import { loadLatestCheckpoint, listCheckpoints } from './checkpoint.ts';
import { log } from './logger.ts';

interface CliOptions {
  duration: number;
  resume?: string;
  'list-checkpoints': boolean;
  'dry-run': boolean;
  test?: string;
  help: boolean;
}

function printHelp(): void {
  console.log(`
AI Development Loop - Autonomous Testing & Fixing

Usage: bun run ai:dev [options]

Options:
  --duration=<hours>      Maximum runtime in hours (default: 10)
  --resume=<checkpoint>   Resume from a specific checkpoint file
  --resume-latest         Resume from the latest checkpoint
  --list-checkpoints      List available checkpoints
  --dry-run               Run without applying fixes (test mode)
  --test=<path>           Run on a specific test file only
  --help                  Show this help message

Examples:
  bun run ai:dev                          # Start 10-hour loop
  bun run ai:dev --duration=5             # Run for 5 hours
  bun run ai:dev --resume-latest          # Resume from latest checkpoint
  bun run ai:dev --dry-run                # Test mode
  bun run ai:dev --test=tests/e2e/openai.spec.ts  # Single test
`);
}

function parseCliOptions(): CliOptions {
  const { values } = parseArgs({
    args: Bun.argv.slice(2),
    options: {
      duration: { type: 'string', default: '10' },
      resume: { type: 'string' },
      'resume-latest': { type: 'boolean', default: false },
      'list-checkpoints': { type: 'boolean', default: false },
      'dry-run': { type: 'boolean', default: false },
      test: { type: 'string' },
      help: { type: 'boolean', default: false },
    },
    allowPositionals: false,
  });

  return {
    duration: parseFloat(values.duration as string) || 10,
    resume: values['resume-latest'] ? 'latest.json' : (values.resume as string),
    'list-checkpoints': values['list-checkpoints'] as boolean,
    'dry-run': values['dry-run'] as boolean,
    test: values.test as string | undefined,
    help: values.help as boolean,
  };
}

async function main(): Promise<void> {
  const options = parseCliOptions();

  if (options.help) {
    printHelp();
    process.exit(0);
  }

  if (options['list-checkpoints']) {
    const checkpoints = listCheckpoints();
    if (checkpoints.length === 0) {
      console.log('No checkpoints found.');
    } else {
      console.log('Available checkpoints:');
      for (const cp of checkpoints.slice(0, 10)) {
        console.log(`  - ${cp}`);
      }
    }
    process.exit(0);
  }

  if (options.resume) {
    const checkpoint = options.resume === 'latest.json' ? loadLatestCheckpoint() : null;
    if (!checkpoint && options.resume === 'latest.json') {
      log('warn', 'No latest checkpoint found, starting fresh');
      options.resume = undefined;
    }
  }

  try {
    await runAutonomousLoop({
      maxDurationHours: options.duration,
      dryRun: options['dry-run'],
      resumeFrom: options.resume,
      targetTest: options.test,
    });
    process.exit(0);
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    log('error', `Loop crashed: ${errorMsg}`);
    process.exit(1);
  }
}

main();
