#!/usr/bin/env bun
/**
 * Test Layer Runner
 * Usage: bun run test:layer <1-5>
 *
 * Layers:
 *   1 - JS Unit Tests (Vitest)
 *   2 - Rust Unit Tests (cargo test)
 *   3 - Integration Tests (Vitest + Tauri)
 *   4 - Playwright E2E (browser-mock IPC)
 *   5 - WebDriver E2E (real Tauri + real API)
 */

import { spawn } from 'child_process';

const layer = process.argv[2];

const layerCommands: Record<string, { cmd: string; desc: string }> = {
  '1': {
    cmd: 'bun vitest run tests/components tests/hooks tests/utils tests/config',
    desc: 'JS Unit Tests (Vitest)',
  },
  '2': {
    cmd: 'cargo test --manifest-path src-tauri/Cargo.toml',
    desc: 'Rust Unit Tests (cargo test)',
  },
  '3': {
    cmd: 'bun vitest run tests/integration',
    desc: 'Integration Tests (Vitest + Tauri)',
  },
  '4': {
    cmd: 'bun playwright test',
    desc: 'Playwright E2E (browser-mock IPC)',
  },
  '5': {
    cmd: 'bunx wdio run wdio.conf.ts',
    desc: 'WebDriver E2E (real Tauri + real API)',
  },
};

if (!layer || !layerCommands[layer]) {
  console.log('Usage: bun run test:layer <1-5>');
  console.log('');
  console.log('Layers:');
  console.log('  1 - JS Unit Tests (Vitest)');
  console.log('  2 - Rust Unit Tests (cargo test)');
  console.log('  3 - Integration Tests (Vitest + Tauri)');
  console.log('  4 - Playwright E2E (browser-mock IPC)');
  console.log('  5 - WebDriver E2E (real Tauri + real API)');
  process.exit(1);
}

const { cmd, desc } = layerCommands[layer];
console.log(`Running Layer ${layer}: ${desc}`);
console.log(`Command: ${cmd}`);
console.log('');

// Run the command and preserve exit code
const child = spawn(cmd, [], { stdio: 'inherit', shell: true });
child.on('close', (code) => {
  process.exit(code ?? 1);
});