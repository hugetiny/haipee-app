# Menu Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the top-level "Agent配置" menu and merge its functionality into Settings > Agent设置 tab.

**Architecture:** Replace ModelsPanel in Settings with the existing AgentConfigView component, which already has agent selector + sub-tabs. Remove agentConfig view from App.tsx and MainLayout.tsx navigation.

**Tech Stack:** React, TypeScript, Tauri, i18next

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `src/App.tsx` | Modify | Remove agentConfig view handling |
| `src/components/layout/MainLayout.tsx` | Modify | Remove agentConfig from navigation menu |
| `src/components/settings/SettingsPage.tsx` | Modify | Replace ModelsPanel with AgentConfigView, rename tab |
| `src/i18n/locales/zh.json` | Modify | Update tab translation |
| `src/i18n/locales/en.json` | Modify | Update tab translation |
| `src/components/settings/ModelsPanel.tsx` | Keep | Still used elsewhere, do not delete |

---

### Task 1: Update MainLayout Navigation

**Files:**
- Modify: `src/components/layout/MainLayout.tsx`

- [ ] **Step 1: Remove agentConfig from MainView type and MAIN_MENU_ITEMS**

Find and remove `agentConfig` from:
1. `MainView` type (line ~32)
2. `MAIN_MENU_ITEMS` array (lines 57-70)

Current MAIN_MENU_ITEMS:
```typescript
const MAIN_MENU_ITEMS = [
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "会话管理",
  },
  {
    id: "agentConfig",
    icon: Settings2,
    labelKey: "agent.config.title",
    labelFallback: "Agent配置",
  },
] as const;
```

Change to:
```typescript
const MAIN_MENU_ITEMS = [
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "会话管理",
  },
] as const;
```

Also update `activeMainMenu` logic (around line 575):
```typescript
const activeMainMenu = useMemo(() => {
  if (currentView === "sessions") return "sessions";
  if (currentView === "agentConfig") return "agentConfig";  // Remove this line
  if (currentView === "settings") return "settings";
  return "sessions";
}, [currentView]);
```

Change to:
```typescript
const activeMainMenu = useMemo(() => {
  if (currentView === "sessions") return "sessions";
  if (currentView === "settings") return "settings";
  return "sessions";
}, [currentView]);
```

- [ ] **Step 2: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors related to MainLayout

- [ ] **Step 3: Commit**

```bash
git add src/components/layout/MainLayout.tsx
git commit -m "refactor: remove agentConfig from MainLayout navigation"
```

---

### Task 2: Update App.tsx

**Files:**
- Modify: `src/App.tsx`

- [ ] **Step 1: Remove agentConfig from View type and VALID_VIEWS**

Find `View` type (around line 50-58) and remove `agentConfig`:
```typescript
type View =
  | "providers"
  | "settings"
  | "prompts"
  | "skills"
  | "skillsDiscovery"
  | "mcp"
  | "agents"
  | "universal"
  | "sessions"
  | "agentConfig";  // Remove this line
```

Find `VALID_VIEWS` array (around line 71-82) and remove `agentConfig`:
```typescript
const VALID_VIEWS: View[] = [
  "providers",
  "settings",
  "prompts",
  "skills",
  "skillsDiscovery",
  "mcp",
  "agents",
  "universal",
  "sessions",
  "agentConfig",  // Remove this line
];
```

- [ ] **Step 2: Remove agentConfig case from renderContent**

Find the switch case for `agentConfig` (around line 627):
```typescript
case "agentConfig":
  return <AgentConfigView />;
```

Remove this entire case block.

- [ ] **Step 3: Remove AgentConfigView import if no longer used**

Check if `AgentConfigView` is still used. If only used in Settings, the import can remain for now since SettingsPage will use it.

- [ ] **Step 4: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add src/App.tsx
git commit -m "refactor: remove agentConfig view from App"
```

---

### Task 3: Update SettingsPage to use AgentConfigView

**Files:**
- Modify: `src/components/settings/SettingsPage.tsx`

- [ ] **Step 1: Import AgentConfigView**

Add import at top:
```typescript
import { AgentConfigView } from "@/components/agents/AgentConfigView";
```

- [ ] **Step 2: Replace ModelsPanel with AgentConfigView in TabsContent**

Find the `TabsContent value="models"` section (around line 221-245):
```typescript
<TabsContent value="models" className="mt-0">
  <motion.div
    initial={{ opacity: 0, y: 10 }}
    animate={{ opacity: 1, y: 0 }}
    transition={{ duration: 0.3 }}
  >
    <div className="flex items-center gap-3 px-1 mb-4">
      <Cpu className="h-5 w-5 text-primary" />
      <div>
        <h2 className="text-base font-semibold">
          {t("settings.models.heading", {
            defaultValue: "模型管理",
          })}
        </h2>
        <p className="text-sm text-muted-foreground">
          {t("settings.models.headingDescription", {
            defaultValue:
              "统一管理所有 Agent 的模型配置，按 Agent 切换查看和编辑。",
          })}
        </p>
      </div>
    </div>
    <ModelsPanel />
  </motion.div>
</TabsContent>
```

Replace with:
```typescript
<TabsContent value="models" className="mt-0 h-full">
  <AgentConfigView />
</TabsContent>
```

- [ ] **Step 3: Update TabsList label**

Find the `TabsTrigger value="models"` (around line 199-201):
```typescript
<TabsTrigger value="models">
  {t("settings.tabModels", { defaultValue: "模型" })}
</TabsTrigger>
```

Change to:
```typescript
<TabsTrigger value="models">
  {t("settings.tabAgentSettings", { defaultValue: "Agent设置" })}
</TabsTrigger>
```

- [ ] **Step 4: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add src/components/settings/SettingsPage.tsx
git commit -m "refactor: replace ModelsPanel with AgentConfigView in Settings"
```

---

### Task 4: Update i18n Translations

**Files:**
- Modify: `src/i18n/locales/zh.json`
- Modify: `src/i18n/locales/en.json`

- [ ] **Step 1: Add new translation key in zh.json**

Find `settings.tabModels` and add/update:
```json
"tabModels": "模型",
"tabAgentSettings": "Agent设置",
```

- [ ] **Step 2: Add new translation key in en.json**

Find `settings.tabModels` and add/update:
```json
"tabModels": "Models",
"tabAgentSettings": "Agent Settings",
```

- [ ] **Step 3: Commit**

```bash
git add src/i18n/locales/zh.json src/i18n/locales/en.json
git commit -m "feat: add AgentSettings translation key"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 2: Run unit tests**

Run: `bun run test:unit`
Expected: All tests pass

- [ ] **Step 3: Manual testing checklist**

1. Open Settings dialog
2. Verify "Agent设置" tab exists and shows AgentConfigView
3. Verify agent selector works (can switch between Claude, Codex, etc.)
4. Verify all sub-tabs work (基础配置, Skills, MCP, 提示词, 环境变量, 高级设置)
5. Verify bottom navigation no longer shows "Agent配置"
6. Verify desktop sidebar no longer shows "Agent配置" button

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: final adjustments for menu simplification"
```

---

## Summary of Changes

1. **Navigation simplified**: Removed "Agent配置" from both mobile bottom nav and desktop sidebar
2. **Settings expanded**: "模型" tab renamed to "Agent设置" and now contains full AgentConfigView with all sub-tabs
3. **No functionality lost**: All features (基础配置, Skills, MCP, 提示词, 环境变量, 高级设置) remain accessible within Settings
4. **Code reuse**: AgentConfigView component is reused, no duplication needed