# Navigation Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify navigation by making 5 agents primary sidebar items with auto-read config status indicators.

**Architecture:** Add backend `get_all_config_statuses` command. Create `useNavigationState` hook used internally by MainLayout. Restructure MainLayout sidebar to show agent list with status indicators. Remove AppSwitcherButton from bottom nav.

**Tech Stack:** React 18, TypeScript, Tauri v2, Rust, Tailwind CSS, shadcn/ui

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `src-tauri/src/commands/config.rs` | Modify | Add `get_all_config_statuses` command |
| `src-tauri/src/lib.rs` | Modify | Register new command |
| `src-tauri/capabilities/default.json` | Modify | Add permission for new command |
| `src/lib/api/config.ts` | Create | Add `getAllConfigStatuses()` API function |
| `src/lib/browser-mock.ts` | Modify | Add mock for new command |
| `src/hooks/useNavigationState.ts` | Create | Navigation state hook (selectedAgent, selectedMode, statusMap) |
| `src/components/layout/MainLayout.tsx` | Modify | Restructure sidebar with agent list, use hook internally |
| `src/App.tsx` | Modify | Simplify, remove activeApp state |
| `src/i18n/locales/zh.json` | Modify | Add navigation i18n keys |
| `src/i18n/locales/en.json` | Modify | Add navigation i18n keys |

---

### Task 1: Backend - Add `get_all_config_statuses` Command

**Files:**
- Modify: `src-tauri/src/commands/config.rs`
- Modify: `src-tauri/src/lib.rs`
- Modify: `src-tauri/capabilities/default.json`

- [ ] **Step 1: Add new command to config.rs**

Add after the existing `get_config_status` function (around line 105):

```rust
/// Get config status for all supported apps in a single call
#[tauri::command]
pub async fn get_all_config_statuses() -> Result<std::collections::HashMap<String, ConfigStatus>, String> {
    let mut results = std::collections::HashMap::new();

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

- [ ] **Step 2: Register command in lib.rs**

Find the `invoke_handler` section with `tauri::generate_handler!` and add `get_all_config_statuses` to the list:

```rust
// Find existing line like:
commands::get_config_status,
// Add after it:
commands::get_all_config_statuses,
```

- [ ] **Step 3: Add capability permission**

Check the existing format in `src-tauri/capabilities/default.json`. Look for similar command permissions and add in the same format. For Tauri v2, commands typically use the format `"command-name"`. Add:

```json
"get-all-config-statuses"
```

to the `permissions` array.

- [ ] **Step 4: Build and verify**

Run: `cargo check --manifest-path src-tauri/Cargo.toml`
Expected: No errors

- [ ] **Step 5: Commit backend changes**

```bash
git add src-tauri/src/commands/config.rs src-tauri/src/lib.rs src-tauri/capabilities/default.json
git commit -m "feat: add get_all_config_statuses command for navigation status"
```

---

### Task 2: Frontend - Add API Function

**Files:**
- Create: `src/lib/api/config.ts`

- [ ] **Step 1: Create config API file**

```typescript
// src/lib/api/config.ts
import { invoke } from "@tauri-apps/api/core";

export interface ConfigStatus {
  exists: boolean;
  path: string;
}

export interface AllConfigStatuses {
  [agentId: string]: ConfigStatus;
}

/**
 * Get config status for all supported apps in a single call
 */
