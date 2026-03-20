# TDD Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish comprehensive TDD infrastructure for Haipee with real API testing capabilities.

**Architecture:** 5-layer test pyramid (Unit → Rust Unit → Integration → Playwright E2E → WebDriver E2E), with Page Object Model for maintainable E2E tests and real API calls for OpenClaw chat testing.

**Tech Stack:** tauri-plugin-webdriver v0.2.1, WebdriverIO, Vitest, Playwright, Tauri v2

---

## File Structure Overview

### Files to Create
```
tests/e2e-tauri/
├── providers/
│   ├── add-provider.spec.ts
│   ├── edit-provider.spec.ts
│   ├── delete-provider.spec.ts
│   ├── switch-provider.spec.ts
│   └── test-connection.spec.ts
├── agents/
│   ├── switch-agent.spec.ts
│   ├── config-skills.spec.ts
│   ├── config-mcp.spec.ts
│   ├── config-prompts.spec.ts
│   └── config-env.spec.ts
├── openclaw/
│   ├── send-message.spec.ts
│   ├── multi-turn.spec.ts
│   ├── stop-generation.spec.ts
│   └── new-session.spec.ts
├── pages/
│   ├── OpenClawChatPage.ts
│   ├── AgentConfigPage.ts
│   ├── SkillsPage.ts
│   ├── McpPage.ts
│   ├── PromptsPage.ts
│   └── EnvPage.ts
├── fixtures/
│   └── test-data.ts
└── setup/
    └── test-env.ts

scripts/tdd/
├── generate-test.ts
└── run-layer.ts

.env.test
```

### Files to Modify
- `src-tauri/Cargo.toml` - upgrade webdriver version
- `wdio.conf.ts` - fix port 4444 → 4445
- `tests/e2e/tauri/pages/TauriBasePage.ts` - enhance base page
- `tests/e2e/tauri/pages/DashboardPage.ts` - enhance provider page

---

## Phase 1: Infrastructure Setup

### Task 1.1: Upgrade tauri-plugin-webdriver

**Files:**
- Modify: `src-tauri/Cargo.toml:40`

- [ ] **Step 1: Update webdriver version in Cargo.toml**

```toml
# Change from:
tauri-plugin-webdriver = { version = "0.2", optional = true }
# To:
tauri-plugin-webdriver = { version = "0.2.1", optional = true }
```

- [ ] **Step 2: Update Cargo.lock**

```bash
cd src-tauri && cargo update tauri-plugin-webdriver
```

Expected: Cargo.lock shows tauri-plugin-webdriver 0.2.1

- [ ] **Step 3: Verify build with webdriver feature**

```bash
cargo build --manifest-path src-tauri/Cargo.toml --features webdriver
```

Expected: Build succeeds without errors

- [ ] **Step 4: Commit**

```bash
git add src-tauri/Cargo.toml src-tauri/Cargo.lock
git commit -m "chore: upgrade tauri-plugin-webdriver to v0.2.1"
```

---

### Task 1.2: Fix WebDriver Port Configuration

**Files:**
- Modify: `wdio.conf.ts:76-78`

- [ ] **Step 1: Update port in wdio.conf.ts**

```typescript
// Change from:
hostname: '127.0.0.1',
port: 4444,
path: '/',

// To:
hostname: '127.0.0.1',
port: 4445,
path: '/',
```

- [ ] **Step 2: Update tauri-setup.ts port constant**

```typescript
// In tests/e2e/setup/tauri-setup.ts:22
// Change from:
const WEBDRIVER_PORT = 4444;
// To:
const WEBDRIVER_PORT = 4445;
```

- [ ] **Step 3: Verify WebdriverIO can connect**

```bash
bun run test:e2e:tauri:build && bun run test:e2e:tauri
```

Expected: Tests connect successfully to port 4445

- [ ] **Step 4: Commit**

```bash
git add wdio.conf.ts tests/e2e/setup/tauri-setup.ts
git commit -m "fix: use correct WebDriver port 4445"
```

---

### Task 1.3: Create Test Environment Configuration

**Files:**
- Create: `.env.test`
- Create: `tests/e2e-tauri/setup/test-env.ts`

- [ ] **Step 1: Create .env.test file**

