# Chat Interface Design Reference

Date: 2026-03-21
Task: #51 Research Phase — CLI GUI Open Source Projects

## Projects Researched

| Project | Repo | Tech | Stars | Last Updated |
|---------|------|------|-------|--------------|
| Misaka | knqiufan/Misaka | Python/Flet | 3 | 2026-03-19 |
| gemiui | MarkShawn2020/gemiui | Electron/React/shadcn | 36 | 2025-08-03 |
| claude-forge | CristianDArrigo/claude-forge | Electron/React/Zustand | 3 | 2026-01-16 |
| claude-workbench | Norman-else/claude-workbench | Electron+Express/React | 6 | 2026-03-10 |

---

## 1. Conversation Message Component Design

### Data Model (from Misaka — most mature)

The most thoroughly designed message model is Misaka's `MessageContentBlock` union type, mirrored directly from Claude SDK's native format:

```typescript
// TypeScript equivalent of Misaka's Python MessageContentBlock dataclass
interface MessageContentBlock {
  type: "text" | "tool_use" | "tool_result" | "code" | "image" | "interrupted";
  // text block
  text?: string;
  // tool_use block
  id?: string;
  name?: string;
  input?: Record<string, unknown>;
  // tool_result block
  tool_use_id?: string;
  content?: string;
  is_error?: boolean;
  // code block
  language?: string;
  code?: string;
  // image block
  source_type?: "file" | "base64" | "url";
  file_path?: string;
  url?: string;
  media_type?: string;
  alt_text?: string;
  base64_data?: string;
}

interface Message {
  id: string;
  session_id: string;
  role: "user" | "assistant";
  content: string;  // JSON string of MessageContentBlock[]
  created_at: string;
  token_usage?: string;  // JSON of TokenUsageInfo
}

interface TokenUsageInfo {
  input_tokens: number;
  output_tokens: number;
  cache_read_input_tokens: number;
  cache_creation_input_tokens: number;
  cost_usd?: number;
}
```

### Message Item Layout Patterns

**Misaka pattern (recommended — most polished):**
- User messages: right-aligned bubble with 90%/10% spacer ratio, person icon avatar, semi-transparent primary color background, asymmetric border-radius (large left, small top-right)
- Assistant messages: left-aligned, starts with icon+label header row (Claude icon, role name, timestamp), followed by content blocks, then action row (copy/regenerate buttons)
- No borders on user messages, subtle card container on assistant messages

**gemiui pattern (simpler):**
- Both roles use `flex items-start space-x-3` layout
- User: `flex-row-reverse` to flip icon to right
- Icon badges: 32×32 rounded squares with role-specific background
- Single content field (no block breakdown) — plain text in a rounded container

**claude-workbench pattern (most feature-rich):**
- Uses `react-markdown` + `remark-gfm` for Markdown rendering
- Code syntax highlighting via `react-syntax-highlighter` with `oneDark` theme and `Prism`
- Tool call rendering inline with messages
- Attachment display with file icons

### Rendering Logic for Assistant Blocks

The key insight from Misaka is to pair `tool_use` + `tool_result` blocks before rendering:

```typescript
// Pair tool_use with tool_result before rendering
function pairToolBlocks(blocks: MessageContentBlock[]) {
  const resultMap = new Map<string, MessageContentBlock>();
  for (const block of blocks) {
    if (block.type === "tool_result" && block.tool_use_id) {
      resultMap.set(block.tool_use_id, block);
    }
  }
  const consumed = new Set<string>();
  const output: RenderedBlock[] = [];

  for (const block of blocks) {
    if (block.type === "tool_use" && block.id) {
      const result = resultMap.get(block.id);
      if (result) consumed.add(block.id);
      output.push({ type: "tool_call", block, result });
    } else if (block.type === "tool_result") {
      if (!block.tool_use_id || !consumed.has(block.tool_use_id)) {
        output.push({ type: "orphan_result", block });
      }
    } else {
      output.push({ type: "passthrough", block });
    }
  }
  return output;
}
```

