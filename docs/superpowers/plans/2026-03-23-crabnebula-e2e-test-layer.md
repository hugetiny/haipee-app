# CrabNebula E2E Test Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fully decoupled CrabNebula tauri-driver E2E test layer for evaluation during trial period.

**Architecture:** Separate Cargo feature `automation` for tauri-plugin-automation, standalone wdio.crabnebula.conf.ts, and independent tests/e2e/crabnebula/ directory with copied and adapted test files.

**Tech Stack:** Tauri v2, tauri-plugin-automation, @crabnebula/tauri-driver, @crabnebula/test-runner-backend, @crabnebula/webdriverio-cloud-reporter, WebdriverIO, Mocha

---

## File Structure

### Created Files
```
wdio.crabnebula.conf.ts                           # Standalone WDIO config
tests/e2e/crabnebula/pages/CrabNebulaBasePage.ts  # Base page object (simplified)
tests/e2e/crabnebula/pages/NavigationPage.ts      # Copied from tauri/
tests/e2e/crabnebula/pages/DashboardPage.ts       # Copied from tauri/
tests/e2e/crabnebula/pages/SettingsPage.ts        # Copied from tauri/
tests/e2e/crabnebula/pages/AgentConfigPage.ts     # Copied from tauri/
tests/e2e/crabnebula/pages/SessionManagerPage.ts  # Copied from tauri/
tests/e2e/crabnebula/pages/PromptsPage.ts         # Copied from tauri/
tests/e2e/crabnebula/pages/SkillsPage.ts          # Copied from tauri/
tests/e2e/crabnebula/pages/McpPage.ts             # Copied from tauri/
tests/e2e/crabnebula/pages/UniversalProviderPage.ts # Copied from tauri/
tests/e2e/crabnebula/pages/OpenClawChatPage.ts    # Copied from tauri/
tests/e2e/crabnebula/pages/OpenClawPages.ts       # Copied from tauri/
tests/e2e/crabnebula/pages/WebDavPage.ts          # Copied from tauri/
tests/e2e/crabnebula/pages/index.ts               # Exports
tests/e2e/crabnebula/utils/test-helpers.ts        # Copied from tauri/
tests/e2e/crabnebula/utils/data-manager.ts        # Copied from tauri/
tests/e2e/crabnebula/utils/external-deps.ts       # Copied from tauri/
tests/e2e/crabnebula/utils/index.ts               # Exports
tests/e2e/crabnebula/fixtures/providers.ts        # Copied from tauri/
tests/e2e/crabnebula/fixtures/index.ts            # Exports
tests/e2e/crabnebula/globals.d.ts                 # Type declarations
tests/e2e/crabnebula/providers/*.spec.ts          # 6 spec files
tests/e2e/crabnebula/settings/*.spec.ts           # 9 spec files
tests/e2e/crabnebula/agents/*.spec.ts             # 1 spec file
tests/e2e/crabnebula/skills/*.spec.ts             # 1 spec file
tests/e2e/crabnebula/mcp/*.spec.ts                # 1 spec file
tests/e2e/crabnebula/prompts/*.spec.ts            # 1 spec file
tests/e2e/crabnebula/sessions/*.spec.ts           # 1 spec file
tests/e2e/crabnebula/navigation/*.spec.ts         # 2 spec files
tests/e2e/crabnebula/openclaw/*.spec.ts           # 3 spec files
tests/e2e/crabnebula/universal/*.spec.ts          # 1 spec file
tests/e2e/crabnebula/errors/*.spec.ts             # 1 spec file
tests/e2e/crabnebula/workspace/*.spec.ts          # 1 spec file
tests/e2e/crabnebula/flows/*.spec.ts              # 4 spec files
tests/e2e/crabnebula/views/*.spec.ts              # 5 spec files
tests/e2e/crabnebula/channel-communication.spec.ts
```

### Modified Files
```
src-tauri/Cargo.toml:18-22                        # Add automation feature
src-tauri/src/lib.rs:199-207                      # Add automation plugin registration
package.json:18-19                                # Add npm scripts (after test:e2e:tauri)
```