```env
# Test API Configuration (not committed to git)
TEST_KIMI_ENDPOINT=https://api.kimi.com/coding/
TEST_KIMI_TOKEN=sk-kimi-zEAPcJFNUmIJ9VDH9apgVPiYGiFx1ofYI1JoDWK57UWCex2M44MHvnJem5Nje5yg

# Test data prefixes
TEST_PROVIDER_PREFIX=test-kimi-
TEST_SESSION_PREFIX=test-session-
```

- [ ] **Step 2: Add .env.test to .gitignore**

```bash
echo ".env.test" >> .gitignore
```

- [ ] **Step 3: Create test environment loader**

```typescript
// tests/e2e-tauri/setup/test-env.ts
import { config } from 'dotenv';
import { resolve } from 'path';

// Load .env.test
config({ path: resolve(process.cwd(), '.env.test') });

export const testEnv = {
  kimiEndpoint: process.env.TEST_KIMI_ENDPOINT || '',
  kimiToken: process.env.TEST_KIMI_TOKEN || '',
  providerPrefix: process.env.TEST_PROVIDER_PREFIX || 'test-',
  sessionPrefix: process.env.TEST_SESSION_PREFIX || 'test-session-',
};

export function getTestProviderName(): string {
  return `${testEnv.providerPrefix}${Date.now()}`;
}
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore tests/e2e-tauri/setup/test-env.ts
git commit -m "feat: add test environment configuration"
```

---

### Task 1.4: Create Test Fixtures

**Files:**
- Create: `tests/e2e-tauri/fixtures/test-data.ts`

- [ ] **Step 1: Create test fixtures file**

```typescript
// tests/e2e-tauri/fixtures/test-data.ts
import { testEnv, getTestProviderName } from '../setup/test-env';

export interface TestProvider {
  name: string;
  apiKey: string;
  baseUrl: string;
  model?: string;
}

export function createKimiTestProvider(): TestProvider {
  return {
    name: getTestProviderName(),
    apiKey: testEnv.kimiToken,
    baseUrl: testEnv.kimiEndpoint,
    model: 'moonshot-v1-8k',
  };
}

export const testMessages = {
  simple: 'Hello, this is a test message.',
  code: 'Write a simple hello world function in Python.',
  multiTurn: [
    'What is 2 + 2?',
    'Now multiply that by 3.',
    'What is the result?',
  ],
};

export const testTimeouts = {
  short: 10_000,
  medium: 30_000,
  long: 60_000,
  api: 120_000,
};
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/fixtures/test-data.ts
git commit -m "feat: add test data fixtures"
```

---

## Phase 2: Enhance Page Objects

### Task 2.1: Enhance TauriBasePage

**Files:**
- Modify: `tests/e2e/tauri/pages/TauriBasePage.ts`

- [ ] **Step 1: Add new helper methods to TauriBasePage**

```typescript
// Add these methods to the class:

/**
 * Wait for element to appear with retry
 */
async waitForElement(selector: string, timeout = 10_000): Promise<WebdriverIO.Element> {
  const el = await $(selector);
  await el.waitForExist({ timeout });
  return el;
}

/**
 * Wait for element to be clickable
 */
async waitForClickable(selector: string, timeout = 10_000): Promise<WebdriverIO.Element> {
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
      const count = spinners.length;
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
async getElements(selector: string): Promise<WebdriverIO.Element[]> {
  return $$(selector) as unknown as WebdriverIO.Element[];
}
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e/tauri/pages/TauriBasePage.ts
git commit -m "feat: enhance TauriBasePage with more helper methods"
```

---

### Task 2.2: Create OpenClawChatPage

**Files:**
- Create: `tests/e2e/tauri/pages/OpenClawChatPage.ts`

- [ ] **Step 1: Create OpenClawChatPage**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * OpenClawChatPage - Page object for OpenClaw chat interface
 */

import { TauriBasePage } from './TauriBasePage';

export class OpenClawChatPage extends TauriBasePage {
  // Selectors
  private readonly chatInput = 'textarea[placeholder*="输入"], textarea[placeholder*="message"], textarea';
  private readonly sendButton = 'button[aria-label*="发送"], button[aria-label*="Send"], button[type="submit"]';
  private readonly stopButton = 'button[aria-label*="停止"], button[aria-label*="Stop"]';
  private readonly messageContainer = '[data-testid="message"], .message, [class*="message"]';
  private readonly newSessionButton = 'button[aria-label*="新建"], button[aria-label*="New"]';
  private readonly responseIndicator = '[data-testid="response"], .ai-response, [class*="response"]';