export async function getAllConfigStatuses(): Promise<AllConfigStatuses> {
  return invoke<AllConfigStatuses>("get_all_config_statuses");
}
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/api/config.ts
git commit -m "feat: add getAllConfigStatuses API function"
```

---

### Task 3: Frontend - Add Browser Mock

**Files:**
- Modify: `src/lib/browser-mock.ts`

- [ ] **Step 1: Add mock for new command**

Find the mock invoke handler object in `browser-mock.ts` and add a new entry:

```typescript
get_all_config_statuses: async () => ({
  claude: { exists: true, path: '/mock/claude' },
  codex: { exists: true, path: '/mock/codex' },
  gemini: { exists: false, path: '未登录' },
  opencode: { exists: true, path: '/mock/opencode' },
  openclaw: { exists: false, path: '/mock/openclaw' },
}),
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/browser-mock.ts
git commit -m "feat: add browser mock for get_all_config_statuses"
```

---

### Task 4: Frontend - Create useNavigationState Hook

**Files:**
- Create: `src/hooks/useNavigationState.ts`

- [ ] **Step 1: Create the navigation hook**

```typescript
// src/hooks/useNavigationState.ts
import { useState, useEffect, useCallback } from "react";
import { getAllConfigStatuses, type ConfigStatus } from "@/lib/api/config";
import type { AppId } from "@/lib/api";

const ALL_APPS: AppId[] = ["claude", "codex", "gemini", "opencode", "openclaw"];
const STORAGE_KEY = "haipee-selected-agent";

export type NavigationMode = "sessions" | "config" | "settings";

export type AgentStatus =
  | { type: "loading" }
  | { type: "success"; exists: boolean }
  | { type: "error"; message: string };

export interface AgentStatusMap {
  [agentId: string]: AgentStatus;
}

interface UseNavigationStateReturn {
  selectedAgent: AppId;
  selectedMode: NavigationMode;
  statusMap: AgentStatusMap;
  isLoading: boolean;
  selectAgent: (agent: AppId) => void;
  setMode: (mode: NavigationMode) => void;
  refreshStatuses: () => Promise<void>;
}