---

## Task 1: Add Rust Automation Feature

**Files:**
- Modify: `src-tauri/Cargo.toml:18-22`
- Modify: `src-tauri/src/lib.rs:199-203`

- [ ] **Step 1: Add automation feature to Cargo.toml**

Edit `src-tauri/Cargo.toml` at line 21, add after `webdriver` feature:

```toml
[features]
default = []
test-hooks = []
webdriver = ["tauri-plugin-webdriver"]
automation = ["tauri-plugin-automation"]
```

- [ ] **Step 2: Add tauri-plugin-automation dependency**

Edit `src-tauri/Cargo.toml` at line 39, add after `tauri-plugin-webdriver`:

```toml
tauri-plugin-webdriver = { version = "0.2.1", optional = true }
tauri-plugin-automation = { version = "0.1", optional = true }
```

- [ ] **Step 3: Add automation plugin registration in lib.rs**

Edit `src-tauri/src/lib.rs` at line 203, add after the webdriver block:

```rust
    // Enable WebDriver endpoint for automated E2E testing (cargo build --features webdriver)
    #[cfg(feature = "webdriver")]
    {
        builder = builder.plugin(tauri_plugin_webdriver::init());
    }

    // CrabNebula automation plugin for E2E testing (cargo build --features automation)
    #[cfg(feature = "automation")]
    {
        builder = builder.plugin(tauri_plugin_automation::init());
    }
```

- [ ] **Step 4: Verify Rust compilation**

Run: `cargo check --manifest-path src-tauri/Cargo.toml --features automation`
Expected: Compilation succeeds without errors

- [ ] **Step 5: Commit Rust changes**

```bash
git add src-tauri/Cargo.toml src-tauri/src/lib.rs
git commit -m "feat(tauri): add automation feature for CrabNebula E2E tests"
```

---

## Task 2: Install NPM Dependencies

**Files:**
- Modify: `package.json` (via bun add)

- [ ] **Step 1: Install CrabNebula packages**

Run: `bun add -d @crabnebula/tauri-driver @crabnebula/test-runner-backend @crabnebula/webdriverio-cloud-reporter`
Expected: Packages added to devDependencies

- [ ] **Step 2: Verify installation**

Run: `bun pm ls | grep crabnebula`
Expected: Shows all three packages

- [ ] **Step 3: Commit package.json changes**

```bash
git add package.json bun.lock
git commit -m "chore: add CrabNebula E2E test dependencies"
```

---

## Task 3: Add Package.json Scripts

**Files:**
- Modify: `package.json:17-20`

- [ ] **Step 1: Add CrabNebula test scripts**

Edit `package.json` in the `scripts` section, add after `test:e2e:tauri`:

```json
    "test:e2e:tauri:build": "bunx cargo build --manifest-path src-tauri/Cargo.toml --features webdriver",
    "test:e2e:tauri": "bunx wdio run wdio.conf.ts",
    "test:e2e:crabnebula:build": "bunx cargo build --manifest-path src-tauri/Cargo.toml --features automation",
    "test:e2e:crabnebula": "bunx wdio run wdio.crabnebula.conf.ts",
```

- [ ] **Step 2: Commit script changes**

```bash
git add package.json
git commit -m "chore: add CrabNebula E2E test scripts"
```

---

## Task 4: Create WDIO Configuration

**Files:**
- Create: `wdio.crabnebula.conf.ts`

- [ ] **Step 1: Create wdio.crabnebula.conf.ts**

Create `wdio.crabnebula.conf.ts` at project root:

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

- [ ] **Step 2: Commit config file**

```bash
git add wdio.crabnebula.conf.ts
git commit -m "feat(e2e): add CrabNebula WDIO configuration"
```

---

## Task 5: Create CrabNebula Base Page Object

**Files:**
- Create: `tests/e2e/crabnebula/pages/CrabNebulaBasePage.ts`

- [ ] **Step 1: Create directory structure**

Run: `mkdir -p tests/e2e/crabnebula/pages tests/e2e/crabnebula/utils tests/e2e/crabnebula/fixtures`

