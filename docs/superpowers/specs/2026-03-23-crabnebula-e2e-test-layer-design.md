---
name: CrabNebula E2E Test Layer
description: Add decoupled CrabNebula tauri-driver E2E test layer for evaluation
type: project
---

# CrabNebula E2E Test Layer Design

**Date:** 2026-03-23
**Status:** Design Complete, Pending Implementation
**Scope:** Add a parallel E2E test layer using CrabNebula's tauri-driver, fully decoupled from the existing tauri-plugin-webdriver setup.

## Why: Evaluate During Trial Period

**Motivation:**
1. Better reliability - Current WKWebView WebDriver has quirks (isDisplayed issues, :has-text() workarounds)
2. Cloud reporting - Test results uploaded to CrabNebula Cloud for visibility
3. Cross-platform consistency - CrabNebula normalizes behavior across macOS/Linux/Windows
4. Evaluation - Explore during trial, may discontinue later

**How to apply:** When trial ends, delete the entire `tests/e2e/crabnebula/` directory, remove the Cargo feature, and uninstall npm packages. No impact on existing tests.

---

## Architecture Comparison

| Aspect | Current (tauri-plugin-webdriver) | CrabNebula (tauri-driver) |
|--------|----------------------------------|---------------------------|
| WebDriver server | Built into app (port 4445) | External process `tauri-driver` (port 4444) |
| Rust plugin | `tauri-plugin-webdriver` | `tauri-plugin-automation` |
| macOS auth | `safaridriver --enable` (free) | `CN_API_KEY` (subscription) |
| Linux | WRY WebView (WebKitGTK) | webkit2gtk-driver or CrabNebula Webdriver |
| Windows | WRY WebView | msedgedriver or CrabNebula Webdriver |
| Capabilities | `{ browserName: 'wry' }` | `{ "tauri:options": { application } }` |
| App lifecycle | Managed by test setup | Managed by tauri-driver |

---

## Directory Structure (Fully Decoupled)

```
tests/e2e/crabnebula/
├── pages/                    # Copied & adapted page objects
│   ├── CrabNebulaBasePage.ts # Adapted for CrabNebula WebDriver
│   ├── NavigationPage.ts
│   ├── DashboardPage.ts
│   ├── SettingsPage.ts
│   ├── AgentConfigPage.ts
│   ├── SessionManagerPage.ts
│   ├── PromptsPage.ts
│   ├── SkillsPage.ts
│   ├── McpPage.ts
│   ├── UniversalProviderPage.ts
│   ├── OpenClawChatPage.ts
│   ├── OpenClawPages.ts
│   ├── WebDavPage.ts
│   └── index.ts
├── utils/                    # Copied utilities
│   ├── test-helpers.ts
│   ├── data-manager.ts
│   ├── external-deps.ts
│   └── index.ts
├── fixtures/                 # Copied test fixtures
│   ├── providers.ts
│   └── index.ts
├── providers/                # Spec files (mirror tauri/)
│   ├── provider-list.spec.ts
│   ├── provider-crud.spec.ts
│   ├── provider-actions.spec.ts
│   ├── provider-switch.spec.ts
│   ├── provider-advanced.spec.ts
│   └── provider-failover.spec.ts
├── settings/
│   ├── settings-general.spec.ts
│   ├── settings-proxy.spec.ts
│   ├── settings-auth.spec.ts
│   ├── settings-advanced.spec.ts
│   ├── settings-usage.spec.ts
│   ├── settings-about.spec.ts
│   ├── settings-webdav.spec.ts
│   ├── settings-env.spec.ts
│   └── settings-global-proxy.spec.ts
├── agents/
│   └── agent-common.spec.ts
├── skills/
│   └── skills-list.spec.ts
├── mcp/
│   └── mcp-servers.spec.ts
├── prompts/
│   └── prompts-crud.spec.ts
├── sessions/
│   └── sessions-management.spec.ts
├── navigation/
│   ├── navigation.spec.ts
│   └── deeplink-import.spec.ts
├── openclaw/
│   ├── openclaw-gateway.spec.ts
│   ├── openclaw-channels.spec.ts
│   └── openclaw-messaging.spec.ts
├── universal/
│   └── universal-provider.spec.ts
├── errors/
│   └── error-handling.spec.ts
├── workspace/
│   └── workspace-management.spec.ts
├── flows/                    # Legacy tests
│   ├── session-management.spec.ts
│   ├── app-switching.spec.ts
│   ├── provider-lifecycle.spec.ts
│   └── mcp-skill-integration.spec.ts
├── views/                    # Legacy tests
│   ├── sessions-view.spec.ts
│   ├── prompts-view.spec.ts
│   ├── skills-view.spec.ts
│   ├── mcp-view.spec.ts
│   └── providers-view.spec.ts
├── channel-communication.spec.ts
└── globals.d.ts

wdio.crabnebula.conf.ts       # Standalone config, NO imports from wdio.conf.ts
```

**Total:** ~38 spec files, ~343 tests (full mirror of existing)

---

## Rust Changes (src-tauri/)

