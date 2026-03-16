# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**Haipee** 是一个 Tauri v2 + React + TypeScript 桌面应用，用于统一管理和切换多个 AI CLI 工具（Claude Code、Codex、Gemini CLI 等）的供应商配置。

- 前端：React 18 + TypeScript + Tailwind CSS，通过 Vite 构建
- 后端：Rust（Tauri v2.10），管理配置文件、数据库（SQLite）、代理、MCP 服务
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
```

---

## 测试命令

```bash
# JS 单元测试（Vitest）
bun run test:unit
bun run test:unit:watch        # 监听模式

# Playwright E2E（测试 Vite renderer，无 Tauri IPC）
bun run test:e2e
bun run test:e2e:ui            # 交互 UI 模式

# Rust 后端测试（cargo test）
cargo test --manifest-path src-tauri/Cargo.toml

# Tauri WebView E2E（真实 WKWebView，通过 tauri-plugin-webdriver）
bun run test:e2e:tauri:build   # 首次需要编译（约 2-3 分钟）
bun run test:e2e:tauri         # 运行 WebdriverIO 测试

# AI 自主开发循环（5层测试 + Claude 自动修复）
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
  config/                   # 供应商配置定义
  contexts/                 # React Context
  hooks/                    # 自定义 hooks
  i18n/                     # 国际化（中/英）
  lib/
    browser-mock.ts         # 非 Tauri 环境下的 IPC mock（浏览器调试用）
  utils/                    # 工具函数

src-tauri/                  # Rust 后端
  src/
    lib.rs                  # Tauri Builder 入口，插件注册
    main.rs                 # 二进制入口
    commands/               # Tauri IPC 命令（#[tauri::command]）
    services/               # 业务逻辑层（配置、代理、MCP 等）
    app_config.rs           # 多 app 配置管理
    settings.rs             # 应用设置
    panic_hook.rs           # 崩溃日志（写入 ~/.cc-switch/crash.log）
  tests/                    # Rust 集成测试（cargo test）
  Cargo.toml                # Rust 依赖

tests/                      # JS/TS 测试
  components/               # React 组件单元测试（Vitest）
  hooks/                    # Hook 单元测试
  utils/                    # 工具函数测试
  integration/              # 集成测试
  e2e/
    providers/              # API 供应商 E2E（Playwright，直接调 API）
    tauri/                  # Tauri WebView E2E（WebdriverIO + tauri-plugin-webdriver）
    pages/                  # Page Object Models
    setup/                  # global-setup/teardown，tauri-setup/teardown

scripts/ai-dev-loop/        # AI 自主开发循环
  index.ts                  # CLI 入口
  loop.ts                   # 主循环逻辑（5 层测试迭代）
  test-runner.ts            # 各层测试执行器
  failure-parser.ts         # 错误解析（Vitest/Playwright/Cargo/WebdriverIO）
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
- **旧格式迁移**：`config.json` → SQLite（`lib.rs` setup 阶段自动处理）

---

## API 供应商配置

Playwright E2E 测试（`tests/e2e/providers/`）直接调用真实 API，需要在 `.env` 中配置 token：

| 供应商 | 环境变量 | API 端点 | 兼容格式 |
|--------|----------|----------|----------|
| NVIDIA NIM | `NVIDIA_TOKEN` | `https://integrate.api.nvidia.com/v1` | OpenAI |
| OpenAI | `OPENAI_TOKEN` | `https://api.openai.com/v1` | OpenAI (Reference) |
| Google Gemini | `GEMINI_TOKEN` | `https://generativelanguage.googleapis.com/v1beta/openai` | OpenAI ⚠️ |
| OpenCode Zen | `OPENCODE_TOKEN` | （见 spec 文件） | OpenAI |
| Kilo Code | `KILO_TOKEN` | （见 spec 文件） | OpenAI |
| Cloudflare | `CLOUDFLARE_API_TOKEN` | `https://api.cloudflare.com/client/v4/ai` | OpenAI |
| Poe | `POE_TOKEN` | （见 spec 文件） | OpenAI |
| XiaoMi MiNo | （内置） | （见 spec 文件） | OpenAI |

