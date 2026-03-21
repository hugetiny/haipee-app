# Navigation Redesign Spec

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify navigation by making 5 agents primary sidebar items, removing AppSwitcher, and auto-reading configs on app start.

**Architecture:** Left sidebar shows 5 fixed agents (Claude, Codex, Gemini, OpenCode, OpenClaw) with status indicators. Bottom nav shows 2 buttons (会话, 配置) on wide screen, 3 buttons (会话, 配置, 设置) on narrow screen. Configs are auto-read on app start with per-agent error handling.

**Tech Stack:** React 18, TypeScript, Tauri v2, Tailwind CSS

---

## Current State Analysis

### Existing Files

| File | Purpose |
|------|---------|
| `src/components/layout/MainLayout.tsx` | Main layout with `MainView` type (providers, settings, sessions, agentConfig, prompts, skills, mcp, etc.) |
| `src/hooks/useSidebarState.ts` | **Already exists** - manages sidebar collapse state (isCollapsed, toggle, collapse, expand) |
| `src/components/settings/SettingsPage.tsx` | **Already exists** - full page settings |
| `src-tauri/src/commands/config.rs` | Has `get_config_status(app: String) -> ConfigStatus` command |
| `src/config.rs` | Has `ConfigStatus { exists: bool, path: String }` struct |

### Existing Constants (in MainLayout.tsx)

```typescript
// Already defined in MainLayout.tsx:
const ALL_APPS: AppId[] = ["claude", "codex", "gemini", "opencode", "openclaw"];
const APP_DISPLAY_NAME: Record<AppId, string> = {
  claude: "Claude", codex: "Codex", gemini: "Gemini",
  opencode: "OpenCode", openclaw: "OpenClaw",
};
const APP_ICON_NAME: Record<AppId, string> = { ... };

const MAIN_MENU_ITEMS = [
  { id: "sessions", icon: History, labelKey: "sessionManager.title", labelFallback: "会话管理" },
  { id: "agentConfig", icon: Settings2, labelKey: "agent.config.title", labelFallback: "Agent配置" },
] as const;
```

### Existing Backend Command

```rust
// src-tauri/src/commands/config.rs (already exists)
#[tauri::command]
pub async fn get_config_status(app: String) -> Result<ConfigStatus, String>

// Returns ConfigStatus { exists: bool, path: String }
// exists = whether the app's config file exists (e.g., ~/.claude/settings.json for claude)
```

---

## Layout Structure

### Wide Screen (≥768px)

```
┌──────────────────────────────────────────────────────────────┐
│  ┌─────────────┐  ┌────────────────────────────────────────┐ │
│  │ Haipee      │  │                                        │ │
│  │ ─────────── │  │         Main Content Area              │ │
│  │ Claude   ✓  │  │   (Session List OR Config Panel        │ │
│  │ Codex     ✓ │  │    based on bottom button selection)   │ │
│  │ Gemini    ⚠ │  │                                        │ │
│  │ OpenCode  ✓ │  │                                        │ │
│  │ OpenClaw  ○ │  │                                        │ │
│  │             │  │                                        │ │
│  │ ─────────── │  │                                        │ │
│  │ [会话] [配置]│  │                                        │ │
│  └─────────────┘  └────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Narrow Screen (<768px)

```
┌────────────────────────────────────┐
│  ┌──────────┐  ┌─────────────────┐ │
│  │ Claude ✓ │  │   Main Content  │ │
│  │ Codex  ✓ │  │                 │ │
│  │ Gemini ⚠ │  │                 │ │
│  │ OpenCode │  │                 │ │
│  │ OpenClaw │  │                 │ │
│  └──────────┘  └─────────────────┘ │
│  ┌────────────────────────────────┐│
│  │ 会话  │ 配置  │ 设置          ││
│  └────────────────────────────────┘│
└────────────────────────────────────┘
```

---

## Files to Modify/Create

| File | Action | Purpose |
|------|--------|---------|
| `src/hooks/useNavigationState.ts` | **Create** | Navigation state (selectedAgent, selectedMode, statusMap) - **NOT useSidebarState.ts** which already exists |
| `src/components/layout/MainLayout.tsx` | Modify | Restructure sidebar with AgentList, remove AppSwitcherButton |
| `src/App.tsx` | Modify | Remove AppSwitcher logic, use new navigation hook |
| `src-tauri/src/commands/config.rs` | Modify | Add `get_all_config_statuses` command (uses existing `get_config_status`) |
| `src-tauri/src/lib.rs` | Modify | Register new command |
| `src-tauri/capabilities/default.json` | Modify | Add `get-all-config-statuses` permission |
| `src/lib/browser-mock.ts` | Modify | Add mock for new command |
| `src/components/AppSwitcher.tsx` | Delete (or keep for AgentConfigView) | Remove from MainLayout |

---

## State Model

```typescript
// src/hooks/useNavigationState.ts

