# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**Haipee**（v3.12.3）是一个 Tauri v2 + React + TypeScript 桌面应用，用于统一管理和切换多个 AI CLI 工具（Claude Code、Codex、Gemini CLI 等）的供应商配置。

- 前端：React 18 + TypeScript + Tailwind CSS，通过 Vite 构建
- 后端：Rust（Tauri v2.8.2），管理配置文件、数据库（SQLite）、代理、MCP 服务
- 包管理：**bun**（不用 npm/pnpm/yarn）
- 平台：macOS、Windows、Linux

---

## 开发命令

```bash
# 安装依赖
bun install

# 开发模式（启动 Vite + Tauri 热重载）
bun run dev

# 仅启动前端 Vite 开发服务器（端口 3000）
bun run dev:renderer

# 构建发布包
bun run build

# TypeScript 类型检查
bun run typecheck

# 格式化代码
bun run format
bun run format:check          # 检查格式化（CI 用）

# 开发工具
bun run dev:devtools          # 带 DevTools 的开发模式（试用功能）
bun run gen:test              # 生成测试文件模板
```

---

## 测试命令

```bash
# JS 单元测试（Vitest）
bun run test:unit
bun run test:unit:watch        # 监听模式

# Rust 后端测试（cargo test）
cargo test --manifest-path src-tauri/Cargo.toml

# Tauri WebView E2E（真实 WKWebView，通过 tauri-plugin-webdriver）
bun run test:e2e:tauri:build   # 首次需要编译（约 2-3 分钟）
bun run test:e2e:tauri         # 运行 WebdriverIO 测试

# 运行特定测试层
bun run test:layer <layer>     # layer: unit, rust, integration, tauri-e2e

# AI 自主开发循环（4层测试 + Claude 自动修复）
bun run ai:dev                 # 启动循环
bun run ai:dev:resume          # 从最新检查点恢复
bun run ai:dev:dry             # 演练（不提交修复）
bun run ai:dev:checkpoints     # 列出所有检查点
```

> **Tauri E2E 前置条件（macOS）：**
> ```bash
> sudo safaridriver --enable   # 只需执行一次
> ```

---

## TDD 工作流

### Rust 后端 TDD

```bash
# Red：写失败测试（src-tauri/tests/ 或 src-tauri/src/commands/）
# Green：实现最小代码
cargo test --manifest-path src-tauri/Cargo.toml --color always
# Refactor：无 warning
cargo clippy --manifest-path src-tauri/Cargo.toml
```

### 前端 TDD（TypeScript/React）

```bash
# Red：在 tests/ 下写失败测试（.test.tsx / .test.ts）
# Green：实现组件/逻辑
bun run test:unit
```

### 浏览器调试（无需启动 Tauri）

`src/lib/browser-mock.ts` 会在非 Tauri 环境下自动 mock 所有 IPC 调用，让应用可以在普通浏览器中运行：

```bash
bun run dev:renderer   # 启动 Vite 开发服务器（http://localhost:3000）
# 然后直接用浏览器或 Playwright MCP 访问 http://localhost:3000
```

如果某个 `invoke('cmd_name')` 在浏览器中报错，在 `src/lib/browser-mock.ts` 里添加对应的 mock 即可。

---

## 代码架构

### 目录结构