export function useNavigationState(): UseNavigationStateReturn {
  // Initialize selectedAgent from localStorage, default to "claude"
  const [selectedAgent, setSelectedAgent] = useState<AppId>(() => {
    if (typeof window !== "undefined") {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored && ALL_APPS.includes(stored as AppId)) {
        return stored as AppId;
      }
    }
    return "claude";
  });

  // selectedMode always starts as "sessions" (no persistence per spec)
  const [selectedMode, setSelectedMode] = useState<NavigationMode>("sessions");

  const [statusMap, setStatusMap] = useState<AgentStatusMap>({});
  const [isLoading, setIsLoading] = useState(false);

  // Fetch all config statuses
  const refreshStatuses = useCallback(async () => {
    setIsLoading(true);
    // Set all to loading
    setStatusMap(
      Object.fromEntries(ALL_APPS.map((app) => [app, { type: "loading" as const }]))
    );

    try {
      const results = await getAllConfigStatuses();
      const newStatusMap: AgentStatusMap = {};

      for (const app of ALL_APPS) {
        const status = results[app];
        if (status) {
          newStatusMap[app] = {
            type: "success",
            exists: status.exists,
          };
        } else {
          newStatusMap[app] = {
            type: "error",
            message: "Unknown status",
          };
        }
      }

      setStatusMap(newStatusMap);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      setStatusMap(
        Object.fromEntries(ALL_APPS.map((app) => [app, { type: "error" as const, message: errorMessage }]))
      );
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Fetch on mount
  useEffect(() => {
    refreshStatuses();
  }, [refreshStatuses]);

  // Persist selectedAgent to localStorage
  const selectAgent = useCallback((agent: AppId) => {
    setSelectedAgent(agent);
    localStorage.setItem(STORAGE_KEY, agent);
  }, []);

  // Set mode (no persistence per spec)
  const setMode = useCallback((mode: NavigationMode) => {
    setSelectedMode(mode);
  }, []);

  return {
    selectedAgent,
    selectedMode,
    statusMap,
    isLoading,
    selectAgent,
    setMode,
    refreshStatuses,
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add src/hooks/useNavigationState.ts
git commit -m "feat: add useNavigationState hook for navigation management"
```

---

### Task 5: Frontend - Add i18n Keys

**Files:**
- Modify: `src/i18n/locales/zh.json`
- Modify: `src/i18n/locales/en.json`

- [ ] **Step 1: Add Chinese translations**

In `src/i18n/locales/zh.json`, find or create the appropriate section and add:

```json
"nav": {
  "sessions": "会话",
  "config": "配置",
  "settings": "设置"
},
"agent": {
  "status": {
    "loading": "读取中...",
    "error": "读取失败",
    "noConfig": "未配置",
    "hasConfig": "已配置"
  }
}
```

- [ ] **Step 2: Add English translations**

In `src/i18n/locales/en.json`, add:

```json
"nav": {
  "sessions": "Sessions",
  "config": "Config",
  "settings": "Settings"
},
"agent": {
  "status": {
    "loading": "Loading...",
    "error": "Read failed",
    "noConfig": "Not configured",
    "hasConfig": "Configured"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/i18n/locales/zh.json src/i18n/locales/en.json
git commit -m "feat: add navigation i18n keys"
```

---

### Task 6: Frontend - Update MainLayout with Agent List

**Files:**
- Modify: `src/components/layout/MainLayout.tsx`

- [ ] **Step 1: Add imports at top of file**

Add to existing imports:

```typescript
import { useMemo } from "react"; // Add if not present
import { Check, Circle, AlertTriangle, Loader2 } from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useNavigationState, type AgentStatus } from "@/hooks/useNavigationState";
```

- [ ] **Step 2: Add useNavigationState hook in MainLayout**

Inside the `MainLayout` component function, add after props destructuring:

```typescript
// Use navigation state hook internally
const {
  selectedAgent,
  selectedMode,
  statusMap,
  selectAgent,
  setMode,
} = useNavigationState();
```

- [ ] **Step 3: Add derived currentView**

Add after the hook:

```typescript
// Derive currentView from selectedMode
const derivedView = useMemo((): MainView => {
  switch (selectedMode) {
    case "settings": return "settings";
    case "config": return "agentConfig";
    default: return "sessions";
  }
}, [selectedMode]);
```

- [ ] **Step 4: Create AgentListButton component**

Add after the constants (ALL_APPS, APP_ICON_NAME, APP_DISPLAY_NAME), before the MainLayout function:

```typescript
interface AgentListButtonProps {
  displayName: string;
  iconName: string;
  isActive: boolean;
  status?: AgentStatus;
  onClick: () => void;
  compact?: boolean;
}

const AgentListButton = ({ displayName, iconName, isActive, status, onClick, compact }: AgentListButtonProps) => {
  const renderStatusIndicator = () => {
    if (!status) return null;
    switch (status.type) {
      case "loading":
        return <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />;
      case "success":
        return status.exists
          ? <Check className="h-4 w-4 text-green-500" />
          : <Circle className="h-4 w-4 text-gray-400" />;
      case "error":
        return (
          <Tooltip>
            <TooltipTrigger asChild>
              <AlertTriangle className="h-4 w-4 text-yellow-500" />
            </TooltipTrigger>
            <TooltipContent>{status.message}</TooltipContent>
          </Tooltip>
        );
    }
  };

  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "w-full flex items-center gap-2 rounded-md text-sm transition-colors",
        compact ? "px-2 py-1.5" : "px-3 py-2",
        isActive
          ? "bg-primary/10 text-primary"
          : "text-muted-foreground hover:text-foreground hover:bg-muted"
      )}
    >
      <ProviderIcon icon={iconName} name={displayName} size={compact ? 16 : 18} />
      <span className="flex-1 truncate text-left">{displayName}</span>
      <span className="shrink-0">{renderStatusIndicator()}</span>
    </button>
  );
};
```

- [ ] **Step 5: Replace DesktopSidebar ScrollArea content**

Find the `ScrollArea` in `DesktopSidebar` and replace its content with agent list:

```typescript
<ScrollArea className="flex-1">
  <nav className="flex flex-col gap-0.5 p-2 py-3">
    <div className="px-1 pb-2 space-y-0.5">
      <div className="px-2 py-1.5 text-xs font-medium text-muted-foreground/70 uppercase tracking-wider">
        Agents
      </div>
      {ALL_APPS.map((app) => (
        <AgentListButton
          key={app}
          displayName={APP_DISPLAY_NAME[app]}
          iconName={APP_ICON_NAME[app]}
          isActive={selectedAgent === app}
          status={statusMap[app]}
          onClick={() => selectAgent(app)}
        />
      ))}
    </div>
  </nav>
</ScrollArea>
```

- [ ] **Step 6: Replace DesktopSidebar bottom buttons**

Find the bottom `div` with `grid-cols-3` and replace with `grid-cols-2` (remove AppSwitcherButton):

```typescript
<div className="p-2 shrink-0">
  <div className="grid grid-cols-2 gap-1">
    {MAIN_MENU_ITEMS.map((item) => (
      <MainMenuButton
        key={item.id}
        item={item}
        isActive={
          (item.id === "sessions" && selectedMode === "sessions") ||
          (item.id === "agentConfig" && selectedMode === "config")
        }
        onClick={() => {
          if (item.id === "sessions") setMode("sessions");
          if (item.id === "agentConfig") setMode("config");
        }}
        variant="desktop"
      />
    ))}
  </div>
</div>
```

- [ ] **Step 7: Replace MobileBottomNav with 3 buttons**

Replace the entire `MobileBottomNav` function:

```typescript
const MobileBottomNav = () => {
  const { t } = useTranslation();

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-30 border-t bg-background/95 backdrop-blur-sm safe-area-bottom shrink-0">
      <div className="flex items-stretch justify-around h-[56px]">
        <button
          type="button"
          className={cn(
            "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
            selectedMode === "sessions" ? "text-primary" : "text-muted-foreground hover:text-foreground"
          )}
          onClick={() => setMode("sessions")}
        >
          <History className="w-[22px] h-[22px]" />
          <span className="text-xs leading-none truncate max-w-[56px]">{t("nav.sessions", "会话")}</span>
        </button>
        <button
          type="button"
          className={cn(
            "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
            selectedMode === "config" ? "text-primary" : "text-muted-foreground hover:text-foreground"
          )}
          onClick={() => setMode("config")}
        >
          <Settings2 className="w-[22px] h-[22px]" />
          <span className="text-xs leading-none truncate max-w-[56px]">{t("nav.config", "配置")}</span>
        </button>
        <button
          type="button"
          className={cn(
            "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
            selectedMode === "settings" ? "text-primary" : "text-muted-foreground hover:text-foreground"
          )}
          onClick={() => setMode("settings")}
        >
          <Settings className="w-[22px] h-[22px]" />
          <span className="text-xs leading-none truncate max-w-[56px]">{t("nav.settings", "设置")}</span>
        </button>
      </div>
    </nav>
  );
};
```

- [ ] **Step 8: Update MobileSidebarOverlay agent list**

Replace the ScrollArea content in `MobileSidebarOverlay` similar to DesktopSidebar:

```typescript
<ScrollArea className="flex-1">
  <nav className="flex flex-col gap-0.5 p-2 py-3">
    <div className="px-1 pb-2 space-y-0.5">
      <div className="px-2 py-1.5 text-xs font-medium text-muted-foreground/70 uppercase tracking-wider">
        Agents
      </div>
      {ALL_APPS.map((app) => (
        <AgentListButton
          key={app}
          displayName={APP_DISPLAY_NAME[app]}
          iconName={APP_ICON_NAME[app]}
          isActive={selectedAgent === app}
          status={statusMap[app]}
          onClick={() => {
            selectAgent(app);
            setIsMobileSidebarOpen(false);
          }}
          compact
        />
      ))}
    </div>
  </nav>
</ScrollArea>
```

And update the bottom buttons in MobileSidebarOverlay to remove AppSwitcherButton.

- [ ] **Step 9: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 10: Commit MainLayout changes**

```bash
git add src/components/layout/MainLayout.tsx
git commit -m "feat: restructure MainLayout sidebar with agent list"
```

---

### Task 7: Frontend - Update App.tsx

**Files:**
- Modify: `src/App.tsx`

- [ ] **Step 1: Remove activeApp state and related code**

Remove from App.tsx:
- `const [activeApp, setActiveApp] = useState<AppId>(getInitialApp);`
- `getInitialApp` function
- `STORAGE_KEY` and `VALID_APPS` constants for activeApp
- Effects related to `activeApp`

- [ ] **Step 2: Simplify MainLayout props**

Remove `activeApp` and `setActiveApp` props from MainLayout usage.

- [ ] **Step 3: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add src/App.tsx
git commit -m "refactor: remove activeApp state from App.tsx"
```

---

### Task 8: Delete AppSwitcher.tsx (optional)

**Files:**
- Delete: `src/components/AppSwitcher.tsx`

- [ ] **Step 1: Check if AppSwitcher is still imported**

Run: `grep -r "AppSwitcher" src/`
If only MainLayout imports it, proceed to delete.

- [ ] **Step 2: Delete the file**

```bash
rm src/components/AppSwitcher.tsx
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove unused AppSwitcher component"
```

---

### Task 9: Add Error Banner to AgentConfigView (optional enhancement)

**Files:**
- Modify: `src/components/agents/AgentConfigView.tsx`

- [ ] **Step 1: Add imports**

```typescript
import { useNavigationState } from "@/hooks/useNavigationState";
import { Button } from "@/components/ui/button";
```

- [ ] **Step 2: Use hook and show error banner for selected agent**

Inside AgentConfigView, add after existing hooks:

```typescript
const { statusMap, refreshStatuses } = useNavigationState();
const agentStatus = statusMap[activeApp];
```

- [ ] **Step 3: Add error banner in render**

Before the tabs, add:

```typescript
{agentStatus?.type === "error" && (
  <div className="mx-4 mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-md flex items-center justify-between">
    <span className="text-sm text-yellow-800">
      无法读取 {AGENT_OPTIONS.find(a => a.id === activeApp)?.label ?? activeApp} 配置: {agentStatus.message}
    </span>
    <Button variant="outline" size="sm" onClick={refreshStatuses}>
      重新读取
    </Button>
  </div>
)}
```

- [ ] **Step 4: Commit**

```bash
git add src/components/agents/AgentConfigView.tsx
git commit -m "feat: add error banner to AgentConfigView for config read failures"
```

---

### Task 10: Testing and Verification

- [ ] **Step 1: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 2: Run unit tests**

Run: `bun run test:unit`
Expected: All tests pass

- [ ] **Step 3: Run Rust tests**

Run: `cargo test --manifest-path src-tauri/Cargo.toml`
Expected: All tests pass

- [ ] **Step 4: Manual testing - Launch app**

Run: `bun run dev`

Verify:
1. App launches without errors
2. Sidebar shows 5 agents with status indicators
3. Clicking agents switches selection (checkmark moves)
4. Bottom buttons (会话, 配置) switch modes correctly
5. Narrow screen shows 3 buttons (会话, 配置, 设置)
6. Settings button switches to settings view

- [ ] **Step 5: Test config status indicators**

1. Check if agents with configs show checkmark (✓)
2. Check if agents without configs show empty circle (○)
3. Gemini should show warning (⚠) if not logged in - hover to see error

- [ ] **Step 6: Test persistence**

1. Select a different agent (e.g., Codex)
2. Close and reopen the app
3. Verify Codex is still selected

---

### Task 9: Final Commit

- [ ] **Step 1: Ensure all changes are committed**

Run: `git status`
Expected: No uncommitted changes

- [ ] **Step 2: Run final verification**

Run: `bun run typecheck && bun run test:unit`
Expected: All pass

- [ ] **Step 3: Implementation complete**

The navigation redesign is now complete with:
- Agent list in sidebar with status indicators
- Auto-read config status on app start
- Simplified bottom nav (2 buttons wide, 3 buttons narrow)
- Removed AppSwitcher from bottom nav
- Persistent agent selection across sessions