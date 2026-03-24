/**
 * CrabNebula Tauri Driver E2E Configuration
 *
 * Following official pattern from: https://docs.crabnebula.dev/plugins/tauri-e2e-tests/
 */

import path from 'path';
import { spawn } from 'child_process';
import { CrabNebulaCloudReporter } from '@crabnebula/webdriverio-cloud-reporter';
import { waitTauriDriverReady } from '@crabnebula/tauri-driver';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Platform-specific application path (using --no-bundle, binary is in target/debug/)
const applicationPath = process.platform === 'darwin'
  ? path.resolve(__dirname, 'src-tauri/target/debug/haipee')
  : process.platform === 'win32'
    ? path.resolve(__dirname, 'src-tauri/target/debug/haipee.exe')
    : path.resolve(__dirname, 'src-tauri/target/debug/haipee');

// Process tracking (global - only started once)
let tauriDriver: ReturnType<typeof spawn> | null = null;
let killedTauriDriver = false;
let testRunnerBackend: ReturnType<typeof spawn> | null = null;
let killedTestRunnerBackend = false;

export const config = {
  host: '127.0.0.1',
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
    // User journey tests
    './tests/e2e/crabnebula/user-journeys/*.spec.ts',
  ],

  maxInstances: 1,

  capabilities: [{
    maxInstances: 1,
    'tauri:options': {
      application: applicationPath,
    },
  }],

  reporters: [
    'spec',
    ...(process.env.CN_API_KEY ? [CrabNebulaCloudReporter] : []),
  ],
  framework: 'mocha',

  mochaOpts: {
    ui: 'bdd',
    timeout: 60000,
  },

  connectionRetryCount: 0,

  onPrepare: async () => {
    // macOS requires test-runner-backend with CN_API_KEY (must start BEFORE tauri-driver)
    if (process.platform === 'darwin') {
      if (!process.env.CN_API_KEY) {
        console.error('');
        console.error('⚠️  CN_API_KEY is required for CrabNebula Webdriver on macOS.');
        console.error('   The test-runner-backend process cannot start without it.');
        console.error('   Get your key at https://app.crabnebula.dev and set CN_API_KEY=<key>.');
        console.error('   Alternatively, run "bun run test:e2e:tauri" to use the webdriver fallback.');
        console.error('');
        throw new Error('CN_API_KEY required on macOS for CrabNebula driver');
      }

      const { waitTestRunnerBackendReady } = await import('@crabnebula/test-runner-backend');

      testRunnerBackend = spawn('bunx', ['test-runner-backend'], {
        stdio: 'inherit',
        shell: true,
      });

      testRunnerBackend.on('error', (error) => {
        console.error('test-runner-backend error:', error);
        process.exit(1);
      });

      testRunnerBackend.on('exit', (code) => {
        if (!killedTestRunnerBackend) {
          console.error('test-runner-backend exited with code:', code);
          process.exit(1);
        }
      });

      await waitTestRunnerBackendReady();

      // Instruct tauri-driver to connect to test-runner-backend (must be set BEFORE starting tauri-driver)
      process.env.REMOTE_WEBDRIVER_URL = 'http://127.0.0.1:3000';
    }

    // Start tauri-driver AFTER test-runner-backend is ready
    tauriDriver = spawn('bunx', ['tauri-driver'], {
      stdio: [null, process.stdout, process.stderr],
      shell: true,
    });

    tauriDriver.on('error', (error) => {
      console.error('tauri-driver error:', error);
      process.exit(1);
    });

    tauriDriver.on('exit', (code) => {
      if (!killedTauriDriver) {
        console.error('tauri-driver exited with code:', code);
        process.exit(1);
      }
    });

    // Wait for tauri-driver to initialize its proxy server
    await waitTauriDriverReady();
  },

  onComplete: () => {
    closeTauriDriver();
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