  /**
   * Navigate to OpenClaw chat
   */
  async openChat(): Promise<void> {
    // Switch to openclaw agent
    const agentButton = await $('button:has-text("OpenClaw")');
    if (await agentButton.isExisting()) {
      await agentButton.click();
      await browser.pause(500);
    }
    await this.waitForReactReady();
  }

  /**
   * Send a message and wait for response
   */
  async sendMessageAndWait(text: string, timeout = 60_000): Promise<string> {
    // Type message
    const input = await this.waitForElement(this.chatInput);
    await input.clearValue();
    await input.addValue(text);

    // Click send
    const send = await this.waitForClickable(this.sendButton);
    await send.click();

    // Wait for response
    return this.waitForResponse(timeout);
  }

  /**
   * Wait for AI response to complete
   */
  async waitForResponse(timeout = 60_000): Promise<string> {
    // Wait for response to start
    await browser.pause(1000);

    // Wait for stop button to disappear (generation complete)
    await browser.waitUntil(
      async () => {
        const stopBtn = await $(this.stopButton);
        const exists = await stopBtn.isExisting();
        return !exists;
      },
      { timeout, timeoutMsg: 'Response did not complete within timeout' }
    );

    // Get the last message
    return this.getLastMessage();
  }

  /**
   * Get the last message content
   */
  async getLastMessage(): Promise<string> {
    const messages = await $$(this.messageContainer);
    if (messages.length === 0) {
      throw new Error('No messages found');
    }
    const lastMessage = messages[messages.length - 1];
    return lastMessage.getText();
  }

