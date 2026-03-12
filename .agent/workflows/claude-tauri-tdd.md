---
description: Claude Code Tauri TDD + Frontend Debug Workflow (inspired by Antigravity)
---

# Claude Code Tauri TDD & Frontend Debug Workflow

基于 Antigravity 工作流改进，适配 Claude Code 工具链的 Tauri 开发工作流。

## 1. 核心原则

- **TDD 分层**: Rust 后端 + TypeScript 前端独立测试
- **浏览器模拟**: 使用 `browser-mock.ts` 让应用在浏览器环境运行
- **自动化 UI 测试**: Playwright MCP 替代 `browser_subagent`
- **验证闭环**: 代码 → 测试 → 浏览器验证 → 修复

## 2. Backend TDD 循环 (Rust)

### Red - 编写失败测试
```rust
// src-tauri/src/commands/my_feature.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_my_feature() {
        let result = my_feature("input");
        assert_eq!(result, "expected");
    }
}
```

### Green - 最小实现
```rust
pub fn my_feature(input: &str) -> String {
    "expected".to_string()
}
```

### Verify - 运行测试
```bash
cargo test --manifest-path src-tauri/Cargo.toml --color always
```

### Refactor - 清理代码
```bash
cargo clippy --manifest-path src-tauri/Cargo.toml
```

## 3. Frontend TDD 循环 (TypeScript/React)

### Red - 编写失败测试
```typescript
// src/components/MyComponent.test.tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { MyComponent } from './MyComponent';

describe('MyComponent', () => {
  it('renders correctly', () => {
    render(<MyComponent />);
    expect(screen.getByText('Hello')).toBeInTheDocument();
  });
});
```

### Green - 实现组件
```typescript
export function MyComponent() {
  return <div>Hello</div>;
}
```

### Verify - 运行测试
```bash
bun run test:unit
```

## 4. Frontend Debug 工作流 (浏览器自动化)

### 准备工作
确保 `src/lib/browser-mock.ts` 已在 `main.tsx` 中导入：
```typescript
import './lib/browser-mock'; // Must be first
```

### Debug 循环
1. **启动 Dev Server**
   ```bash
   bun run dev:renderer  # 端口 3000
   ```

2. **Playwright MCP 验证** (替代 browser_subagent)
   ```
   使用 Playwright MCP:
   - 导航到 http://localhost:3000
   - 执行用户交互 (点击、输入)
   - 捕获控制台日志
   - 截图验证
   ```

3. **自动修复**
   - 分析控制台错误
   - 如果包含组件名或 Traceback，读取相关文件
   - 提出修复建议

### 常用 Debug 命令
```bash
# 检查 dev server 是否运行
lsof -i :3000

# 运行 Playwright 测试
bunx playwright test --ui

# 捕获浏览器日志
bunx playwright test debug.spec.ts
```

## 5. E2E 验证循环

### API 测试 (无需桌面应用)
```bash
# 测试所有供应商 API
bun run test:e2e

# 测试特定供应商
bunx playwright test providers/openai.spec.ts
```

### 桌面应用测试 (需本地运行)
```bash
# 1. 用户启动 Tauri 应用
bun run tauri dev

# 2. 运行 Playwright E2E 测试
bunx playwright test e2e/
```

## 6. 构建验证

```bash
# 验证完整构建
bun run tauri build

# 检查构建产物
ls -la src-tauri/target/release/bundle/
```

## 7. 工具对照表

| Antigravity 工具 | Claude Code 替代方案 | 用途 |
|-----------------|---------------------|------|
| `browser_subagent` | Playwright MCP | 浏览器自动化 |
| `capture_browser_console_logs` | `mcp__plugin_playwright__browser_console_messages` | 捕获日志 |
| `capture_browser_screenshot` | `mcp__plugin_playwright__browser_take_screenshot` | 截图 |
| `run_command` | `Bash` tool | 运行命令 |
| `task_boundary` | `Skill` tool | 任务边界 |

## 8. 最佳实践

### Mock 更新
当新增 Tauri 命令时，更新 `browser-mock.ts`：
```typescript
if (cmd === "new_command") {
  return { success: true };
}
```

### 测试隔离
- 单元测试: Vitest + React Testing Library
- 集成测试: MSW mock API
- E2E 测试: Playwright + 真实 API

### 错误处理
1. 控制台出现 `Uncaught ReferenceError` → 检查 imports
2. `invoke` 报错 → 检查 browser-mock.ts
3. 网络错误 → 检查 MSW handlers

// turbo-all
