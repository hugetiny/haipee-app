# TDD Infrastructure for Haipee

## Overview

Build a comprehensive TDD (Test-Driven Development) infrastructure that enables:

1. **Full test coverage** across all layers (unit → integration → E2E)
2. **Real user interaction testing** with real API calls (no mocking)
3. **TDD workflow support** - tools that make "write test first" easy
4. **AI-assisted development loop** - autonomous test-fix cycles

---

## Architecture

### Test Pyramid

```
┌─────────────────────────────────────┐
│     Layer 5: Tauri E2E (WebDriver)  │  ← 10-20 核心用户流程（真实 API）
│     - OpenClaw 对话                 │
│     - Provider 端到端操作           │
├─────────────────────────────────────┤
│     Layer 4: Playwright E2E         │  ← 30-50 UI 交互测试
│     - 组件交互测试                  │
│     - 导航、表单验证                │
├─────────────────────────────────────┤
│     Layer 3: Integration Tests      │  ← 40-60 集成测试
│     - Tauri 命令 + 真实 SQLite      │
│     - Provider CRUD 操作            │
├─────────────────────────────────────┤
│     Layer 2: Rust Unit Tests        │  ← 50-100 后端逻辑单元测试
│     - 配置解析、验证逻辑            │
├─────────────────────────────────────┤
│     Layer 1: JS Unit Tests          │  ← 100+ 前端组件/hooks 测试
│     - React 组件、工具函数          │
└─────────────────────────────────────┘
```

### Directory Structure

```
tests/
├── unit/                    # Layer 1: JS 单元测试 (Vitest)
│   ├── components/          # React 组件测试
│   ├── hooks/               # 自定义 hooks 测试
│   └── utils/               # 工具函数测试
│
├── integration/             # Layer 3: 集成测试 (Vitest + Tauri)
│   ├── providers.test.ts    # Provider CRUD 集成
│   ├── mcp.test.ts          # MCP 配置集成
│   └── skills.test.ts       # Skills 管理集成
│
├── e2e/                     # Layer 4: Playwright (browser-mock IPC)
│   ├── providers/           # Provider UI 交互
│   └── navigation/          # 导航测试
│
└── e2e-tauri/               # Layer 5: WebDriver (真实 Tauri + 真实 API)
    ├── providers/           # Provider 端到端
    ├── agents/              # Agent 配置管理
    ├── openclaw/            # OpenClaw 真实对话
    ├── pages/               # Page Object Models
    └── setup/               # 测试环境配置
```

---

## Layer 5: WebDriver E2E Tests

### Test Cases

#### Provider Management

| Test Case | Steps | Verification |
|-----------|-------|--------------|
| `add-provider` | Click add → Fill Kimi config → Save | Provider appears in list |
| `edit-provider` | Select Provider → Edit name/config → Save | Updated values displayed |
| `delete-provider` | Select Provider → Click delete → Confirm | Provider removed from list |
| `switch-provider` | Click another Provider's switch button | Status shows "current" |
| `test-provider-connection` | Click test connection button | Shows success/failure status |

#### Agent Configuration Management

| Test Case | Steps | Verification |
|-----------|-------|--------------|
| `switch-agent` | Click Agent switcher → Select Codex | UI switches to Codex config view |
| `config-skills` | Go to Skills tab → Enable/disable skill | State persisted to database |
| `config-mcp` | Go to MCP tab → Add/remove MCP server | Config written to agent config file |
| `config-prompts` | Go to Prompts tab → Edit prompt | Content saved successfully |
| `config-env` | Go to Env tab → Add env variable | Variable written to shell config |

#### OpenClaw Real Chat (Real API)

| Test Case | Steps | Verification |
|-----------|-------|--------------|
| `send-message` | Type "Hello" in input → Send | Message displayed, AI response received |
| `multi-turn-conversation` | Send multiple messages in sequence | Context maintained, coherent responses |
| `stop-generation` | Send message → Click stop button | Generation interrupted, partial response kept |
| `new-session` | Click new session button | Conversation cleared, new session started |

---

## Page Object Model

### Structure

