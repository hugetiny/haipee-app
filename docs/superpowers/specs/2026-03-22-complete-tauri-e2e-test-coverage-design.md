---
title: Complete Tauri E2E Test Coverage Design
created: 2026-03-22
status: draft
estimated_hours: 8
---

# Complete Tauri E2E Test Coverage Design

## 1. Overview

### Goal
为 Haipee Tauri 应用编写完整的 E2E 测试，覆盖每个界面的每个操作，并支持 AI 自主开发循环进行修复。

### Scope
- 10 个主要界面 View
- 5 个 App 切换（claude, codex, gemini, opencode, openclaw）
- 所有用户交互操作

### Current State
- 已有测试：~1200 行，主要覆盖 Settings 页面
- 未覆盖：Providers CRUD、Sessions、Prompts、Skills、MCP、OpenClaw Dashboard 等

---

## 2. Test Architecture

### Directory Structure

```
tests/e2e/tauri/
├── pages/                    # Page Object Models
│   ├── BasePage.ts          # 基础页面类
│   ├── ProvidersPage.ts     # 供应商页面
│   ├── SessionsPage.ts      # 会话管理页面
│   ├── SettingsPage.ts      # 设置页面（已存在，需更新）
│   ├── McpPage.ts           # MCP 配置页面
│   ├── PromptsPage.ts       # 提示词页面
│   ├── SkillsPage.ts        # 技能页面
│   ├── OpenClawDashboardPage.ts  # OpenClaw 仪表盘
│   └── ChannelTestPage.ts   # 频道测试页面
│
├── flows/                    # 用户流程测试（核心）
│   ├── provider-lifecycle.spec.ts      # 供应商 CRUD + 切换
│   ├── app-switching.spec.ts           # App 切换流程
│   ├── session-management.spec.ts      # 会话管理流程
│   ├── settings-workflow.spec.ts       # 设置完整流程
│   └── mcp-skill-integration.spec.ts   # MCP/Skill 集成流程
│
├── views/                    # 界面细节测试
│   ├── providers-view.spec.ts          # 供应商界面细节
│   ├── sessions-view.spec.ts           # 会话界面细节
│   ├── prompts-view.spec.ts            # 提示词界面细节
│   ├── skills-view.spec.ts             # 技能界面细节
│   ├── mcp-view.spec.ts                # MCP 界面细节
│   ├── universal-provider.spec.ts      # 通用供应商界面
│   └── openclaw-dashboard.spec.ts      # OpenClaw 仪表盘细节
│
├── utils/                    # 测试工具
│   ├── test-helpers.ts      # 通用辅助函数
│   ├── data-manager.ts      # 测试数据管理（备份/还原）
│   ├── external-deps.ts     # 外部依赖检查
│   └── assertions.ts        # 自定义断言
│
└── setup/                    # 测试环境设置
    ├── global-setup.ts
    └── global-teardown.ts
```

---

## 3. Test Data Management

### Lifecycle
每个测试套件的生命周期：

```
beforeAll:
  1. 备份当前数据库 → ~/.haipee/test-backups/{suite-id}-{timestamp}.db
  2. 清理测试相关数据（保留基础配置）
  3. 注入最小必要数据（至少一个供应商）

afterAll:
  1. 还原数据库
  2. 清理备份文件
```

### DataManager Class

```typescript
// utils/data-manager.ts
export class DataManager {
  private backupPath: string | null = null;
  private dbPath: string;

  constructor(suiteId: string);

  async backup(): Promise<string>;
  async restore(): Promise<void>;
  async cleanup(): Promise<void>;
  async clearTestData(): Promise<void>;
  async injectTestProviders(appId: AppId, count: number): Promise<Provider[]>;
  async injectTestMcpServers(count: number): Promise<McpServer[]>;
  async injectTestSkills(count: number): Promise<Skill[]>;
}
```

### Database Backup Strategy

```typescript
// 使用 Tauri IPC 进行数据库操作
async backup(): Promise<string> {
  const timestamp = Date.now();
  const backupPath = `~/.haipee/test-backups/${this.suiteId}-${timestamp}.db`;

  await invoke('backup_database', { path: backupPath });
  this.backupPath = backupPath;

  return backupPath;
}

async restore(): Promise<void> {
  if (!this.backupPath) return;

  await invoke('restore_database', { path: this.backupPath });

  // 清理备份文件
  await invoke('delete_file', { path: this.backupPath });
  this.backupPath = null;
}
```

---

## 4. External Dependencies

### Environment Variables

| 变量 | 用途 | 测试影响 |
|------|------|---------|
| `TEST_API_TOKENS` | API 供应商测试 | 无则跳过 API 连通性测试 |
| `TEST_WEBDAV_URL` | WebDAV 同步测试 | 无则跳过同步测试 |
| `TEST_OPENCLAW_GATEWAY` | OpenClaw Gateway 测试 | 无则跳过 Gateway 连接测试 |

### Skip Pattern