- [ ] **Step 2: Create CrabNebulaBasePage.ts**

Create `tests/e2e/crabnebula/pages/CrabNebulaBasePage.ts`:

```typescript
/**
 * CrabNebulaBasePage - Base page object for CrabNebula WebDriver tests
 *
 * Simplified compared to TauriBasePage - CrabNebula WebDriver is more standard.
 * No :has-text() workarounds needed, isDisplayed() works correctly.
 */

/// <reference types="@wdio/globals/types" />

export abstract class CrabNebulaBasePage {
  /**
   * Wait for React to render
   */
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

  /**
   * Call a Tauri IPC command
   */
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

  /**
   * Navigate to a section by clicking sidebar
   */
  async navigateTo(section: string): Promise<void> {
    await this.waitForReactReady();

    const selectors = [
      `button[aria-label*="${section}"]`,
      `[data-testid="${section.toLowerCase()}"]`,
    ];

    for (const selector of selectors) {
      try {
        const button = await $(selector);
        if (await button.isExisting()) {
          await button.waitForClickable({ timeout: 5000 });
          await button.click();
          await browser.pause(500);
          return;
        }
      } catch {
        // Try next selector
      }
    }

    console.log(`Navigation to "${section}" - no button found, may already be on page`);
  }

  /**
   * Wait for toast notification
   */
  async waitForToast(timeout = 5000): Promise<string | null> {
    try {
      const toast = await $('[data-sonner-toast], [role="status"]');
      await toast.waitForExist({ timeout });
      return toast.getText();
    } catch {
      return null;
    }
  }

  /**
   * Take a named screenshot
   */
  async screenshot(name: string): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    await browser.saveScreenshot(`./ai-loop-logs/screenshots/crabnebula-${name}-${timestamp}.png`);
  }

  /**
   * Wait for loading to complete
   */
  async waitForLoadingComplete(timeout = 10_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const loader = await $('[data-testid="loading"], .animate-spin');
        const exists = await loader.isExisting();
        return !exists;
      },
      { timeout, timeoutMsg: 'Loading did not complete' }
    );
  }

  /**
   * Get page title
   */
  async getTitle(): Promise<string> {
    return browser.getTitle();
  }

  /**
   * Check if element exists
   */
  async elementExists(selector: string): Promise<boolean> {
    const el = await $(selector);
    return el.isExisting();
  }

  /**
   * Get text content of element
   */
  async getText(selector: string): Promise<string> {
    const el = await $(selector);
    return el.getText();
  }

  /**
   * Click element with retry
   */
  async clickWithRetry(selector: string, maxRetries = 3): Promise<void> {
    for (let i = 0; i < maxRetries; i++) {
      try {
        const el = await $(selector);
        await el.waitForClickable({ timeout: 5000 });
        await el.click();
        return;
      } catch (err) {
        if (i === maxRetries - 1) throw err;
        await browser.pause(500);
      }
    }
  }

  /**
   * Check if current page has specific heading
   */
  async hasHeading(text: string): Promise<boolean> {
    return browser.execute((searchText) => {
      const headings = document.querySelectorAll('h1, h2, h3');
      for (const h of headings) {
        if (h.textContent?.includes(searchText)) {
          return true;
        }
      }
      return false;
    }, text);
  }

  /**
   * Wait for element to appear with retry
   */
  async waitForElement(selector: string, timeout = 10_000) {
    const el = await $(selector);
    await el.waitForExist({ timeout });
    return el;
  }

  /**
   * Wait for element to be clickable
   */
  async waitForClickable(selector: string, timeout = 10_000) {
    const el = await $(selector);
    await el.waitForClickable({ timeout });
    return el;
  }

  /**
   * Safe click - wait for element then click
   */
  async safeClick(selector: string): Promise<void> {
    const el = await this.waitForClickable(selector);
    await el.click();
  }

  /**
   * Input text - clear then type
   */
  async inputText(selector: string, text: string): Promise<void> {
    const el = await this.waitForElement(selector);
    await el.clearValue();
    await el.addValue(text);
  }

  /**
   * Wait for API request to complete (no loading spinners)
   */
  async waitForApiComplete(timeout = 30_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const spinners = await $$('[data-testid="loading"], .animate-spin, [aria-busy="true"]');
        const count = await spinners.length;
        return count === 0;
      },
      { timeout, timeoutMsg: 'API request did not complete' }
    );
  }

  /**
   * Wait for text to appear in element
   */
  async waitForText(selector: string, text: string, timeout = 10_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const el = await $(selector);
        const content = await el.getText();
        return content.includes(text);
      },
      { timeout, timeoutMsg: `Text "${text}" did not appear` }
    );
  }

  /**
   * Get all elements matching selector
   */
  async getElements(selector: string) {
    return $$(selector);
  }

  /**
   * Find element by data-testid attribute
   */
  async findByTestId(testId: string) {
    return $(`[data-testid="${testId}"]`);
  }

  /**
   * Check if element is visible
   * CrabNebula WebDriver properly supports isDisplayed()
   */
  async isElementVisible(selector: string): Promise<boolean> {
    const el = await $(selector);
    const exists = await el.isExisting();
    if (!exists) return false;
    return el.isDisplayed();
  }

  /**
   * Click element by tag and text content
   */
  async clickByText(tag: string, text: string): Promise<void> {
    const elements = await $$(tag);
    for (const el of elements) {
      const elText = await el.getText();
      if (elText.includes(text)) {
        await el.click();
        return;
      }
    }
    throw new Error(`Element <${tag}> containing "${text}" not found`);
  }

  /**
   * Navigate to a specific view/tab
   */
  async navigateToView(view: string): Promise<void> {
    await this.waitForReactReady();

    const viewMap: Record<string, string> = {
      providers: 'providers',
      settings: 'settings',
      sessions: 'sessions',
      prompts: 'prompts',
      skills: 'skills',
      mcp: 'mcp',
      agents: 'agents',
      openclaw: 'openclaw',
      universal: 'universal',
    };

    const testId = viewMap[view.toLowerCase()] || view.toLowerCase();
    const navItem = await $(`[data-testid="nav-${testId}"], button[aria-label*="${view}"]`);

    if (await navItem.isExisting()) {
      await navItem.click();
      await browser.pause(500);
    }
  }
}
```

