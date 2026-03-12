# Tauri E2E 测试实施计划

## 目标
为 .env 中的每个 API 供应商创建 E2E 测试，验证通过 UI 界面发送和接收消息的功能。

## API 供应商列表 (来自 .env)
1. **NVIDIA NIM** (nvapi-ajg5EZm...)
2. **XiaoMi MiNo** (sk-cyouu960w...)
3. **OpenAI** (sk-proj-y4SPqcZ...)
4. **Google Gemini** (AIzaSyC5Yain...)
5. **Cloudflare** (4bd454391e...)
6. **Poe** (a6vR1BtaWv...)
7. **OpenCode** (sk-umO6iZpa...)
8. **Kilo Code** (eyJhbGciOiJ...)
9. **Huawei** (9CTjWRE3f...)

## 技术方案分析

### 方案 1: Playwright + Tauri (推荐)
**状态**: ⚠️ 部分可行
- Tauri 官方支持 Playwright E2E 测试
- 需要运行 `bun run tauri dev` 启动桌面应用
- Claude Code 无法直接启动 Tauri 桌面应用（需要图形界面）

**实施方式**:
1. 安装 Playwright 和 @playwright/test
2. 配置 `playwright.config.ts` 适配 Tauri
3. 编写 Page Object Models
4. 用户本地运行测试

### 方案 2: Vercel Agent Browser
**状态**: ❌ 不适用
- Vercel Agent Browser 针对 Web 应用设计
- 无法直接测试 Tauri 桌面应用
- 仅当应用有 Web 部署版本时可用

### 方案 3: API 集成测试 + 组件测试
**状态**: ✅ 完全可行
- 使用 Vitest + MSW 测试 API 调用
- 使用 React Testing Library 测试组件交互
- 无需启动桌面应用

## 推荐方案: 混合策略

### Phase 1: API 集成测试 (可立即实施)
为每个供应商创建 API 测试，验证：
- API 认证成功
- 发送消息并接收响应
- 错误处理

### Phase 2: UI 组件测试 (可立即实施)
- 测试 Provider 配置表单
- 测试聊天界面交互
- 测试消息发送/接收流程

### Phase 3: Playwright E2E (需用户本地运行)
- 提供完整的 Playwright 配置
- 提供测试脚本
- 用户在本地运行完整 E2E 测试

## 实施步骤

### 任务 1: 安装 Playwright
```bash
cd /Users/a12/projects/skillhub/haipee
bun add -d @playwright/test
bunx playwright install
```

### 任务 2: 创建 Playwright 配置
文件: `playwright.config.ts`
- 配置 Tauri 应用启动
- 配置测试环境
- 配置截图/视频录制

### 任务 3: 创建 Page Object Models
文件: `tests/e2e/pages/OpenClawPage.ts`
- 封装 OpenClaw 配置页面操作
- 封装聊天界面操作
- 封装 Provider 切换操作

### 任务 4: 创建供应商 API 测试
为每个供应商创建测试文件:
- `tests/e2e/providers/nvidia.spec.ts`
- `tests/e2e/providers/openai.spec.ts`
- `tests/e2e/providers/gemini.spec.ts`
- ... (其他供应商)

### 任务 5: 创建 E2E 流程测试
- `tests/e2e/flows/send-message.spec.ts`
- `tests/e2e/flows/switch-provider.spec.ts`
- `tests/e2e/flows/configure-provider.spec.ts`

## 测试报告格式
```markdown
# E2E 测试报告

**日期**: 2026-03-12
**总测试数**: X
**通过**: Y (Z%)
**失败**: A

## 供应商测试结果
| 供应商 | 状态 | 响应时间 | 错误信息 |
|--------|------|----------|----------|
| NVIDIA | ✅ | 1.2s | - |
| OpenAI | ✅ | 0.8s | - |
| ... | | | |

## 失败详情
...
```

## 限制说明

### Claude Code 无法直接做到:
1. ❌ 启动 Tauri 桌面应用（需要图形界面）
2. ❌ 直接操作桌面应用 UI
3. ❌ 运行需要显示环境的 Playwright 测试

### Claude Code 可以做到:
1. ✅ 编写完整的 Playwright 测试代码
2. ✅ 创建 Page Object Models
3. ✅ 配置测试环境
4. ✅ 提供运行脚本和说明
5. ✅ 使用 Vercel Agent Browser 测试 Web 版本（如有）

## 用户需要做的:
1. 在本地运行 `bun run tauri dev` 启动应用
2. 运行 `bunx playwright test` 执行测试
3. 查看测试报告

## 预期输出
1. 完整的 Playwright 配置
2. 每个供应商的测试用例
3. 测试报告生成脚本
4. 运行说明文档