```
src/                        # React 前端
  App.tsx                   # 根组件
  components/               # UI 组件
    providers/              # 供应商管理组件
    settings/               # 设置面板组件
    sessions/               # 会话管理组件
    prompts/                # 提示词组件
    skills/                 # 技能组件
    mcp/                    # MCP 服务器组件
    agents/                 # 代理组件
    navigation/             # 导航组件
    openclaw/               # OpenClaw 组件
  config/                   # 供应商配置定义
  contexts/                 # React Context
  hooks/                    # 自定义 hooks
  i18n/                     # 国际化（中/英）
  lib/
    api/                    # Tauri IPC API 封装
    browser-mock.ts         # 非 Tauri 环境下的 IPC mock
  utils/                    # 工具函数

src-tauri/                  # Rust 后端
  src/
    lib.rs                  # Tauri Builder 入口，插件注册
    main.rs                 # 二进制入口
    commands/               # Tauri IPC 命令（#[tauri::command]）
    services/               # 业务逻辑层（配置、代理、MCP 等）
    app_config.rs           # 多 app 配置管理
    settings.rs             # 应用设置
    store.rs                # tauri-plugin-store 封装
    panic_hook.rs           # 崩溃日志（写入 ~/.cc-switch/crash.log）
  tests/                    # Rust 集成测试
  capabilities/             # Tauri IPC 权限声明
  Cargo.toml                # Rust 依赖

tests/                      # JS/TS 测试
  components/               # React 组件单元测试（Vitest）
  hooks/                    # Hook 单元测试
  utils/                    # 工具函数测试
  config/                   # 配置预设测试
  msw/                      # Mock Service Worker 配置
  integration/              # 集成测试
  e2e/tauri/                # Tauri WebView E2E（WebdriverIO）
    providers/              # 供应商测试（5 个 spec 文件，50 个测试）
    settings/               # 设置测试（6 个 spec 文件，78 个测试）
    agents/                 # 代理测试
    skills/                 # 技能测试
    mcp/                    # MCP 服务器测试
    prompts/                # 提示词测试
    sessions/               # 会话测试
    navigation/             # 导航测试
    openclaw/               # OpenClaw 测试
    universal/              # 统一供应商测试
    flows/                  # 端到端流程测试
    views/                  # 视图测试
    pages/                  # Page Object Models（13 个页面对象）
    fixtures/               # 测试数据生成器
    setup/                  # 测试启动/清理
  setupGlobals.ts           # 全局测试设置
  setupTests.ts             # 测试环境初始化

scripts/ai-dev-loop/        # AI 自主开发循环
  index.ts                  # CLI 入口
  loop.ts                   # 主循环逻辑（4 层测试迭代）
  test-runner.ts            # 各层测试执行器
  failure-parser.ts         # 错误解析（Vitest/Cargo/WebdriverIO）
  fix-orchestrator.ts       # 调用 claude CLI 自动修复
  checkpoint.ts             # 检查点持久化
  types.ts                  # 类型定义
  logger.ts                 # 日志输出
```

### Tauri IPC 模式

前端通过 `@tauri-apps/api` 调用后端命令：
```typescript
import { invoke } from '@tauri-apps/api/core';
const configs = await invoke('list_app_configs');
```

Rust 端用 `#[tauri::command]` 注解，在 `lib.rs` 中通过 `.invoke_handler(tauri::generate_handler![...])` 注册。新增命令还需要在 `src-tauri/capabilities/` 下添加对应权限。

### 数据存储

- **SQLite** (`~/.cc-switch/cc-switch.db`)：供应商配置、会话等
- **tauri-plugin-store**：应用设置（主题、语言等）
- **OpenClaw Profile**：`~/.openclaw-haipee/` 目录

---

## E2E 测试架构

### 测试覆盖统计

| 模块 | Spec 文件 | 测试用例 |
|------|-----------|----------|
| Providers | 5 | 50 |
| Settings | 6 | 78 |
| Agents/Skills/MCP/Prompts/Sessions | 5 | 56 |
| Navigation/OpenClaw/Universal | 5 | 50 |
| Legacy (flows/views) | 9 | 105 |
| Channel Communication | 1 | 4 |
| **总计** | **31** | **343** |

### Page Object Models

位于 `tests/e2e/tauri/pages/`，共 13 个页面对象：

- `TauriBasePage.ts` - 基础页面对象，提供通用方法
- `NavigationPage.ts` - 导航和 App 切换
- `ProviderPage.ts` - 供应商管理
- `SettingsPage.ts` - 设置面板
- `SessionManagerPage.ts` - 会话管理
- `PromptsPage.ts` - 提示词管理
- `SkillsPage.ts` - 技能列表
- `McpServersPage.ts` - MCP 服务器
- `AgentsPage.ts` - 代理管理
- `OpenClawGatewayPage.ts` - OpenClaw 网关
- `OpenClawChannelsPage.ts` - OpenClaw 频道
- `OpenClawSkillsMcpPage.ts` - OpenClaw Skills/MCP
- `UniversalProviderPage.ts` - 统一供应商