Also worth noting: Misaka detects raw JSON text (starts with `{` or `[`, parses cleanly, length > 120) and renders a collapsible summary row instead of dumping the JSON inline — a useful UX optimization.

---

## 2. Session Management Mechanism

### Data Model

**Misaka `ChatSession`:**
```typescript
interface ChatSession {
  id: string;           // UUID
  title: string;        // "New Chat" default
  model: string;
  system_prompt: string;
  working_directory: string;
  project_name: string;
  sdk_session_id: string;  // Claude SDK session continuity ID
  status: "active" | "archived" | "hidden";
  mode: "agent" | "plan" | "ask";
  created_at: string;
  updated_at: string;
}
```

**claude-workbench `AIConversation`:**
```typescript
interface AIConversation {
  id: string;
  name: string;  // auto-generated after first exchange
  createdAt: string;
  updatedAt: string;
}
```

### Storage

- **Misaka:** SQLite at `~/.cc-switch/cc-switch.db`, messages stored as JSON content column, cursor-based pagination via `_rowid`
- **claude-workbench:** JSON files in `~/.claude/ai-assistant-conversations/`, index file at `conversations/index.json`, default conversation ID `__default__`

### Session List UI (gemiui Sidebar pattern)

```tsx
// gemiui Sidebar — simple in-memory session list
interface ChatSession {
  id: string;
  title: string;
  timestamp: Date;
  messageCount: number;
}
// Each session item: truncated title, message count, relative time, hover delete button
```

**claude-workbench auto-naming:** After the first complete stream, calls `generateConversationName(conversationId, model)` API. Uses `hasAutoNamed` ref set to prevent duplicate calls. Falls back gracefully — removes ID from set on failure to allow retry.

### Session Switching

- Always create new conversation on project switch to avoid stale context
- Load history lazily: `getConversation(id)` on mount / ID change
- On load, show empty state first then hydrate — prevents flash of stale content

---

## 3. Streaming Response Implementation

### Architecture Options

#### Option A: Python asyncio + Flet (Misaka)

Misaka uses the `claude-agent-sdk` Python package with a `ClaudeSDKClient` for stateful multi-turn sessions. The `StreamHandler` class encapsulates the entire streaming turn lifecycle:

1. Build per-invocation `_StreamContext` (session_id, generation counter, foreground flag, cancelled flag, accumulated blocks)
2. Wire callbacks: `on_text`, `on_tool_use`, `on_tool_result`, `on_permission_request`
3. Async iteration over SDK events — each event mutates `state.streaming_blocks` and calls `ui_refresh()`
4. Incremental UI update: if only the last text block changed, update `markdown.value` in-place (avoid full rebuild)
5. On completion: serialize blocks → `Message`, persist to DB, update session metadata

**Key optimization — incremental update strategy:**
```python
def _incremental_update(self) -> None:
    blocks = self.state.streaming_blocks
    current_count = len(blocks)

    # Most common case: text chunk appended to last text block
    if (current_count == self._rendered_block_count
            and current_count > 0
            and self._last_text_md is not None
            and hasattr(blocks[-1], "text")):
        self._last_text_md.value = blocks[-1].text
        self._last_text_md.update()  # single widget update, not full page
        return

    # New blocks: append only new controls to column
    if current_count > self._rendered_block_count:
        for i in range(self._rendered_block_count, current_count):
            ...append to _content_column.controls...
        self._rendered_block_count = current_count
        return

    # Fallback: full rebuild
    self._build_ui()
```

#### Option B: SSE + requestAnimationFrame (claude-workbench)

The most sophisticated web-based implementation. Uses Server-Sent Events over HTTP streaming with frame-rate throttling:

```typescript
// Throttle UI updates to animation frames
let rafScheduled = false;
let pendingToolUpdate = false;

function scheduleUIUpdate(): void {
  if (rafScheduled) return;
  rafScheduled = true;
  requestAnimationFrame(() => {
    rafScheduled = false;
    const update: Partial<AIChatMessage> = { content: assistantContent };
    if (pendingToolUpdate) {
      update.toolCalls = [...toolCalls];
      pendingToolUpdate = false;
    }
    setMessages((prev) =>
      prev.map((m) => m.id === assistantId ? { ...m, ...update } : m)
    );
  });
}
```