```typescript
describe.skipIf(!process.env.TEST_API_TOKENS)('API Provider Tests', () => {
  // 完整测试
});

describe('Provider UI Tests', () => {
  // UI 测试始终运行，不依赖外部 API
});
```

---

## 5. Page Object Model

### BasePage

```typescript
// pages/BasePage.ts
export class BasePage {
  protected baseUrl = 'http://localhost:3000';

  // 导航
  async navigate(path: string): Promise<void>;

  // 等待
  async waitForText(text: string, timeout?: number): Promise<boolean>;
  async waitForAnyText(texts: string[], timeout?: number): Promise<boolean>;
  async waitForElement(selector: string, timeout?: number): Promise<boolean>;

  // 交互
  async clickButton(label: string): Promise<void>;
  async clickElement(selector: string): Promise<void>;
  async fillInput(selector: string, value: string): Promise<void>;
  async selectOption(selector: string, value: string): Promise<void>;

  // 状态
  async isChecked(selector: string): Promise<boolean>;
  async isDisplayed(selector: string): Promise<boolean>;
  async getText(selector: string): Promise<string>;
  async getValue(selector: string): Promise<string>;

  // 断言辅助
  async pageContainsText(text: string): Promise<boolean>;
  async countElements(selector: string): Promise<number>;

  // Tauri IPC
  async isTauriAvailable(): Promise<boolean>;
  async invokeIPC<T>(cmd: string, args?: Record<string, unknown>): Promise<T | null>;

  // 截图
  async takeScreenshot(name: string): Promise<void>;
}
```

### ProvidersPage

```typescript
// pages/ProvidersPage.ts
export class ProvidersPage extends BasePage {
  // 导航
  async navigateToApp(appId: AppId): Promise<void>;

  // 供应商操作
  async createProvider(data: ProviderFormData): Promise<string>;
  async editProvider(id: string, data: Partial<ProviderFormData>): Promise<void>;
  async deleteProvider(id: string): Promise<void>;
  async switchProvider(id: string): Promise<void>;
  async duplicateProvider(id: string): Promise<string>;

  // 排序
  async dragProvider(fromIndex: number, toIndex: number): Promise<void>;

  // 状态检查
  async getProviderCount(): Promise<number>;
  async getActiveProviderId(): Promise<string | null>;
  async providerExists(name: string): Promise<boolean>;
  async getProviderByName(name: string): Promise<Provider | null>;

  // 搜索
  async searchProviders(query: string): Promise<void>;
  async clearSearch(): Promise<void>;
}

interface ProviderFormData {
  name: string;
  apiKey: string;
  endpoint?: string;
  model?: string;
  category?: string;
}
```

### SessionsPage

```typescript
// pages/SessionsPage.ts
export class SessionsPage extends BasePage {
  // 列表操作
  async getSessionCount(): Promise<number>;
  async selectSession(sessionKey: string): Promise<void>;
  async deleteSession(sessionKey: string): Promise<void>;

  // 搜索
  async searchSessions(query: string): Promise<void>;

  // 过滤
  async filterByProvider(provider: ProviderFilter): Promise<void>;

  // 消息操作
  async getMessageCount(): Promise<number>;
  async sendMessage(message: string): Promise<void>;

  // 详情
  async openSessionDetail(sessionKey: string): Promise<void>;
  async closeSessionDetail(): Promise<void>;
}

type ProviderFilter = 'all' | 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';
```

### McpPage

```typescript
// pages/McpPage.ts
export class McpPage extends BasePage {
  // MCP 服务器操作
  async createServer(data: McpServerFormData): Promise<string>;
  async editServer(id: string, data: Partial<McpServerFormData>): Promise<void>;
  async deleteServer(id: string): Promise<void>;
  async toggleServer(id: string, enabled: boolean): Promise<void>;

  // App 切换
  async toggleServerApp(id: string, app: AppId, enabled: boolean): Promise<void>;

  // 状态检查
  async getServerCount(): Promise<number>;
  async serverExists(name: string): Promise<boolean>;
}

interface McpServerFormData {
  name: string;
  command: string;
  args?: string[];
  env?: Record<string, string>;
}
```

### PromptsPage

```typescript
// pages/PromptsPage.ts
export class PromptsPage extends BasePage {
  // 提示词操作
  async createPrompt(data: PromptFormData): Promise<string>;
  async editPrompt(id: string, data: Partial<PromptFormData>): Promise<void>;
  async deletePrompt(id: string): Promise<void>;
  async togglePrompt(id: string, enabled: boolean): Promise<void>;

  // 状态检查
  async getPromptCount(): Promise<number>;
  async promptExists(name: string): Promise<boolean>;
}

interface PromptFormData {
  name: string;
  content: string;
  enabled?: boolean;
}
```

### SkillsPage

```typescript
// pages/SkillsPage.ts
export class SkillsPage extends BasePage {
  // 技能操作
  async installSkill(id: string): Promise<void>;
  async uninstallSkill(id: string): Promise<void>;
  async toggleSkillApp(id: string, app: AppId, enabled: boolean): Promise<void>;

  // 备份
  async backupSkill(id: string): Promise<void>;
  async restoreSkill(id: string): Promise<void>;

  // 导入
  async importFromZip(path: string): Promise<void>;
  async importFromApp(app: AppId): Promise<void>;

  // 状态检查
  async getSkillCount(): Promise<number>;
  async skillExists(name: string): Promise<boolean>;
}
```