- [ ] **Step 3: Commit base page**

```bash
git add tests/e2e/crabnebula/pages/CrabNebulaBasePage.ts
git commit -m "feat(e2e): add CrabNebulaBasePage"
```

---

## Task 6: Copy Page Objects from Tauri Tests

**Files:**
- Create: `tests/e2e/crabnebula/pages/*.ts` (13 files)

- [ ] **Step 1: Copy and adapt DashboardPage.ts**

Copy `tests/e2e/tauri/pages/DashboardPage.ts` to `tests/e2e/crabnebula/pages/DashboardPage.ts`, then:
- Change `extends TauriBasePage` to `extends CrabNebulaBasePage`
- Change import from `'./TauriBasePage'` to `'./CrabNebulaBasePage'`

- [ ] **Step 2: Copy and adapt NavigationPage.ts**

Copy `tests/e2e/tauri/pages/NavigationPage.ts` to `tests/e2e/crabnebula/pages/NavigationPage.ts`, adapt imports.

- [ ] **Step 3: Copy and adapt remaining page objects**

For each file listed below, copy from `tests/e2e/tauri/pages/` to `tests/e2e/crabnebula/pages/`:
- SettingsPage.ts
- AgentConfigPage.ts
- SessionManagerPage.ts
- PromptsPage.ts
- SkillsPage.ts
- McpPage.ts
- UniversalProviderPage.ts
- OpenClawChatPage.ts
- OpenClawPages.ts
- WebDavPage.ts

For each copied file:
1. Update import: `import { TauriBasePage } from './TauriBasePage'` → `import { CrabNebulaBasePage } from './CrabNebulaBasePage'`
2. Change all `extends TauriBasePage` to `extends CrabNebulaBasePage`