SSE event types:
- `text_delta` — append text chunk to `assistantContent`
- `tool_call` — push new `AIToolCall` to `toolCalls[]`
- `command_confirm` — pause stream, show confirmation UI
- `error` — surface error message
- `done` — finalize

AbortController for cancellation; on abort, keep whatever content was already streamed.

#### Option C: AsyncGenerator (gemiui)

Simplest implementation using `@google/generative-ai` SDK's built-in streaming:

```typescript
async function* sendMessage(message: string): AsyncGenerator<StreamingResponse> {
  const chat = model.startChat({ history: chatHistory });
  const result = await chat.sendMessageStream(message);
  let fullResponse = '';
  for await (const chunk of result.stream) {
    const text = chunk.text();
    if (text) {
      fullResponse += text;
      yield { type: 'content', content: text };
    }
  }
  // Persist to history after full response
  chatHistory.push(
    { role: 'user', parts: [{ text: message }] },
    { role: 'model', parts: [{ text: fullResponse }] }
  );
  yield { type: 'done' };
}
```

Consumed in the component via `for await (const response of generator)`, accumulating into `currentStreamingMessage` state.

### Recommendation for Haipee

Since Haipee uses Tauri (Rust backend), the recommended approach combines elements of Option B and C:

1. Rust backend spawns Claude CLI subprocess, reads stdout line-by-line
2. Each JSON event line is forwarded to frontend via Tauri event system: `window.emit("claude_stream_event", payload)`
3. Frontend listens with `listen("claude_stream_event", handler)` from `@tauri-apps/api/event`
4. Use `requestAnimationFrame` throttling (Option B pattern) for UI updates
5. Maintain `abortRef` with a Tauri command to send SIGTERM to subprocess

---

## 4. Code Block Rendering Component

### Misaka CodeBlock (Python/Flet)

Key design decisions:
- Header row: language badge (10px semibold, 40% opacity) + copy icon button
- Body: monospace font, 12px, selectable text, no horizontal scroll (wraps)
- Container: `SURFACE_CONTAINER_HIGH` background, 10px border-radius, 1px border at 6% opacity, subtle box shadow
- Copy feedback: swap icon to checkmark for 1.5s then restore

```python
# Language badge + copy button header
# Monospace code content (no syntax highlighting — clean but limited)
# Container: bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH, border_radius=10
```

Note: Misaka does NOT use syntax highlighting — it relies on monospace font only. This is simpler but visually inferior.

### claude-workbench CodeBlock (React)

Uses `react-syntax-highlighter` with Prism engine and `oneDark` theme:

```tsx
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism';

// In ReactMarkdown components prop:
code({ node, inline, className, children, ...props }) {
  const match = /language-(\w+)/.exec(className || '');
  return !inline && match ? (
    <SyntaxHighlighter style={oneDark} language={match[1]} PreTag="div" {...props}>
      {String(children).replace(/\n$/, '')}
    </SyntaxHighlighter>
  ) : (
    <code className={className} {...props}>{children}</code>
  );
}
```

### Recommendation for Haipee

Use `react-syntax-highlighter` with Prism + `oneDark` theme (same as claude-workbench). Wrap in a custom `CodeBlock` component that adds:
- Language badge in header
- Copy button with 1.5s checkmark feedback (same pattern as Misaka)
- Container with `bg-surface` background, rounded corners, subtle border

---

## 5. File Attachment Handling

### claude-workbench Attachments

Types:
```typescript
interface AIAttachment {
  name: string;
  mediaType: string;  // MIME type
  data: string;       // base64
}
```

UI: paperclip icon button opens file picker, attachments displayed as chips with remove button above the input field. Files are base64-encoded before sending to API.

Backend strips to `{ name, mediaType, data }` and passes to Anthropic SDK as `image` or `document` content blocks.