interface NavigationState {
  selectedAgent: AppId;  // Reuse existing AppId type
  selectedMode: 'sessions' | 'config' | 'settings';  // settings only on narrow
}

type AgentStatus =
  | { type: 'loading' }
  | { type: 'success'; exists: boolean }  // exists from ConfigStatus
  | { type: 'error'; message: string };

interface AgentStatusStore {
  [agentId: string]: AgentStatus;
}

interface UseNavigationStateReturn {
  // State
  selectedAgent: AppId;
  selectedMode: 'sessions' | 'config' | 'settings';
  statusMap: AgentStatusStore;
  isLoading: boolean;

  // Actions
  selectAgent: (agent: AppId) => void;
  setMode: (mode: 'sessions' | 'config' | 'settings') => void;
  refreshStatuses: () => Promise<void>;
}

export function useNavigationState(): UseNavigationStateReturn;
```

---

## Frontend API

```typescript
// src/lib/api/config.ts (add to existing file)

export interface AllConfigStatuses {
  [agentId: string]: ConfigStatus;
}

export async function getAllConfigStatuses(): Promise<AllConfigStatuses> {
  return invoke<AllConfigStatuses>('get_all_config_statuses');
}
```

---

## Backend Command

```rust
// src-tauri/src/commands/config.rs (add new command)

use std::collections::HashMap;

#[tauri::command]
pub async fn get_all_config_statuses() -> Result<HashMap<String, ConfigStatus>, String> {
    let mut results = HashMap::new();

    for app in ["claude", "codex", "gemini", "opencode", "openclaw"] {
        let status = match get_config_status(app.to_string()).await {
            Ok(s) => s,
            Err(e) => ConfigStatus {
                exists: false,
                path: e,
            },
        };
        results.insert(app.to_string(), status);
    }

    Ok(results)
}
```

---

## Browser Mock

Add to `src/lib/browser-mock.ts`:

```typescript
// Add to mock invoke handler
get_all_config_statuses: async () => ({
  claude: { exists: true, path: '/mock/claude' },
  codex: { exists: true, path: '/mock/codex' },
  gemini: { exists: false, path: '未登录' },
  opencode: { exists: true, path: '/mock/opencode' },
  openclaw: { exists: false, path: '/mock/openclaw' },
}),
```

---

## Components

### 1. AgentList (extract from MainLayout)

Shows 5 agents with selection state and config status indicator.

```typescript
interface AgentListProps {
  selectedAgent: AppId;
  statusMap: AgentStatusStore;
  onSelect: (agentId: AppId) => void;
  compact?: boolean;  // for narrow screen
}
```

**Use existing constants:**
- `ALL_APPS` for iteration
- `APP_DISPLAY_NAME` for labels
- `APP_ICON_NAME` for icons (via `ProviderIcon` component)

**Status Indicators (Lucide icons):**
- `<Check className="h-4 w-4 text-green-500" />` - exists: true
- `<Circle className="h-4 w-4 text-gray-400" />` - exists: false (no config)
- `<AlertTriangle className="h-4 w-4 text-yellow-500" />` - error (with Tooltip)
- `<Loader2 className="h-4 w-4 animate-spin" />` - loading

### 2. BottomNav (modify existing)

Keep existing `MAIN_MENU_ITEMS` for wide screen. Add settings button for narrow screen.

### 3. MainContent Integration

**Current MainView type mapping:**
- `mode === 'sessions'` → `currentView = "sessions"` (with `sessionProviderFilter = selectedAgent`)
- `mode === 'config'` → `currentView = "agentConfig"` + use `key={selectedAgent}` for AgentConfigView
- `mode === 'settings'` → `currentView = "settings"` (narrow screen only)

---

## Config Auto-Read Flow

```
App Mount
    │
    ▼
useNavigationState initialization
    │
    ▼
getAllConfigStatuses() - calls backend
    │
    ▼
