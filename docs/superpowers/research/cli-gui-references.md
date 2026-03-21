# CLI GUI 开源项目研究

## Claude Code GUI

| 项目 | 描述 | 技术栈 | Stars |
|------|------|--------|-------|
| [Norman-else/claude-workbench](https://github.com/Norman-else/claude-workbench) | Modern GUI for Claude Code CLI, AI Assistant built-in | Tauri | - |
| [badlogic/claude-gui](https://github.com/badlogic/claude-gui) | Bi-directional websocket wrapper for non-TUI interfaces | Rust/WebSocket | - |
| [CristianDArrigo/claude-forge](https://github.com/CristianDArrigo/claude-forge) | Desktop GUI for Claude Code with project management | Tauri | - |
| [knqiufan/Misaka](https://github.com/knqiufan/Misaka) | Claude Code 桌面GUI客户端 (Python/Flet), Material Design 3 | Python/Flet | - |
| [GTFerguson/cade](https://github.com/GTFerguson/cade) | Agentic Development Environment, VIM+TMUX inspired | - | - |
| [youssefabdelrhim2000/claude-code-web](https://github.com/youssefabdelrhim2000/claude-code-web) | Web chat interface for claude-code-api | Web | - |

**关键特性参考：**
- Multi-turn streaming conversations
- Session management
- File tree browsing
- MCP server integration
- Material Design 3 interface
- Built-in AI Assistant

## Codex CLI GUI

| 项目 | 描述 | 技术栈 |
|------|------|--------|
| [garyohosu/CodexGUI](https://github.com/garyohosu/CodexGUI) | Qt/PySide6 GUI wrapper for OpenAI Codex CLI | Python/Qt |

## Gemini CLI GUI

| 项目 | 描述 | 技术栈 |
|------|------|--------|
| [MarkShawn2020/gemiui](https://github.com/MarkShawn2020/gemiui) | Modern GUI for Gemini CLI | Electron/React/shadcn/ui |
| [tcmartin/gemmit](https://github.com/tcmartin/gemmit) | GUI-based AI vibe coding, free requests | - |

## OpenCode GUI

| 项目 | 描述 | 技术栈 |
|------|------|--------|
| [akemmanuel/OpenGUI](https://github.com/akemmanuel/OpenGUI) | Graphical desktop interface for OpenCode | - |
| [HALDRO/PrimeCode](https://github.com/HALDRO/PrimeCode) | OpenCode GUI for VS Code | VS Code Extension |
| [ktmage/opencode-gui](https://github.com/ktmage/opencode-gui) | VS Code sidebar chat interface | VS Code Extension |

## 共同功能模式

### 对话功能
1. **消息列表**: 滚动消息历史，区分用户/AI
2. **输入框**: 多行文本输入，支持快捷键发送
3. **流式响应**: 打字机效果显示AI回复
4. **代码块**: 语法高亮，复制按钮
5. **文件附件**: 拖放或选择文件

### 会话管理
1. **会话列表**: 侧边栏显示历史会话
2. **新建会话**: 清除上下文开始新对话
3. **会话标题**: 自动生成或手动编辑
4. **搜索过滤**: 按关键词查找历史会话

### UI设计模式
1. **三栏布局**: 会话列表 | 对话区 | 详情/设置
2. **命令面板**: /slash commands 快捷输入
3. **工具栏**: 常用操作快捷按钮
4. **主题切换**: 深色/浅色模式

## 技术实现参考

### 流式对话实现
```typescript
// WebSocket or EventSource for streaming
const eventSource = new EventSource('/api/chat/stream');
eventSource.onmessage = (event) => {
  const chunk = JSON.parse(event.data);
  appendMessage(chunk.content);
};
```

### 消息组件结构
```typescript
interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  attachments?: Attachment[];
  thinking?: string; // For reasoning models
}
```

### 会话状态管理
```typescript
interface Session {
  id: string;
  title: string;
  messages: Message[];
  createdAt: number;
  updatedAt: number;
  providerId: string;
}
```

## 待研究项目

- [ ] Misaka (Python/Flet) - 深入了解Material Design 3实现
- [ ] gemiui (Electron/React) - shadcn/ui组件使用
- [ ] claude-forge (Tauri) - 桌面端最佳实践
- [ ] claude-workbench - MCP server集成方式