---

## 6. Test Coverage

### Flow Tests (核心流程)

| 流程 | 测试用例 |
|------|---------|
| **Provider Lifecycle** | 创建供应商 → 编辑 → 切换 → 删除 → 排序 → 搜索 |
| **App Switching** | 切换 5 个 App → 验证数据隔离 → 验证 UI 状态 |
| **Session Management** | 列出会话 → 搜索 → 查看详情 → 发送消息 → 删除 |
| **Settings Workflow** | 8 个 tab 完整操作流程 |
| **MCP/Skill Integration** | 添加 → 启用/禁用 App → 删除 → 导入 |

### View Tests (界面细节)

| 界面 | 测试点 |
|------|--------|
| **Providers View** | 搜索、拖拽排序、状态指示（绿色边框）、空状态、代理状态显示 |
| **Sessions View** | 过滤、搜索、消息列表、发送测试、TOC 目录 |
| **Prompts View** | CRUD、启用/禁用、导入、Markdown 编辑器 |
| **Skills View** | 安装、卸载、App 切换、备份还原、导入 |
| **MCP View** | 添加服务器、编辑配置、App 切换、JSON 编辑器 |
| **OpenClaw Dashboard** | 8 个 tab、Gateway 连接、Channels 配置、Skills |
| **Universal Provider** | 通用供应商表单、配置保存 |

### Settings Tests (已存在，需更新)

| Tab | 新增测试点 |
|-----|-----------|
| Models | Agent 默认配置、模型测试 |
| General | 语言切换、主题切换、窗口设置 |
| Proxy | 启动/停止、端口配置、故障转移 |
| Auth | OAuth 流程、认证状态 |
| Env | 环境变量 CRUD、App 切换 |
| Advanced | 导入/导出、备份、日志配置 |
| Usage | 统计显示、数据刷新 |
| About | 版本信息、工具版本检测 |

---

## 7. AI Dev Loop Integration

### Test Layer Configuration

```typescript
// scripts/ai-dev-loop/loop.ts
const DEFAULT_CONFIG: LoopConfig = {
  layers: [
    { name: 'unit', command: 'bun vitest run', timeout: 120000, priority: 1 },
    { name: 'rust', command: 'cargo test --manifest-path src-tauri/Cargo.toml', timeout: 300000, priority: 2 },
    { name: 'integration', command: 'bun vitest run tests/integration', timeout: 300000, priority: 3 },
    { name: 'tauri-e2e', command: 'bunx wdio run wdio.conf.ts', timeout: 1800000, priority: 4 }, // 30 分钟
  ],
};
```

### WDIO Configuration Update

```typescript
// wdio.conf.ts
specs: [
  // 分组运行，避免超时
  './tests/e2e/tauri/flows/*.spec.ts',
  './tests/e2e/tauri/views/*.spec.ts',
  './tests/e2e/tauri/settings-full.spec.ts',
],
```

---

## 8. Implementation Plan

### Hour 1-2: Infrastructure

1. 创建 `pages/BasePage.ts`
2. 创建 `utils/data-manager.ts`
3. 创建 `utils/test-helpers.ts`
4. 创建 `utils/external-deps.ts`
5. 更新 `wdio.conf.ts` 支持分组运行

### Hour 3-4: Core Flow Tests

1. `flows/provider-lifecycle.spec.ts`
2. `flows/app-switching.spec.ts`
3. `flows/session-management.spec.ts`
4. `flows/settings-workflow.spec.ts`
5. `flows/mcp-skill-integration.spec.ts`

### Hour 5-6: View Tests

1. `pages/ProvidersPage.ts` + `views/providers-view.spec.ts`
2. `pages/SessionsPage.ts` + `views/sessions-view.spec.ts`
3. `pages/PromptsPage.ts` + `views/prompts-view.spec.ts`
4. `pages/SkillsPage.ts` + `views/skills-view.spec.ts`
5. `pages/McpPage.ts` + `views/mcp-view.spec.ts`
6. `views/openclaw-dashboard.spec.ts`
7. `views/universal-provider.spec.ts`

### Hour 7: Run & Fix

1. 运行完整测试套件
2. 分析失败用例
3. AI 自主修复发现的问题
4. 验证修复

### Hour 8: Regression

1. 全量回归测试
2. 最终验证
3. 清理和文档

---

## 9. Success Criteria

- [ ] 所有 10 个界面有对应的 Page Object
- [ ] 5 个核心流程测试全部通过
- [ ] 7 个界面细节测试覆盖主要操作
- [ ] 测试数据管理：备份/还原可靠
- [ ] 外部依赖：无 token 时正确跳过
- [ ] AI Dev Loop：能在 30 分钟内完成 Tauri E2E 层