> ⚠️ **Gemini 注意**：使用 OpenAI 兼容端点 + `Authorization: Bearer` header，**不是** 原生 Gemini API（`?key=` query param）。

---

## AI 自主开发循环

`scripts/ai-dev-loop/` 实现了一个 10 小时无人值守的自修复开发循环，按优先级依次运行 5 个测试层：

| 优先级 | 层名 | 命令 | 超时 |
|--------|------|------|------|
| 1 | `unit` | `bun vitest run` | 2 分钟 |
| 2 | `rust` | `cargo test --manifest-path src-tauri/Cargo.toml` | 5 分钟 |
| 3 | `integration` | `bun vitest run tests/integration` | 5 分钟 |
| 4 | `e2e` | `bun playwright test` | 15 分钟 |
| 5 | `tauri-e2e` | `bunx wdio run wdio.conf.ts` | 20 分钟 |

**跳过规则：**
- `integration` 在 unit 失败时跳过
- `e2e` 在 unit 或 integration 失败时跳过
- `tauri-e2e` 在 rust 或 integration 失败时跳过（二进制不可信）

**修复流程：** 解析失败 → 构建上下文（源文件 + 错误）→ 调用 `claude -p <prompt>` → 应用 XML 文件块 → 重跑测试 → 失败则回滚

---

## Cargo Features

```toml
webdriver = ["tauri-plugin-webdriver"]   # 启用 WebDriver E2E 端点（port 4444）
test-hooks = []                          # 测试专用 hook（集成测试用）
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
| `playwright.config.ts` | Playwright E2E（连接 localhost:3000，测试 Vite renderer） |
| `wdio.conf.ts` | WebdriverIO Tauri E2E（连接 localhost:4444，测试真实 WebView） |
| `vitest.config.ts` | Vitest 单元/集成测试配置 |
| `tailwind.config.cjs` | Tailwind CSS 配置 |
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


## 项目概述

**Haipee** 是一个 Tauri v2 + React + TypeScript 桌面应用，用于统一管理和切换多个 AI CLI 工具（Claude Code、Codex、Gemini CLI 等）的供应商配置。

- 前端：React 18 + TypeScript + Tailwind CSS，通过 Vite 构建
- 后端：Rust（Tauri v2.10），管理配置文件、数据库（SQLite）、代理、MCP 服务
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
```

---

## 测试命令

```bash
# JS 单元测试（Vitest）
bun run test:unit
bun run test:unit:watch        # 监听模式

# Playwright E2E（测试 Vite renderer，无 Tauri IPC）
bun run test:e2e
bun run test:e2e:ui            # 交互 UI 模式

# Rust 后端测试（cargo test）
cargo test --manifest-path src-tauri/Cargo.toml

# Tauri WebView E2E（真实 WKWebView，通过 tauri-plugin-webdriver）
bun run test:e2e:tauri:build   # 首次需要编译（约 2-3 分钟）
bun run test:e2e:tauri         # 运行 WebdriverIO 测试

# AI 自主开发循环（5层测试 + Claude 自动修复）
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

## 代码架构

### 目录结构

```
src/                        # React 前端
  App.tsx                   # 根组件
  components/               # UI 组件
  config/                   # 供应商配置定义
  contexts/                 # React Context
  hooks/                    # 自定义 hooks
  i18n/                     # 国际化（中/英）
  utils/                    # 工具函数

src-tauri/                  # Rust 后端
  src/
    lib.rs                  # Tauri Builder 入口，插件注册
    main.rs                 # 二进制入口
    commands/               # Tauri IPC 命令（#[tauri::command]）
    services/               # 业务逻辑层（配置、代理、MCP 等）
    app_config.rs           # 多 app 配置管理
    settings.rs             # 应用设置
    panic_hook.rs           # 崩溃日志
  tests/                    # Rust 集成测试（cargo test）
  Cargo.toml                # Rust 依赖（bun 不管理 Rust 依赖）