### Misaka Image Handling

`ImageBlock` component renders images either from file path or base64. Clicking opens a full-screen `ImageOverlay`. Images displayed in the chat at natural size with click-to-expand.

For file attachments (non-image), Misaka uses an `image_preview_bar` component that shows a horizontal strip of attachment chips above the input box. Files are read and embedded as base64 before sending.

### Recommendation for Haipee

```typescript
interface ChatAttachment {
  id: string;
  name: string;
  type: "image" | "document" | "text";
  mediaType: string;
  size: number;
  data: string;  // base64
  preview?: string;  // thumbnail URL for images
}
```

Display: horizontal chip strip above the text input, each chip shows file name + size, with an `×` button. On send, convert to appropriate Anthropic SDK content blocks.

---

## 6. UI Layout Recommendations

### Three-Panel Layout (claude-forge pattern)

```
┌─────────────────────────────────────────────────────┐
│  TabBar (project tabs)                               │
├──────────┬──────────────────────────┬───────────────┤
│          │                          │               │
│ Sidebar  │   Main Content           │  Tasks Panel  │
│          │   (chat or editor)       │               │
│  - File  │                          │  (streaming   │
│    tree  │                          │   output)     │
│  - MCP   │                          │               │
│  - etc   │                          │               │
└──────────┴──────────────────────────┴───────────────┘
```

claude-forge uses CSS classes `app-container`, `app-workspace` (flex row), `Sidebar` (fixed width), `MainContent` (flex-1), `TasksPanel` (right drawer).

### Drawer Pattern (claude-workbench pattern)

claude-workbench uses a floating AI Assistant drawer that overlays the right side of the screen. The Floating Action Button (FAB) uses `bottom-6 right-6 fixed` positioning and detects when other panels overlap its area using `getBoundingClientRect()` — automatically repositioning to avoid conflicts.

Key: `isFullscreen` toggle to expand drawer to full width.

### Message List Layout

Both Misaka and gemiui use a `ScrollArea`/overflow-y-auto container with:
- `padding: 16px` on sides
- `space-y-4` (16px gap) between messages
- Auto-scroll: monitor `messages.length`, use `scrollTop = scrollHeight` on each new message
- For streaming: `requestAnimationFrame(() => messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' }))` — only smooth scroll when message count increases (not on token deltas)

### Input Area

claude-workbench input area features:
- Slash command popup menu (`/` prefix triggers tool selection from `tools[]`)
- `/model` command to switch model inline
- Multi-line `textarea` with auto-resize
- Keyboard: `Enter` sends, `Shift+Enter` newlines, `Escape` dismisses menus, arrow keys navigate slash menu
- Model selector dropdown showing profile-derived models
- File attachment button + chip display

Misaka input area:
- Fixed-height text field with send button
- Separate image preview bar above input
- Keyboard shortcut: `Enter` sends, `Shift+Enter` newlines

---

## 7. State Management Approach

### Misaka (Python/Flet — centralized reactive state)

Single `AppState` class with a `page` reference. All UI components hold a reference to `AppState` and read its attributes. Services mutate state and call `state.update()` which calls `page.update()` to trigger a full page refresh.

Key state fields:
- `sessions: list[ChatSession]` — all sessions for sidebar
- `current_session: ChatSession | None` — selected session
- `messages: list[Message]` — messages for current session
- `is_streaming: bool` — streaming in progress
- `streaming_blocks: list[StreamingBlock]` — in-progress blocks
- `permission_request: PermissionRequest | None` — pending permission dialog
- `background_streams: dict[str, BackgroundStreamInfo]` — sessions streaming in background

Background streaming design: when user switches sessions during an active stream, the session's stream is demoted to background. A `BackgroundStreamStatus.STREAMING` badge shows in the session list. When stream completes, status becomes `COMPLETED_UNREAD`.

### claude-forge (Zustand — multiple domain stores)