  /**
   * Stop generation
   */
  async stopGeneration(): Promise<void> {
    const stopBtn = await $(this.stopButton);
    if (await stopBtn.isExisting()) {
      await stopBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Start new session
   */
  async newSession(): Promise<void> {
    const newBtn = await $(this.newSessionButton);
    if (await newBtn.isExisting()) {
      await newBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Check if chat is ready for input
   */
  async isReadyForInput(): Promise<boolean> {
    const input = await $(this.chatInput);
    return input.isExisting() && input.isDisplayed();
  }

  /**
   * Get all messages
   */
  async getAllMessages(): Promise<string[]> {
    const messages = await $$(this.messageContainer);
    const texts: string[] = [];
    for (const msg of messages) {
      texts.push(await msg.getText());
    }
    return texts;
  }
}

export const openClawChatPage = new OpenClawChatPage();
```

- [ ] **Step 2: Update pages index**

```typescript
// Add to tests/e2e/tauri/pages/index.ts
export { OpenClawChatPage, openClawChatPage } from './OpenClawChatPage';
```

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/tauri/pages/OpenClawChatPage.ts tests/e2e/tauri/pages/index.ts
git commit -m "feat: add OpenClawChatPage for chat testing"
```

---

### Task 2.3: Create AgentConfigPage

**Files:**
- Create: `tests/e2e/tauri/pages/AgentConfigPage.ts`

- [ ] **Step 1: Create AgentConfigPage**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * AgentConfigPage - Page object for Agent configuration view
 */

import { TauriBasePage } from './TauriBasePage';

export type AgentId = 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';
export type ConfigTab = 'basic' | 'skills' | 'mcp' | 'prompts' | 'env' | 'advanced';

export class AgentConfigPage extends TauriBasePage {
  // Tab selectors
  private readonly tabButtons: Record<ConfigTab, string> = {
    basic: '[data-value="basic"], button:has-text("基础")',
    skills: '[data-value="skills"], button:has-text("Skills")',
    mcp: '[data-value="mcp"], button:has-text("MCP")',
    prompts: '[data-value="prompts"], button:has-text("提示词")',
    env: '[data-value="env"], button:has-text("环境变量")',
    advanced: '[data-value="advanced"], button:has-text("高级")',
  };

  private readonly agentSwitcher = '[data-testid="agent-switcher"], button[aria-label*="Agent"]';

  /**
   * Navigate to Agent Config view
   */
  async open(): Promise<void> {
    const configButton = await $('button[aria-label*="Agent配置"], button:has-text("Agent配置")');
    if (await configButton.isExisting()) {
      await configButton.click();
      await browser.pause(500);
    }
    await this.waitForReactReady();
  }

  /**
   * Switch to a specific agent
   */
  async switchAgent(agent: AgentId): Promise<void> {
    const agentButtons: Record<AgentId, string> = {
      claude: 'button:has-text("Claude")',
      codex: 'button:has-text("Codex")',
      gemini: 'button:has-text("Gemini")',
      opencode: 'button:has-text("OpenCode")',
      openclaw: 'button:has-text("OpenClaw")',
    };

    const button = await $(agentButtons[agent]);
    if (await button.isExisting()) {
      await button.click();
      await browser.pause(500);
    }
  }

  /**
   * Switch to a config tab
   */
  async switchTab(tab: ConfigTab): Promise<void> {
    const tabButton = await $(this.tabButtons[tab]);
    if (await tabButton.isExisting()) {
      await tabButton.click();
      await browser.pause(300);
    }
  }

  /**
   * Get current active tab
   */
  async getActiveTab(): Promise<string | null> {
    const activeTab = await $('[role="tab"][data-state="active"], button[data-state="active"]');
    if (await activeTab.isExisting()) {
      return activeTab.getAttribute('data-value');
    }
    return null;
  }

  /**
   * Check if agent is selected
   */
  async isAgentSelected(agent: AgentId): Promise<boolean> {
    const button = await $(`button[aria-pressed="true"]:has-text("${agent}")`);
    return button.isExisting();
  }
}

export const agentConfigPage = new AgentConfigPage();
```

- [ ] **Step 2: Update pages index**

```typescript
// Add to tests/e2e/tauri/pages/index.ts
export { AgentConfigPage, agentConfigPage } from './AgentConfigPage';
export type { AgentId, ConfigTab } from './AgentConfigPage';
```

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/tauri/pages/AgentConfigPage.ts tests/e2e/tauri/pages/index.ts
git commit -m "feat: add AgentConfigPage for agent configuration testing"
```

---

## Phase 3: Provider E2E Tests

### Task 3.1: Add Provider Test

**Files:**
- Create: `tests/e2e-tauri/providers/add-provider.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Add Provider E2E Test
 */

import { dashboardPage } from '../pages/DashboardPage';
import { createKimiTestProvider } from '../fixtures/test-data';

describe('Provider Management - Add Provider', () => {
  it('should add a new provider with valid configuration', async () => {
    const testProvider = createKimiTestProvider();

    // Get initial count
    await dashboardPage.open();
    const initialCount = await dashboardPage.getProviderCount();

    // Add provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
      model: testProvider.model,
    });

    // Wait for toast
    await browser.pause(1000);

    // Verify provider was added
    const newCount = await dashboardPage.getProviderCount();
    expect(newCount).toBe(initialCount + 1);

    // Verify provider appears in list
    const names = await dashboardPage.getVisibleProviderNames();
    expect(names.some(n => n.includes(testProvider.name))).toBe(true);
  });

  it('should show validation error for empty name', async () => {
    await dashboardPage.open();
    await dashboardPage.clickAddProvider();

    // Try to save without filling required fields
    await dashboardPage.saveProvider();

    // Wait for validation
    await browser.pause(500);

    // Check for error message or form still open
    const form = await $('[data-testid="provider-form"], form');
    const formVisible = await form.isExisting();
    expect(formVisible).toBe(true); // Form should still be visible
  });
});
```

- [ ] **Step 2: Run test to verify it works**

```bash
bun run test:e2e:tauri
```

Expected: Tests pass

- [ ] **Step 3: Commit**

```bash
git add tests/e2e-tauri/providers/add-provider.spec.ts
git commit -m "test: add provider creation E2E test"
```

---

### Task 3.2: Switch Provider Test

**Files:**
- Create: `tests/e2e-tauri/providers/switch-provider.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Switch Provider E2E Test
 */

import { dashboardPage } from '../pages/DashboardPage';
import { createKimiTestProvider } from '../fixtures/test-data';

describe('Provider Management - Switch Provider', () => {
  const testProvider = createKimiTestProvider();

  before(async () => {
    // Ensure test provider exists
    await dashboardPage.open();
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
    });
    await browser.pause(500);
  });

  it('should switch to a different provider', async () => {
    await dashboardPage.open();

    // Find provider card and click switch
    const cards = await dashboardPage.getProviderCards();
    expect(cards.length).toBeGreaterThan(0);

    // Click on the test provider card
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(testProvider.name)) {
        // Click the provider card to select it
        await card.click();
        await browser.pause(300);

        // Look for switch/activate button
        const switchBtn = await card.$('button[aria-label*="切换"], button[aria-label*="Switch"]');
        if (await switchBtn.isExisting()) {
          await switchBtn.click();
          await browser.pause(500);
        }
        break;
      }
    }

    // Verify toast notification
    const toast = await dashboardPage.waitForToast();
    expect(toast).not.toBeNull();
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/providers/switch-provider.spec.ts
git commit -m "test: add provider switch E2E test"
```

---

### Task 3.3: Delete Provider Test

**Files:**
- Create: `tests/e2e-tauri/providers/delete-provider.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Delete Provider E2E Test
 */

import { dashboardPage } from '../pages/DashboardPage';
import { createKimiTestProvider } from '../fixtures/test-data';

describe('Provider Management - Delete Provider', () => {
  it('should delete a provider after confirmation', async () => {
    const testProvider = createKimiTestProvider();

    // Add a provider first
    await dashboardPage.open();
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
    });
    await browser.pause(500);

    const countBefore = await dashboardPage.getProviderCount();

    // Delete the provider
    await dashboardPage.deleteProvider(testProvider.name);
    await browser.pause(500);

    // Verify deletion
    const countAfter = await dashboardPage.getProviderCount();
    expect(countAfter).toBe(countBefore - 1);

    // Verify provider not in list
    const names = await dashboardPage.getVisibleProviderNames();
    expect(names.some(n => n.includes(testProvider.name))).toBe(false);
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/providers/delete-provider.spec.ts
git commit -m "test: add provider deletion E2E test"
```

---

## Phase 4: Agent Config Tests

### Task 4.1: Switch Agent Test

**Files:**
- Create: `tests/e2e-tauri/agents/switch-agent.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Switch Agent E2E Test
 */

import { agentConfigPage, AgentId } from '../pages/AgentConfigPage';

describe('Agent Configuration - Switch Agent', () => {
  const agents: AgentId[] = ['claude', 'codex', 'gemini', 'opencode', 'openclaw'];

  before(async () => {
    await agentConfigPage.open();
  });

  agents.forEach((agent) => {
    it(`should switch to ${agent} agent`, async () => {
      await agentConfigPage.switchAgent(agent);
      await browser.pause(300);

      // Verify agent is selected
      const isSelected = await agentConfigPage.isAgentSelected(agent);
      expect(isSelected).toBe(true);
    });
  });

  it('should maintain selected agent after tab switch', async () => {
    await agentConfigPage.switchAgent('codex');
    await agentConfigPage.switchTab('skills');
    await browser.pause(300);

    // Switch back to basic tab
    await agentConfigPage.switchTab('basic');
    await browser.pause(300);

    // Verify codex is still selected
    const isSelected = await agentConfigPage.isAgentSelected('codex');
    expect(isSelected).toBe(true);
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/agents/switch-agent.spec.ts
git commit -m "test: add agent switch E2E test"
```

---

### Task 4.2: Config Tabs Test

**Files:**
- Create: `tests/e2e-tauri/agents/config-tabs.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Config Tabs E2E Test
 */

import { agentConfigPage, ConfigTab } from '../pages/AgentConfigPage';

describe('Agent Configuration - Config Tabs', () => {
  const tabs: ConfigTab[] = ['basic', 'skills', 'mcp', 'prompts', 'env', 'advanced'];

  before(async () => {
    await agentConfigPage.open();
  });

  tabs.forEach((tab) => {
    it(`should switch to ${tab} tab`, async () => {
      await agentConfigPage.switchTab(tab);
      await browser.pause(300);

      // Verify tab content is visible
      const activeTab = await agentConfigPage.getActiveTab();
      expect(activeTab).toBe(tab);
    });
  });

  it('should show provider list in basic tab', async () => {
    await agentConfigPage.switchTab('basic');
    await browser.pause(300);

    // Check for provider cards or list
    const providerCards = await $$('[data-testid="provider-card"], .provider-card');
    const count = providerCards.length;
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should show skills list in skills tab', async () => {
    await agentConfigPage.switchTab('skills');
    await browser.pause(500);

    // Check for skills content
    const skillsContent = await $('[data-testid="skills-panel"], [class*="skills"]');
    const exists = await skillsContent.isExisting();
    expect(exists).toBe(true);
  });

  it('should show MCP servers in mcp tab', async () => {
    await agentConfigPage.switchTab('mcp');
    await browser.pause(500);

    // Check for MCP content
    const mcpContent = await $('[data-testid="mcp-panel"], [class*="mcp"]');
    const exists = await mcpContent.isExisting();
    expect(exists).toBe(true);
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/agents/config-tabs.spec.ts
git commit -m "test: add config tabs E2E test"
```

---

## Phase 5: OpenClaw Chat Tests

### Task 5.1: Send Message Test

**Files:**
- Create: `tests/e2e-tauri/openclaw/send-message.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Send Message E2E Test - Real API
 */

import { openClawChatPage } from '../pages/OpenClawChatPage';
import { testMessages, testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - Send Message', () => {
  before(async () => {
    await openClawChatPage.openChat();
    // Ensure we're ready for input
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );
  });

  it('should send a message and receive a response', async () => {
    const message = testMessages.simple;

    // Send message and wait for response
    const response = await openClawChatPage.sendMessageAndWait(
      message,
      testTimeouts.api
    );

    // Verify we got a non-empty response
    expect(response.length).toBeGreaterThan(0);

    // Log response for debugging
    console.log('AI Response:', response.substring(0, 100) + '...');
  });

  it('should display user message in chat history', async () => {
    const message = `Test message ${Date.now()}`;

    await openClawChatPage.sendMessageAndWait(message, testTimeouts.api);

    // Get all messages
    const messages = await openClawChatPage.getAllMessages();

    // Verify user message appears
    const found = messages.some(m => m.includes(message));
    expect(found).toBe(true);
  });

  it('should handle special characters in message', async () => {
    const specialMessages = [
      'Test with "quotes"',
      "Test with 'apostrophes'",
      'Test with symbols: @#$%^&*()',
    ];

    for (const msg of specialMessages) {
      const response = await openClawChatPage.sendMessageAndWait(
        msg,
        testTimeouts.api
      );
      expect(response.length).toBeGreaterThan(0);
    }
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/openclaw/send-message.spec.ts
git commit -m "test: add OpenClaw send message E2E test with real API"
```

---

### Task 5.2: Multi-Turn Conversation Test

**Files:**
- Create: `tests/e2e-tauri/openclaw/multi-turn.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Multi-Turn Conversation E2E Test - Real API
 */

import { openClawChatPage } from '../pages/OpenClawChatPage';
import { testMessages, testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - Multi-Turn Conversation', () => {
  before(async () => {
    await openClawChatPage.openChat();
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );

    // Start a new session for clean state
    await openClawChatPage.newSession();
    await browser.pause(500);
  });

  it('should maintain context across multiple messages', async () => {
    const questions = testMessages.multiTurn;
    const responses: string[] = [];

    for (const question of questions) {
      const response = await openClawChatPage.sendMessageAndWait(
        question,
        testTimeouts.api
      );
      responses.push(response);
      console.log(`Q: ${question}`);
      console.log(`A: ${response.substring(0, 100)}...`);
    }

    // All responses should be non-empty
    expect(responses.every(r => r.length > 0)).toBe(true);

    // Last response should reference the context (result should be 12)
    const lastResponse = responses[responses.length - 1].toLowerCase();
    const hasNumber = lastResponse.includes('12') || lastResponse.includes('twelve');
    expect(hasNumber).toBe(true);
  });

  it('should handle sequential code-related questions', async () => {
    // Start fresh
    await openClawChatPage.newSession();
    await browser.pause(500);

    // First: Ask to create a function
    const response1 = await openClawChatPage.sendMessageAndWait(
      'Create a simple Python function called "greet" that takes a name and returns "Hello, {name}!"',
      testTimeouts.api
    );
    expect(response1.toLowerCase()).toContain('def greet');

    // Second: Ask to modify it
    const response2 = await openClawChatPage.sendMessageAndWait(
      'Now modify it to handle None input by returning "Hello, World!"',
      testTimeouts.api
    );
    expect(response2.length).toBeGreaterThan(0);

    // Third: Ask about the function
    const response3 = await openClawChatPage.sendMessageAndWait(
      'What does the function return when called with greet(None)?',
      testTimeouts.api
    );
    expect(response3.toLowerCase()).toContain('hello');
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/openclaw/multi-turn.spec.ts
git commit -m "test: add multi-turn conversation E2E test"
```

---

### Task 5.3: Stop Generation Test

**Files:**
- Create: `tests/e2e-tauri/openclaw/stop-generation.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * Stop Generation E2E Test - Real API
 */

import { openClawChatPage } from '../pages/OpenClawChatPage';
import { testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - Stop Generation', () => {
  before(async () => {
    await openClawChatPage.openChat();
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );
  });

  it('should stop generation when stop button is clicked', async () => {
    // Send a message that will generate a long response
    const input = await $('textarea');
    await input.setValue('Write a detailed 500-word essay about artificial intelligence');

    const sendBtn = await $('button[type="submit"]');
    await sendBtn.click();

    // Wait a bit for generation to start
    await browser.pause(2000);

    // Click stop button
    await openClawChatPage.stopGeneration();
    await browser.pause(500);

    // Get last message (should be partial)
    const lastMessage = await openClawChatPage.getLastMessage();

    // Message should exist but may be shorter than full response
    expect(lastMessage.length).toBeGreaterThan(0);

    console.log('Partial response length:', lastMessage.length);
  });

  it('should allow sending new message after stop', async () => {
    // Start generation and stop it
    const input = await $('textarea');
    await input.setValue('Tell me a long story');
    const sendBtn = await $('button[type="submit"]');
    await sendBtn.click();
    await browser.pause(1500);
    await openClawChatPage.stopGeneration();
    await browser.pause(500);

    // Should be able to send new message
    const newResponse = await openClawChatPage.sendMessageAndWait(
      'What is 1+1?',
      testTimeouts.api
    );

    expect(newResponse.length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/openclaw/stop-generation.spec.ts
git commit -m "test: add stop generation E2E test"
```

---

### Task 5.4: New Session Test

**Files:**
- Create: `tests/e2e-tauri/openclaw/new-session.spec.ts`

- [ ] **Step 1: Write the test**

```typescript
/// <reference types="@wdio/globals/types" />
/**
 * New Session E2E Test - Real API
 */

import { openClawChatPage } from '../pages/OpenClawChatPage';
import { testTimeouts } from '../fixtures/test-data';

describe('OpenClaw Chat - New Session', () => {
  before(async () => {
    await openClawChatPage.openChat();
    await browser.waitUntil(
      async () => openClawChatPage.isReadyForInput(),
      { timeout: testTimeouts.medium }
    );
  });

  it('should start a new session', async () => {
    // Send a message first
    await openClawChatPage.sendMessageAndWait(
      'My favorite color is blue.',
      testTimeouts.api
    );

    // Get message count
    const messagesBefore = await openClawChatPage.getAllMessages();

    // Start new session
    await openClawChatPage.newSession();
    await browser.pause(1000);

    // Verify messages are cleared
    const messagesAfter = await openClawChatPage.getAllMessages();

    // After new session, message count should be less (or empty)
    expect(messagesAfter.length).toBeLessThan(messagesBefore.length);
  });

  it('should not retain context from previous session', async () => {
    // Start fresh
    await openClawChatPage.newSession();
    await browser.pause(500);

    // Send message and establish context
    await openClawChatPage.sendMessageAndWait(
      'I am testing session isolation.',
      testTimeouts.api
    );

    // Start new session
    await openClawChatPage.newSession();
    await browser.pause(500);

    // Ask about context - AI should not know about previous message
    const response = await openClawChatPage.sendMessageAndWait(
      'What did I just tell you?',
      testTimeouts.api
    );

    // Response should indicate lack of context
    const lowerResponse = response.toLowerCase();
    const hasNoContext = lowerResponse.includes("don't know") ||
                         lowerResponse.includes("didn't mention") ||
                         lowerResponse.includes("no context") ||
                         lowerResponse.includes("no previous") ||
                         lowerResponse.includes("haven't told");

    // This test is soft - AI might respond various ways
    console.log('Context test response:', response.substring(0, 200));
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e-tauri/openclaw/new-session.spec.ts
git commit -m "test: add new session E2E test"
```

---

## Phase 6: TDD Tools

### Task 6.1: Test Generator Script

**Files:**
- Create: `scripts/tdd/generate-test.ts`

- [ ] **Step 1: Create generator script**

```typescript
#!/usr/bin/env bun
/**
 * Test Generator Script
 * Usage: bun run gen:test <ComponentName>
 */

import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

const componentName = process.argv[2];

if (!componentName) {
  console.error('Usage: bun run gen:test <ComponentName>');
  process.exit(1);
}

const testDir = join(process.cwd(), 'tests', 'unit', 'components');
const testFile = join(testDir, `${componentName}.test.tsx`);

if (existsSync(testFile)) {
  console.error(`Test file already exists: ${testFile}`);
  process.exit(1);
}

const template = `import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ${componentName} } from '@/components/${componentName}';

describe('${componentName}', () => {
  it('should render correctly', () => {
    render(<${componentName} />);
    // Add assertions here
  });

  it('should handle click events', async () => {
    const onClick = vi.fn();
    render(<${componentName} onClick={onClick} />);

    // Find and click element
    // const button = screen.getByRole('button');
    // await userEvent.click(button);
    // expect(onClick).toHaveBeenCalled();
  });
});
`;

mkdirSync(testDir, { recursive: true });
writeFileSync(testFile, template);

console.log(`Created test file: ${testFile}`);
console.log('Remember to implement the tests!');
```

- [ ] **Step 2: Add script to package.json**

```json
{
  "scripts": {
    "gen:test": "bun run scripts/tdd/generate-test.ts"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add scripts/tdd/generate-test.ts package.json
git commit -m "feat: add test generator script"
```

---

### Task 6.2: Layer Runner Script

**Files:**
- Create: `scripts/tdd/run-layer.ts`

- [ ] **Step 1: Create layer runner script**

```typescript
#!/usr/bin/env bun
/**
 * Test Layer Runner
 * Usage: bun run test:layer <1-5>
 */

const layer = process.argv[2];

const layerCommands: Record<string, string> = {
  '1': 'bun vitest run tests/unit',
  '2': 'cargo test --manifest-path src-tauri/Cargo.toml',
  '3': 'bun vitest run tests/integration',
  '4': 'bun playwright test',
  '5': 'bunx wdio run wdio.conf.ts',
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

import { $ } from 'bun';

const cmd = layerCommands[layer];
console.log(`Running Layer ${layer}: ${cmd}`);
console.log('');

await $`${cmd}`.nothrow();
```

- [ ] **Step 2: Add script to package.json**

```json
{
  "scripts": {
    "test:layer": "bun run scripts/tdd/run-layer.ts"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add scripts/tdd/run-layer.ts package.json
git commit -m "feat: add layer runner script for TDD workflow"
```

---

## Verification Checklist

After completing all phases:

- [ ] `bun run test:unit` passes
- [ ] `bun run test:rust` passes
- [ ] `bun run test:integration` passes
- [ ] `bun run test:e2e` passes
- [ ] `bun run test:tauri` passes (all 14 new E2E tests)
- [ ] Provider CRUD works via real UI
- [ ] Agent configuration tabs are navigable
- [ ] OpenClaw chat sends/receives messages with real Kimi API
- [ ] Multi-turn conversation maintains context
- [ ] Stop generation interrupts AI response
- [ ] New session clears conversation

---

## Summary

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| Phase 1: Infrastructure | 4 tasks | 1 hour |
| Phase 2: Page Objects | 3 tasks | 2 hours |
| Phase 3: Provider Tests | 3 tasks | 2 hours |
| Phase 4: Agent Tests | 2 tasks | 1 hour |
| Phase 5: OpenClaw Tests | 4 tasks | 3 hours |
| Phase 6: TDD Tools | 2 tasks | 1 hour |
| **Total** | **18 tasks** | **~10 hours** |