# Tauri 项目使用 AI SDK 的架构对比

## 方案 1: Node.js Sidecar（可以使用 Vercel AI SDK）

```
┌─────────────────────────────────────────────────────────────┐
│                     Tauri Desktop App                        │
│  ┌─────────────────┐  ┌─────────────────────────────────┐  │
│  │  Frontend       │  │  Rust Backend                   │  │
│  │  (React)        │◄─┤  - Tauri Commands               │  │
│  └─────────────────┘  │  - 系统交互                     │  │
│           │           └─────────────────────────────────┘  │
│           │                          │                     │
│           │ IPC                      │ spawn               │
│           ▼                          ▼                     │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Node.js Sidecar Process                 │  │
│  │  ┌─────────────────────────────────────────────┐   │  │
│  │  │  Vercel AI SDK (@ai-sdk/openai, etc.)        │   │  │
│  │  │  - Streaming                                │   │  │
│  │  │  - Tool Calling                             │   │  │
│  │  │  - Structured Output                        │   │  │
│  │  └─────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 实现方式

```javascript
// sidecar/node-bridge.js
const { openai } = require('@ai-sdk/openai');
const { streamText } = require('ai');

async function handleRequest(provider, messages) {
  const result = await streamText({
    model: openai('gpt-4o'),
    messages,
  });
  return result.toDataStream();
}

// 通过 stdio 或 local socket 与 Rust 通信
process.stdin.on('data', async (data) => {
  const request = JSON.parse(data);
  const response = await handleRequest(request.provider, request.messages);
  process.stdout.write(JSON.stringify(response));
});
```

```rust
// src-tauri/src/ai_sdk_bridge.rs
use std::process::Command;

pub async fn call_ai_sdk(provider: &str, messages: Value) -> Result<String> {
    let output = Command::new("node")
        .arg("sidecar/node-bridge.js")
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .spawn()?;

    // 通过 stdin 发送请求，stdout 接收响应
    // ...
}
```

### 缺点

| 问题 | 影响 |
|------|------|
| **打包体积** | 需要嵌入 Node.js runtime (~30-50MB) |
| **内存占用** | Node.js 进程常驻内存 (~100MB+) |
| **启动速度** | 需要启动 Node.js sidecar |
| **调试复杂度** | 需要管理两个运行时之间的通信 |
| **更新维护** | Node.js 依赖需要单独管理 |

---

## 方案 2: Rust Native（当前方案）

```
┌─────────────────────────────────────────────────────────────┐
│                     Tauri Desktop App                        │
│  ┌─────────────────┐  ┌─────────────────────────────────┐  │
│  │  Frontend       │  │  Rust Backend                   │  │
│  │  (React)        │◄─┤  - HTTP Client (reqwest)        │  │
│  └─────────────────┘  │  - Provider Adapters              │  │
│                       │  - Streaming SSE                  │  │
│                       │  - Auth Management                │  │
│                       └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP
                              ▼
                    ┌─────────────────┐
                    │  AI APIs        │
                    └─────────────────┘
```

### 优点

| 方面 | 说明 |
|------|------|
| **打包体积** | 单一二进制，无额外 runtime (~10-20MB 总大小) |
| **内存占用** | Rust 高效内存管理，通常 <50MB |
| **启动速度** | 毫秒级启动 |
| **安全性** | API keys 完全在 Rust 层，无泄露风险 |
| **性能** | 原生编译，无 JS 运行时开销 |

---

## Rust 生态中的 AI SDK 现状

### 目前可用的 Rust AI SDK

| SDK | 供应商 | 成熟度 | 功能 |
|-----|--------|--------|------|
| `async-openai` | OpenAI | ⭐⭐⭐⭐⭐ | 完整支持，包括 Assistants、Realtime |
| `anthropic` | Claude | ⭐⭐⭐⭐ | 官方 Rust SDK，功能完整 |
| `google-generative-ai-rs` | Gemini | ⭐⭐⭐ | 社区维护，基本功能 |
| `rig` | 多供应商 | ⭐⭐⭐ | 新兴框架，类似 AI SDK 的设计 |

### 对比 Vercel AI SDK

| 功能 | Vercel AI SDK (JS) | Rust 生态 |
|------|-------------------|-----------|
| 多供应商统一接口 | ✅ | ⚠️ 需自己封装或等 `rig` 成熟 |
| 流式响应 (SSE) | ✅ | ✅ `async-openai` 等支持 |
| 工具调用 (Tools) | ✅ | ✅ `async-openai` 支持 |
| 结构化输出 | ✅ | ✅ 通过 serde 实现 |
| Agent/多步推理 | ✅ | ⚠️ 需自己实现 |
| 嵌入 (Embeddings) | ✅ | ✅ 支持 |

---

## 推荐方案

### 对于当前项目（Haipee）

**保持 Rust Native 架构**，但可以改进：

```rust
// 使用成熟的 Rust SDK 替代手写 HTTP 调用

// OpenAI
use async_openai::Client as OpenAIClient;

// Anthropic
use anthropic::Client as AnthropicClient;

// Gemini (暂时用 HTTP，等 SDK 成熟)
```

### 如果一定要用 Vercel AI SDK

**方案 A: WASM (有限支持)**
- 部分 `@ai-sdk` 包可编译为 WASM
- 但 Node.js 特定功能（如流式）无法使用
- **不推荐**

**方案 B: tauri-shell 插件**
```rust
// 使用 tauri-plugin-shell 调用 npx ai
let output = shell()
    .command("npx")
    .args(["ai-sdk@latest", "generate", "--prompt", "Hello"])
    .output()
    .await?;
```
- 需要用户安装 Node.js
- **不推荐**

**方案 C: 内嵌 Node.js (sidecar)**
- 使用 `nodejs-mobile-gyp` 或类似方案
- 复杂度高，维护困难
- **不推荐**

---

## 结论

| 方案 | 可行性 | 推荐度 | 适用场景 |
|------|--------|--------|----------|
| Rust Native + SDK crates | ✅ | ⭐⭐⭐⭐⭐ | **当前最佳选择** |
| Rust Native + reqwest (当前) | ✅ | ⭐⭐⭐⭐ | 自定义需求高时 |
| Node.js Sidecar | ✅ | ⭐⭐ | 必须使用 AI SDK 功能时 |
| WASM | ⚠️ 有限 | ⭐ | 简单场景 |

### 建议

1. **继续使用 Rust Native**
2. **逐步引入成熟 crates**:
   ```toml
   # Cargo.toml
   [dependencies]
   async-openai = "0.28"  # OpenAI 完整支持
   anthropic = "0.3"       # Claude 官方 SDK
   ```
3. **关注 `rig` 框架发展** - 可能成为 Rust 版的 Vercel AI SDK

### 参考

- `async-openai`: https://github.com/64bit/async-openai
- `rig`: https://github.com/0xPlaygrounds/rig
- `anthropic-sdk-rust`: https://github.com/anthropics/anthropic-sdk-rust