### WKWebView 兼容性

Tauri E2E 测试在 macOS 上使用 WKWebView（WebKit），有以下限制：

1. **不支持 `:has-text()` 伪选择器** - 在 `wdio.conf.ts` 中通过 `browser.execute()` 实现文本搜索
2. **`isDisplayed()` 始终返回 false** - 通过检查 CSS 属性（display, visibility, opacity）判断可见性
3. **元素查找** - 使用 `data-testid` 属性作为主要选择器

```typescript
// 示例：通过 data-testid 查找元素
const btn = await $('[data-testid="provider-add-btn"]');

// 示例：检查元素可见性
const isVisible = await browser.execute((sel) => {
  const el = document.querySelector(sel);
  if (!el) return false;
  const style = window.getComputedStyle(el);
  return style.display !== 'none' && style.visibility !== 'hidden';
}, '[data-testid="my-element"]');
```

---

## AI 自主开发循环

`scripts/ai-dev-loop/` 实现了一个 10 小时无人值守的自修复开发循环，按优先级依次运行 4 个测试层：

| 优先级 | 层名 | 命令 | 超时 |
|--------|------|------|------|
| 1 | `unit` | `bun vitest run` | 2 分钟 |
| 2 | `rust` | `cargo test --manifest-path src-tauri/Cargo.toml` | 5 分钟 |
| 3 | `integration` | `bun vitest run tests/integration` | 5 分钟 |
| 4 | `tauri-e2e` | `bunx wdio run wdio.conf.ts` | 30 分钟 |

**跳过规则：**
- `integration` 在 unit 失败时跳过
- `tauri-e2e` 在 rust 或 integration 失败时跳过（二进制不可信）

**修复流程：** 解析失败 → 构建上下文（源文件 + 错误）→ 调用 `claude -p <prompt>` → 应用 XML 文件块 → 重跑测试 → 失败则回滚

---

## Cargo Features

```toml
webdriver = ["tauri-plugin-webdriver"]   # 启用 WebDriver E2E 端点（port 4445）
test-hooks = []                          # 测试专用 hook（集成测试用）
devtools = ["tauri-plugin-devtools"]     # CrabNebula DevTools（试用，2026-04-01 后移除）
```

构建带 WebDriver 支持的二进制：
```bash
cargo build --manifest-path src-tauri/Cargo.toml --features webdriver
```

---

## 关键配置文件

| 文件 | 用途 |
|------|------|
| `vite.config.ts` | Vite 配置，开发端口 **3000** |
| `src-tauri/tauri.conf.json` | Tauri 主配置，`devUrl: http://localhost:3000` |
| `wdio.conf.ts` | WebdriverIO Tauri E2E（连接 localhost:4445，测试真实 WebView） |
| `vitest.config.ts` | Vitest 单元/集成测试配置 |
| `tailwind.config.cjs` | Tailwind CSS 配置 |
| `postcss.config.cjs` | PostCSS 配置 |
| `src-tauri/capabilities/` | Tauri IPC 权限声明（新命令需在此添加） |

---

## 重要约定

1. **包管理用 `bun`**，不用 npm/pnpm。运行脚本：`bun run <script>`，执行包：`bunx <pkg>`
2. **Rust 代码不用 bun 管理**，直接用 `cargo`
3. **不修改 `src-tauri/target/`** 目录（构建产物）
4. **供应商配置**定义在 `src/config/` 下，不在数据库 schema 里硬编码
5. **i18n**：所有用户可见字符串走 `src/i18n/` 的翻译 key，支持中/英切换
6. **新 Tauri 命令**需要同时：① `#[tauri::command]` + `generate_handler!` 注册，② 在 `capabilities/` 添加权限
7. **browser-mock.ts**：浏览器调试时自动 mock IPC，添加新命令的 mock 在此文件里维护
8. **E2E 测试**使用 `data-testid` 属性定位元素，新增 UI 组件需添加 testid