Backend calls get_config_status() for each app
    │
    ▼
Returns { claude: { exists, path }, codex: { exists, path }, ... }
    │
    ▼
Update statusMap in hook
    │
    ▼
Render sidebar with status indicators
```

---

## Responsive Breakpoints

- **Wide Screen**: `>= 768px`
  - Left sidebar: 200px width
  - Bottom: 2 buttons (会话, 配置) from `MAIN_MENU_ITEMS`
  - Settings: Click "Haipee" header → `openSettings()` (existing prop)

- **Narrow Screen**: `< 768px`
  - Left sidebar: 160px width (compact)
  - Bottom: 3 buttons (会话, 配置, 设置)
  - Settings: Third button → `setMode('settings')` → `currentView = "settings"`

---

## State Persistence

**`selectedAgent` should persist across app restarts.**

Use `localStorage` for consistency with existing patterns (`useSidebarState.ts`, `App.tsx:activeApp`):

```typescript
// In useNavigationState hook

const STORAGE_KEY = 'haipee-selected-agent';

// Load on mount
const [selectedAgent, setSelectedAgent] = useState<AppId>(() => {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && ALL_APPS.includes(stored as AppId)) {
      return stored as AppId;
    }
  }
  return 'claude';
});

// Save on change
const selectAgent = (agent: AppId) => {
  setSelectedAgent(agent);
  localStorage.setItem(STORAGE_KEY, agent);
};
```

**`selectedMode` does NOT need persistence** - always start with 'sessions'.

**Migration from `activeApp` in App.tsx:**
The existing `activeApp` state in `App.tsx` serves a similar purpose. This spec replaces it:
- Remove `activeApp` state from `App.tsx`
- Use `useNavigationState().selectedAgent` instead
- Update any components that read `activeApp` prop to read from navigation hook

---

## Migration Path

### From MainView to NavigationState

**Current:** `MainView` is a string union with many values (providers, settings, sessions, agentConfig, prompts, skills, mcp, agents, universal, openclawEnv, openclawTools, openclawAgents, etc.)

**New:** Simplify navigation:
- `selectedAgent` (AppId) - which agent is active
- `selectedMode` ('sessions' | 'config' | 'settings') - which content to show

**Transition:**
1. Keep `MainView` type for internal routing
2. `useNavigationState` determines `MainView` based on `selectedMode`:
   - 'sessions' → 'sessions' (filter by selectedAgent)
   - 'config' → 'agentConfig'
   - 'settings' → 'settings'
3. AgentConfigView internal navigation (tabs: basic, skills, mcp, prompts, env, advanced) remains unchanged

### Remove "导入当前配置" Page

The "providers" view (AppSwitcher page) is no longer needed. Configs are auto-read and status shown in sidebar.

---

## Error Handling

**In Sidebar:**
- Error indicator (⚠) next to agent name
- Hover tooltip shows `statusMap[agent].message` or `statusMap[agent].path` (error message)
- Click still works - user can go to config page to see details

**In Config Page (AgentConfigView):**
- If `statusMap[agent].type === 'error'`, show error banner
- Banner: "无法读取 {agent} 配置: {error message}"
- Action: "重新读取" button to call `refreshStatuses()`

---

## i18n Keys

Add to `src/i18n/locales/zh.json`:

```json
{
  "nav": {
    "sessions": "会话",
    "config": "配置",
    "settings": "设置"
  },
  "agent": {
    "status": {
      "error": "读取失败",
      "noConfig": "未配置",
      "hasConfig": "已配置"
    }
  }
}
```

Add to `src/i18n/locales/en.json`:

```json
{
  "nav": {
    "sessions": "Sessions",
    "config": "Config",
    "settings": "Settings"
  },
  "agent": {
    "status": {
      "error": "Read failed",
      "noConfig": "Not configured",
      "hasConfig": "Configured"
    }
  }
}
```

---

## Verification

1. **TypeScript compilation**: `bun run typecheck`
2. **Unit tests**: `bun run test:unit`
3. **Manual testing**:
   - Launch app, verify all 5 agents appear in sidebar
   - Verify status indicators show correctly (especially for failing reads like Gemini)
   - Click each agent, verify mode switches work
   - Test narrow screen layout (resize browser)
   - Verify error tooltips on hover
   - Verify error banner in config page for failed reads
   - Verify `selectedAgent` persists after app restart