- [ ] **Step 4: Create pages/index.ts**

Create `tests/e2e/crabnebula/pages/index.ts`:

```typescript
/**
 * Page Object Models for CrabNebula E2E Tests
 */

export { CrabNebulaBasePage } from './CrabNebulaBasePage.ts';
export { DashboardPage, dashboardPage } from './DashboardPage.ts';
export { SettingsPage, settingsPage } from './SettingsPage.ts';
export { NavigationPage, navigationPage } from './NavigationPage.ts';
export { OpenClawChatPage, openClawChatPage } from './OpenClawChatPage.ts';
export {
  OpenClawGatewayPage,
  OpenClawChannelsPage,
  OpenClawSkillsMcpPage,
  openClawGatewayPage,
  openClawChannelsPage,
  openClawSkillsMcpPage,
} from './OpenClawPages.ts';
export { UniversalProviderPage, universalProviderPage } from './UniversalProviderPage.ts';
export { AgentConfigPage, agentConfigPage } from './AgentConfigPage.ts';
export { SessionManagerPage } from './SessionManagerPage.ts';
export { McpPage, mcpPage } from './McpPage.ts';
export { PromptsPage, promptsPage } from './PromptsPage.ts';
export { SkillsPage, skillsPage } from './SkillsPage.ts';
export { WebDavPage, webDavPage } from './WebDavPage.ts';

// Type exports
export type { ProviderFormData } from './DashboardPage.ts';
export type { AppSection } from './NavigationPage.ts';
export type { AgentId, ConfigTab } from './AgentConfigPage.ts';
export type { McpServerFormData, AppId } from './McpPage.ts';
export type { PromptFormData } from './PromptsPage.ts';
export type { SkillFormData } from './SkillsPage.ts';
export type { UniversalProviderData } from './UniversalProviderPage.ts';
```

- [ ] **Step 5: Commit page objects**

```bash
git add tests/e2e/crabnebula/pages/
git commit -m "feat(e2e): add CrabNebula page objects"
```

---

## Task 7: Copy Utilities and Fixtures

**Files:**
- Create: `tests/e2e/crabnebula/utils/*.ts`
- Create: `tests/e2e/crabnebula/fixtures/*.ts`

- [ ] **Step 1: Copy utility files**

```bash
cp tests/e2e/tauri/utils/test-helpers.ts tests/e2e/crabnebula/utils/
cp tests/e2e/tauri/utils/data-manager.ts tests/e2e/crabnebula/utils/
cp tests/e2e/tauri/utils/external-deps.ts tests/e2e/crabnebula/utils/
```

- [ ] **Step 2: Create utils/index.ts**

```typescript
/**
 * Test Utilities Index
 */

export * from './test-helpers';
export * from './data-manager';
export * from './external-deps';
```

- [ ] **Step 3: Copy fixture files**

```bash
cp tests/e2e/tauri/fixtures/providers.ts tests/e2e/crabnebula/fixtures/
```

- [ ] **Step 4: Create fixtures/index.ts**

```typescript
/**
 * Test Fixtures - Main Export
 */

export {
  createTestProvider,
  createTestProviders,
  createTestSession,
  createTestMcpServer,
  createTestSkill,
  createTestPrompt,
  createTestChannel,
  FIXTURE_PROVIDERS,
} from './providers';

export type {
  TestProvider,
  TestSession,
  TestMcpServer,
  TestSkill,
  TestPrompt,
  TestChannel,
} from './providers';
```

- [ ] **Step 5: Commit utilities and fixtures**

```bash
git add tests/e2e/crabnebula/utils/ tests/e2e/crabnebula/fixtures/
git commit -m "feat(e2e): add CrabNebula test utilities and fixtures"
```

---

## Task 8: Create globals.d.ts

**Files:**
- Create: `tests/e2e/crabnebula/globals.d.ts`

- [ ] **Step 1: Create globals.d.ts**