### Cargo.toml

```toml
[features]
webdriver = ["tauri-plugin-webdriver"]      # Existing - keep unchanged
automation = ["tauri-plugin-automation"]    # New - CrabNebula only
test-hooks = []                              # Existing - keep unchanged

[dependencies]
tauri-plugin-automation = { version = "0.1", optional = true }
```

### lib.rs

```rust
// Existing webdriver feature (unchanged)
#[cfg(feature = "webdriver")]
builder = builder.plugin(tauri_plugin_webdriver::init());

// New: CrabNebula automation feature
#[cfg(feature = "automation")]
builder = builder.plugin(tauri_plugin_automation::init());
```

**Important:** Both features are mutually exclusive at build time. Never enable both.

---

## NPM Dependencies

```bash
bun add -d @crabnebula/tauri-driver @crabnebula/test-runner-backend @crabnebula/webdriverio-cloud-reporter
```

### package.json Scripts

```json
{
  "scripts": {
    "test:e2e:crabnebula:build": "bunx cargo build --manifest-path src-tauri/Cargo.toml --features automation",
    "test:e2e:crabnebula": "bunx wdio run wdio.crabnebula.conf.ts"
  }
}
```

---

## wdio.crabnebula.conf.ts (Full Implementation)

```typescript
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
```

---

## CrabNebulaBasePage.ts

Key differences from `TauriBasePage.ts`:

1. **No `:has-text()` workaround needed** - CrabNebula WebDriver properly supports it
2. **`isDisplayed()` works correctly** - No need for CSS property checking workaround
3. **Direct element interaction** - More reliable element finding and clicking

```typescript
/**
 * CrabNebulaBasePage - Base page object for CrabNebula WebDriver tests
 *
 * Simplified compared to TauriBasePage - CrabNebula WebDriver is more standard.
 */
export abstract class CrabNebulaBasePage {
  async waitForReactReady(timeout = 10_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const childCount = await browser.execute(() =>
          document.getElementById('root')?.childElementCount ?? 0,
        );
        return childCount > 0;
      },
      { timeout, timeoutMsg: 'React did not render within timeout' }
    );
  }

  async invokeIPC<T = unknown>(command: string, args?: Record<string, unknown>): Promise<T> {
    return browser.execute(
      async (cmd, cmdArgs) => {
        const { invoke } = (window as any).__TAURI__.core;
        return invoke(cmd, cmdArgs);
      },
      command,
      args ?? {}
    );
  }

  async findByTestId(testId: string) {
    return $(`[data-testid="${testId}"]`);
  }

  async safeClick(selector: string): Promise<void> {
    const el = await $(selector);
    await el.waitForClickable({ timeout: 10_000 });
    await el.click();
  }

  async inputText(selector: string, text: string): Promise<void> {
    const el = await $(selector);
    await el.waitForExist({ timeout: 10_000 });
    await el.clearValue();
    await el.addValue(text);
  }

  async elementExists(selector: string): Promise<boolean> {
    const el = await $(selector);
    return el.isExisting();
  }

  async getText(selector: string): Promise<string> {
    const el = await $(selector);
    return el.getText();
  }

  async screenshot(name: string): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    await browser.saveScreenshot(`./ai-loop-logs/screenshots/crabnebula-${name}-${timestamp}.png`);
  }
}
```

---

## Deletion Path (When Trial Ends)

```bash
# 1. Remove test directory
rm -rf tests/e2e/crabnebula/

# 2. Remove config file
rm wdio.crabnebula.conf.ts

# 3. Remove Cargo feature and dependency
# Edit src-tauri/Cargo.toml:
#   - Remove `automation = ["tauri-plugin-automation"]` from [features]
#   - Remove `tauri-plugin-automation` from [dependencies]

# 4. Remove Rust plugin registration
# Edit src-tauri/src/lib.rs:
#   - Remove the `#[cfg(feature = "automation")]` block

# 5. Uninstall npm packages
bun remove @crabnebula/tauri-driver @crabnebula/test-runner-backend @crabnebula/webdriverio-cloud-reporter

# 6. Remove package.json scripts
# Edit package.json:
#   - Remove `test:e2e:crabnebula:build`
#   - Remove `test:e2e:crabnebula`
```

No impact on existing `tests/e2e/tauri/` or `wdio.conf.ts`.

---

## Running Tests

### Build and run CrabNebula tests (macOS with CN_API_KEY)

```bash
# Set API key (macOS only)
export CN_API_KEY="your-api-key"

# Build with automation feature
bun run test:e2e:crabnebula:build

# Run tests
bun run test:e2e:crabnebula
```

### Run existing tests (unchanged)

```bash
bun run test:e2e:tauri:build
bun run test:e2e:tauri
```

---

## Expected Benefits

1. **Reliability** - No WKWebView-specific workarounds needed
2. **Cloud Reporting** - Automatic test result upload to CrabNebula Cloud
3. **Cross-platform** - Consistent behavior on macOS/Linux/Windows
4. **Isolation** - Zero coupling with existing test infrastructure