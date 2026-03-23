/**
 * CrabNebula Tauri Driver E2E Configuration
 *
 * Fully decoupled from wdio.conf.ts - no imports, no shared code.
 * Delete this file and tests/e2e/crabnebula/ when trial ends.
 */

import path from 'path';
import { spawn, spawnSync } from 'child_process';
import { CrabNebulaCloudReporter } from '@crabnebula/webdriverio-cloud-reporter';
import { waitTauriDriverReady } from '@crabnebula/tauri-driver';
import { waitTestRunnerBackendReady } from '@crabnebula/test-runner-backend';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Platform-specific application path
const applicationPath = process.platform === 'darwin'
  ? path.resolve(__dirname, 'src-tauri/target/debug/bundle/macos/haipee.app')
  : process.platform === 'win32'
    ? path.resolve(__dirname, 'src-tauri/target/debug/haipee.exe')
    : path.resolve(__dirname, 'src-tauri/target/debug/haipee');

// Process tracking
let tauriDriver: ReturnType<typeof spawn> | null = null;
let killedTauriDriver = false;
let testRunnerBackend: ReturnType<typeof spawn> | null = null;
let killedTestRunnerBackend = false;

export const config = {
  runner: 'local',
  hostname: '127.0.0.1',
  port: 4444,

  specs: [
    './tests/e2e/crabnebula/providers/*.spec.ts',
    './tests/e2e/crabnebula/settings/*.spec.ts',
    './tests/e2e/crabnebula/agents/*.spec.ts',
    './tests/e2e/crabnebula/skills/*.spec.ts',
    './tests/e2e/crabnebula/mcp/*.spec.ts',
    './tests/e2e/crabnebula/prompts/*.spec.ts',
    './tests/e2e/crabnebula/sessions/*.spec.ts',
    './tests/e2e/crabnebula/navigation/*.spec.ts',
    './tests/e2e/crabnebula/openclaw/*.spec.ts',
    './tests/e2e/crabnebula/universal/*.spec.ts',
    './tests/e2e/crabnebula/errors/*.spec.ts',
    './tests/e2e/crabnebula/workspace/*.spec.ts',
    './tests/e2e/crabnebula/flows/*.spec.ts',
    './tests/e2e/crabnebula/views/*.spec.ts',
    './tests/e2e/crabnebula/channel-communication.spec.ts',
  ],

  maxInstances: 1,

  capabilities: [{
    maxInstances: 1,
    'tauri:options': {
      application: applicationPath,
    },
  }],

  logLevel: 'warn',
  bail: 0,
  waitforTimeout: 15_000,
  connectionRetryTimeout: 180_000,
  connectionRetryCount: 5,

  framework: 'mocha',
  reporters: [CrabNebulaCloudReporter],

  mochaOpts: {
    ui: 'bdd',
    timeout: 90_000,
  },

  // Build app and start test-runner-backend (macOS only)
  onPrepare: async () => {
    console.log('[crabnebula] Building Tauri app with automation feature...');

    // Build with automation feature
    spawnSync('bunx', ['cargo', 'build', '--manifest-path', 'src-tauri/Cargo.toml', '--features', 'automation'], {
      cwd: path.resolve(__dirname),
      stdio: 'inherit',
      shell: true,
    });

    // macOS: start test-runner-backend (requires CN_API_KEY)
    if (process.platform === 'darwin') {
      if (!process.env.CN_API_KEY) {
        console.error('[crabnebula] CN_API_KEY is not set, required for macOS tests');
        console.error('[crabnebula] Get your API key from CrabNebula Cloud');
        process.exit(1);
      }

      console.log('[crabnebula] Starting test-runner-backend...');
      testRunnerBackend = spawn('bunx', ['test-runner-backend'], {
        stdio: 'inherit',
        shell: true,
      });

      testRunnerBackend.on('error', (error) => {
        console.error('[crabnebula] test-runner-backend error:', error);
        process.exit(1);
      });

      testRunnerBackend.on('exit', (code) => {
        if (!killedTestRunnerBackend) {
          console.error('[crabnebula] test-runner-backend exited with code:', code);
          process.exit(1);
        }
      });

      await waitTestRunnerBackendReady();

      // Instruct tauri-driver to connect to test-runner-backend
      process.env.REMOTE_WEBDRIVER_URL = 'http://127.0.0.1:3000';
    }
  },

  // Start tauri-driver proxy
  beforeSession: async () => {
    console.log('[crabnebula] Starting tauri-driver...');

    tauriDriver = spawn('bunx', ['tauri-driver'], {
      stdio: [null, process.stdout, process.stderr],
      shell: true,
    });

    tauriDriver.on('error', (error) => {
      console.error('[crabnebula] tauri-driver error:', error);
      process.exit(1);
    });

    tauriDriver.on('exit', (code) => {
      if (!killedTauriDriver) {
        console.error('[crabnebula] tauri-driver exited with code:', code);
        process.exit(1);
      }
    });

    // Wait for tauri-driver to initialize its proxy server
    await waitTauriDriverReady();
    console.log('[crabnebula] tauri-driver ready');
  },

  // Wait for React to render
  before: async () => {
    console.log('[crabnebula] Waiting for React to render...');
    await browser.waitUntil(
      async () => {
        const count = await browser.execute(() =>
          document.getElementById('root')?.childElementCount ?? 0,
        );
        return count > 0;
      },
      { timeout: 30_000, timeoutMsg: 'React did not render within 30s' }
    );
    console.log('[crabnebula] React rendered successfully');
  },

  afterSession: () => {
    closeTauriDriver();
  },

  onComplete: () => {
    killedTestRunnerBackend = true;
    testRunnerBackend?.kill();
    console.log('[crabnebula] Test run complete');
  },
};

function closeTauriDriver() {
  killedTauriDriver = true;
  tauriDriver?.kill();
  killedTestRunnerBackend = true;
  testRunnerBackend?.kill();
}

// Graceful shutdown on all signals
function onShutdown(fn: () => void) {
  const cleanup = () => {
    try {
      fn();
    } finally {
      process.exit();
    }
  };
  process.on('exit', cleanup);
  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);
  process.on('SIGHUP', cleanup);
  process.on('SIGBREAK', cleanup);
}

onShutdown(closeTauriDriver);