```typescript
/// <reference types="@wdio/globals/types" />

declare global {
  namespace WebdriverIO {
    interface Browser {
      execute<T>(script: string, ...args: any[]): T;
      execute<T>(script: (...args: any[]) => T, ...args: any[]): T;
    }
  }
}

export {};
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e/crabnebula/globals.d.ts
git commit -m "feat(e2e): add CrabNebula test type declarations"
```

---

## Task 9: Copy Spec Files (Providers)

**Files:**
- Create: `tests/e2e/crabnebula/providers/*.spec.ts` (6 files)

- [ ] **Step 1: Create providers directory and copy specs**

```bash
mkdir -p tests/e2e/crabnebula/providers
cp tests/e2e/tauri/providers/provider-list.spec.ts tests/e2e/crabnebula/providers/
cp tests/e2e/tauri/providers/provider-crud.spec.ts tests/e2e/crabnebula/providers/
cp tests/e2e/tauri/providers/provider-actions.spec.ts tests/e2e/crabnebula/providers/
cp tests/e2e/tauri/providers/provider-switch.spec.ts tests/e2e/crabnebula/providers/
cp tests/e2e/tauri/providers/provider-advanced.spec.ts tests/e2e/crabnebula/providers/
cp tests/e2e/tauri/providers/provider-failover.spec.ts tests/e2e/crabnebula/providers/
```

- [ ] **Step 2: Verify imports resolve correctly**

Since spec files are copied to the same relative location within `tests/e2e/crabnebula/`, import paths like `'../pages'` will correctly resolve to the crabnebula pages directory. No import changes needed.

- [ ] **Step 3: Commit providers specs**

```bash
git add tests/e2e/crabnebula/providers/
git commit -m "feat(e2e): add CrabNebula provider test specs"
```

---

## Task 10: Copy Spec Files (Settings)

**Files:**
- Create: `tests/e2e/crabnebula/settings/*.spec.ts` (9 files)

- [ ] **Step 1: Create settings directory and copy specs**

```bash
mkdir -p tests/e2e/crabnebula/settings
cp tests/e2e/tauri/settings/settings-general.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-proxy.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-auth.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-advanced.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-usage.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-about.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-webdav.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-env.spec.ts tests/e2e/crabnebula/settings/
cp tests/e2e/tauri/settings/settings-global-proxy.spec.ts tests/e2e/crabnebula/settings/
```

- [ ] **Step 2: Commit settings specs**

```bash
git add tests/e2e/crabnebula/settings/
git commit -m "feat(e2e): add CrabNebula settings test specs"
```

---

## Task 11: Copy Remaining Spec Files

**Files:**
- Create: All remaining spec files in tests/e2e/crabnebula/

- [ ] **Step 1: Create directories and copy specs**