Separate Zustand stores per domain:
- `projectStore` — open projects, active project, `getActiveProject()`
- `agentStore` — agent definitions
- `taskStore` — running tasks with streaming output, `initializeListeners()`
- `commitStore` — git commit history
- `settingsStore` — app settings

`taskStore.initializeListeners()` wires Electron IPC events (`TASK_STREAM`, `TASK_COMPLETE`, `TASK_ERROR`) and returns a cleanup function. The App component calls this in `useEffect` and returns the cleanup.

### claude-workbench (React hooks — composition pattern)

Custom `useAIChat(conversationId, options)` hook encapsulates all chat state:

```typescript
// Returns:
{
  messages: AIChatMessage[];
  isLoading: boolean;
  error: string | null;
  pendingConfirmation: CommandConfirmation | null;
  sendMessage: (message: string, model: string, forceTool?: string, attachments?: AIAttachment[]) => Promise<void>;
  stopGeneration: () => void;
  clearHistory: () => Promise<void>;
  loadHistory: () => Promise<void>;
  confirmCommand: () => void;
  rejectCommand: () => void;
}
```

The `abortControllerRef` pattern for cancellation: always create a new AbortController before each request, store in ref, abort previous if one exists.

### gemiui (Service + hook — two-layer pattern)

`GeminiService` class holds SDK instance, chat history array, and initialization state. `useGemini()` hook wraps the service in a `useRef` (stable across renders) + `useState` (triggers re-renders when status changes). This prevents re-initialization on every render while still providing reactive state.

### Recommendation for Haipee

Given Haipee already uses Tauri IPC with React:

```typescript
// Recommended structure using Zustand
interface ChatStore {
  // Session management
  sessions: ChatSession[];
  activeSessionId: string | null;

  // Message state
  messages: Record<string, Message[]>;  // keyed by sessionId

  // Streaming state
  isStreaming: boolean;
  streamingBlocks: StreamingBlock[];
  streamingSessionId: string | null;

  // Actions
  createSession: (workingDir: string) => Promise<ChatSession>;
  loadMessages: (sessionId: string) => Promise<void>;
  sendMessage: (sessionId: string, content: string, attachments?: ChatAttachment[]) => Promise<void>;
  stopStreaming: () => void;
}
```

For streaming, use Tauri's `listen()` from `@tauri-apps/api/event` to receive events from Rust:
- `claude:stream:text` — text delta
- `claude:stream:tool_use` — tool invocation started
- `claude:stream:tool_result` — tool result received
- `claude:stream:done` — stream completed
- `claude:stream:error` — error occurred

---

## Summary: Best Patterns Per Category

| Category | Best Source | Key Insight |
|----------|-------------|-------------|
| Message data model | Misaka | Store as JSON `MessageContentBlock[]`, parse on render |
| Tool call rendering | Misaka | Pair tool_use+tool_result before rendering, collapsible detail |
| Streaming optimization | Misaka | In-place Markdown update for text delta, append-only for new blocks |
| SSE + UI throttling | claude-workbench | `requestAnimationFrame` batching, AbortController cancellation |
| Code highlighting | claude-workbench | `react-syntax-highlighter` + Prism + oneDark theme |
| Session management | claude-workbench | Auto-naming via API after first stream completes |
| File attachments | claude-workbench | Chip strip above input, base64 encode, pass as Anthropic content blocks |
| State management | claude-forge | Zustand domain stores, IPC event listeners in `useEffect` with cleanup |
| Hook composition | claude-workbench | `useAIChat(conversationId, options)` — conversation-scoped hook |
| Layout structure | claude-forge | Tab bar + sidebar + main content + right drawer |
| Slash commands | claude-workbench | `/` prefix popup with keyboard navigation, `/model` for model switch |
| Background streaming | Misaka | `BackgroundStreamInfo` — demote to background on session switch |
| Permission handling | Misaka | `PermissionRequest` dataclass, pause stream, wait for user decision |
| JSON display in chat | Misaka | Detect raw JSON, show collapsible summary row instead of raw dump |
| File tree | Misaka | Extension→icon+color map, depth-based indent, context menu on right-click |