tests/                      # JS/TS 测试
  components/               # React 组件单元测试（Vitest）
  hooks/                    # Hook 单元测试
  utils/                    # 工具函数测试
  integration/              # 集成测试
  e2e/
    providers/              # API 供应商 E2E（Playwright，直接调 API）
    tauri/                  # Tauri WebView E2E（WebdriverIO + tauri-plugin-webdriver）
    pages/                  # Page Object Models
    setup/                  # globalSetup/Teardown，tauri-setup/teardown

scripts/ai-dev-loop/        # AI 自主开发循环
  index.ts                  # CLI 入口
  loop.ts                   # 主循环逻辑（5 层测试迭代）
  test-runner.ts            # 各层测试执行器
  failure-parser.ts         # 错误解析（Vitest/Playwright/Cargo/WebdriverIO）
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

Rust 端用 `#[tauri::command]` 注解，在 `lib.rs` 中通过 `.invoke_handler(tauri::generate_handler![...])` 注册。

### 数据存储

- **SQLite** (`~/.cc-switch/cc-switch.db`)：供应商配置、会话等
- **tauri-plugin-store**：应用设置（主题、语言等）
- **旧格式迁移**：`config.json` → SQLite（`lib.rs` setup 阶段自动处理）

---

## AI 自主开发循环

`scripts/ai-dev-loop/` 实现了一个 10 小时无人值守的自修复开发循环，按优先级依次运行 5 个测试层：

| 优先级 | 层名 | 命令 | 超时 |
|--------|------|------|------|
| 1 | `unit` | `bun vitest run` | 2 分钟 |
| 2 | `rust` | `cargo test --manifest-path src-tauri/Cargo.toml` | 5 分钟 |
| 3 | `integration` | `bun vitest run tests/integration` | 5 分钟 |
| 4 | `e2e` | `bun playwright test` | 15 分钟 |
| 5 | `tauri-e2e` | `bunx wdio run wdio.conf.ts` | 20 分钟 |

**跳过规则：**
- `integration` 在 unit 失败时跳过
- `e2e` 在 unit 或 integration 失败时跳过
- `tauri-e2e` 在 rust 或 integration 失败时跳过（二进制不可信）

**修复流程：** 解析失败 → 构建上下文（源文件 + 错误）→ 调用 `claude -p <prompt>` → 应用 XML 文件块 → 重跑测试 → 失败则回滚

---

## Cargo Features

```toml
webdriver = ["tauri-plugin-webdriver"]   # 启用 WebDriver E2E 端点（port 4444）
test-hooks = []                          # 测试专用 hook（集成测试用）
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
| `playwright.config.ts` | Playwright E2E（连接 localhost:3000，测试 Vite renderer） |
| `wdio.conf.ts` | WebdriverIO Tauri E2E（连接 localhost:4444，测试真实 WebView） |
| `vitest.config.ts` | Vitest 单元/集成测试配置 |
| `tailwind.config.cjs` | Tailwind CSS 配置 |

---

## 重要约定

1. **包管理用 `bun`**，不用 npm/pnpm。运行脚本：`bun run <script>`，执行包：`bunx <pkg>`
2. **Rust 代码不用 bun 管理**，直接用 `cargo`
3. **不修改 `src-tauri/target/`** 目录（构建产物）
4. **供应商配置**定义在 `src/config/` 下，不在数据库 schema 里硬编码
5. **i18n**：所有用户可见字符串走 `src/i18n/` 的翻译 key，支持中/英切换
6. **Tauri 命令**需要在 `src-tauri/capabilities/` 下添加对应 capability 权限才能调用

---

## 提交历史（AI dev loop 相关）

| Hash | 说明 |
|------|------|
| `bacced47` | feat: 实现真实 Tauri WebView E2E via tauri-plugin-webdriver |
| `be7ca155` | fix: 添加 Rust 测试层 + 修复 E2E 端口 (1420→3000) |
| `311fda01` | fix: 完善 AI 自主开发循环（callClaudeAgent、failure parsing 等） |
| `bac7349d` | feat: 添加 AI 自主开发循环初始版本 |