```bash
# Single-file modules
mkdir -p tests/e2e/crabnebula/agents
cp tests/e2e/tauri/agents/agent-common.spec.ts tests/e2e/crabnebula/agents/

mkdir -p tests/e2e/crabnebula/skills
cp tests/e2e/tauri/skills/skills-list.spec.ts tests/e2e/crabnebula/skills/

mkdir -p tests/e2e/crabnebula/mcp
cp tests/e2e/tauri/mcp/mcp-servers.spec.ts tests/e2e/crabnebula/mcp/

mkdir -p tests/e2e/crabnebula/prompts
cp tests/e2e/tauri/prompts/prompts-crud.spec.ts tests/e2e/crabnebula/prompts/

mkdir -p tests/e2e/crabnebula/sessions
cp tests/e2e/tauri/sessions/sessions-management.spec.ts tests/e2e/crabnebula/sessions/

mkdir -p tests/e2e/crabnebula/universal
cp tests/e2e/tauri/universal/universal-provider.spec.ts tests/e2e/crabnebula/universal/

mkdir -p tests/e2e/crabnebula/errors
cp tests/e2e/tauri/errors/error-handling.spec.ts tests/e2e/crabnebula/errors/

mkdir -p tests/e2e/crabnebula/workspace
cp tests/e2e/tauri/workspace/workspace-management.spec.ts tests/e2e/crabnebula/workspace/

# Multi-file modules
mkdir -p tests/e2e/crabnebula/navigation
cp tests/e2e/tauri/navigation/navigation.spec.ts tests/e2e/crabnebula/navigation/
cp tests/e2e/tauri/navigation/deeplink-import.spec.ts tests/e2e/crabnebula/navigation/

mkdir -p tests/e2e/crabnebula/openclaw
cp tests/e2e/tauri/openclaw/openclaw-gateway.spec.ts tests/e2e/crabnebula/openclaw/
cp tests/e2e/tauri/openclaw/openclaw-channels.spec.ts tests/e2e/crabnebula/openclaw/
cp tests/e2e/tauri/openclaw/openclaw-messaging.spec.ts tests/e2e/crabnebula/openclaw/

# Legacy tests
mkdir -p tests/e2e/crabnebula/flows
cp tests/e2e/tauri/flows/session-management.spec.ts tests/e2e/crabnebula/flows/
cp tests/e2e/tauri/flows/app-switching.spec.ts tests/e2e/crabnebula/flows/
cp tests/e2e/tauri/flows/provider-lifecycle.spec.ts tests/e2e/crabnebula/flows/
cp tests/e2e/tauri/flows/mcp-skill-integration.spec.ts tests/e2e/crabnebula/flows/

mkdir -p tests/e2e/crabnebula/views
cp tests/e2e/tauri/views/sessions-view.spec.ts tests/e2e/crabnebula/views/
cp tests/e2e/tauri/views/prompts-view.spec.ts tests/e2e/crabnebula/views/
cp tests/e2e/tauri/views/skills-view.spec.ts tests/e2e/crabnebula/views/
cp tests/e2e/tauri/views/mcp-view.spec.ts tests/e2e/crabnebula/views/
cp tests/e2e/tauri/views/providers-view.spec.ts tests/e2e/crabnebula/views/

# Channel communication
cp tests/e2e/tauri/channel-communication.spec.ts tests/e2e/crabnebula/
```

- [ ] **Step 2: Commit all remaining specs**

```bash
git add tests/e2e/crabnebula/
git commit -m "feat(e2e): add remaining CrabNebula test specs"
```

---

## Task 12: Verify Test Discovery

**Files:**
- None (verification only)

- [ ] **Step 1: Verify spec file count**

Run: `find tests/e2e/crabnebula -name "*.spec.ts" | wc -l`
Expected: 30+ spec files

- [ ] **Step 2: Verify WDIO config is valid**

Run: `bun -e "import('./wdio.crabnebula.conf.ts').then(c => console.log('Config valid:', !!c.config))"`
Expected: `Config valid: true`

- [ ] **Step 3: Final commit summary**

```bash
git status
git log --oneline -10
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add Rust automation feature | 2 |
| 2 | Install NPM dependencies | 1 |
| 3 | Add package.json scripts | 1 |
| 4 | Create WDIO config | 1 |
| 5 | Create base page object | 1 |
| 6 | Copy page objects | 14 |
| 7 | Copy utilities/fixtures | 6 |
| 8 | Create type declarations | 1 |
| 9 | Copy provider specs | 6 |
| 10 | Copy settings specs | 9 |
| 11 | Copy remaining specs | 20+ |
| 12 | Verify test discovery | 0 |

**Total:** ~60 files created/modified

---

## Running the Tests

```bash
# Set API key (macOS only)
export CN_API_KEY="your-api-key"

# Build with automation feature
bun run test:e2e:crabnebula:build

# Run tests
bun run test:e2e:crabnebula
```

---

## Cleanup (When Trial Ends)

See the spec document `docs/superpowers/specs/2026-03-23-crabnebula-e2e-test-layer-design.md` for detailed deletion instructions. Summary:

```bash
rm -rf tests/e2e/crabnebula/
rm wdio.crabnebula.conf.ts
bun remove @crabnebula/tauri-driver @crabnebula/test-runner-backend @crabnebula/webdriverio-cloud-reporter
# Remove automation feature from Cargo.toml and lib.rs
```

No impact on existing `tests/e2e/tauri/` or `wdio.conf.ts`.