```
tests/e2e-tauri/pages/
├── BasePage.ts              # Base page object (common methods)
├── AppPage.ts               # Main app page
├── ProviderListPage.ts      # Provider list
├── ProviderFormPage.ts      # Provider add/edit form
├── AgentConfigPage.ts       # Agent config page (6 tabs)
├── SkillsPage.ts            # Skills management
├── McpPage.ts               # MCP management
├── PromptsPage.ts           # Prompts management
├── EnvPage.ts               # Environment variables
├── OpenClawChatPage.ts      # OpenClaw chat interface
├── SettingsPage.ts          # Settings page
└── index.ts                 # Unified exports
```

### BasePage Core Methods

```typescript
class BasePage {
  // Wait for element to appear (with retry)
  async waitForElement(selector: string, timeout?: number): Promise<void>

  // Wait for element to be clickable
  async waitForClickable(selector: string): Promise<void>

  // Safe click (wait then click)
  async safeClick(selector: string): Promise<void>

  // Input text (clear then type)
  async inputText(selector: string, text: string): Promise<void>

  // Execute Tauri IPC command
  async invoke<T>(command: string, args?: object): Promise<T>

  // Save screenshot (for debugging)
  async screenshot(name: string): Promise<void>

  // Wait for API request to complete
  async waitForApiComplete(timeout?: number): Promise<void>
}
```

### OpenClawChatPage Example

```typescript
class OpenClawChatPage extends BasePage {
  // Send message and wait for response
  async sendMessageAndWait(text: string, timeout?: number): Promise<string>

  // Wait for AI response to complete
  async waitForResponse(): Promise<string>

  // Get last message content
  async getLastMessage(): Promise<string>

  // Stop generation
  async stopGeneration(): Promise<void>

  // Create new session
  async newSession(): Promise<void>
}
```

---

## TDD Tool Support

### Scripts

```
scripts/tdd/
├── generate-test.ts         # Generate test template from component
├── run-layer.ts             # Run specific layer tests
├── watch-test.ts            # Hot-reload test development
└── test-fixture.ts          # Test data fixtures
```

### Commands

```bash
# Run specific layer tests
bun run test:unit              # Layer 1
bun run test:rust              # Layer 2
bun run test:integration       # Layer 3
bun run test:e2e               # Layer 4
bun run test:tauri             # Layer 5

# TDD workflow
bun run test:watch             # Hot-reload mode
bun run test:affected          # Only run affected tests

# Generate tests
bun run gen:test ComponentName  # Auto-generate component test template
```

### Test Environment Configuration

```env
# .env.test (not committed to git)
TEST_KIMI_ENDPOINT=https://api.kimi.com/coding/
TEST_KIMI_TOKEN=sk-kimi-xxx
```

---

## Test Data Isolation

1. **Database reset** before each test suite
2. **Test ID prefix** for providers (e.g., `test-kimi-`)
3. **Cleanup** after tests complete
4. **Fixtures** for common test data

---

## Dependencies

### Already in Use
- `tauri-plugin-webdriver` v0.2 → **upgrade to v0.2.1**
- `vitest` for unit/integration tests
- `playwright` for browser E2E
- `@wdio/cli` for WebDriver tests

### Port Configuration Fix
- Current: `wdio.conf.ts` uses port 4444
- WebDriver default: port 4445
- **Action**: Update to use port 4445

---

## Implementation Phases

### Phase 1: Infrastructure Setup
1. Upgrade `tauri-plugin-webdriver` to v0.2.1
2. Fix port configuration (4444 → 4445)
3. Create `.env.test` for test credentials
4. Set up test fixtures

### Phase 2: Page Objects
1. Implement `BasePage` with core methods
2. Create Page Objects for each main view
3. Add helper methods for common operations

### Phase 3: Provider Tests
1. Provider CRUD tests
2. Provider switch tests
3. Connection test verification

### Phase 4: Agent Config Tests
1. Agent switcher tests
2. Skills/MCP/Prompts/Env tab tests
3. Configuration persistence tests

### Phase 5: OpenClaw Chat Tests
1. Basic message send/receive
2. Multi-turn conversation
3. Stop generation
4. Session management

### Phase 6: TDD Tools
1. Test generator script
2. Layer runner script
3. Watch mode setup
4. CI/CD integration

---

## Success Criteria

1. ✅ All 5 test layers passing
2. ✅ Provider management fully tested with real API
3. ✅ Agent configuration fully tested
4. ✅ OpenClaw chat tested with real Kimi API
5. ✅ TDD workflow established (write test → run → fail → implement → pass)
6. ✅ ai-dev-loop can auto-fix failing tests