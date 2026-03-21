# Agent Configuration UI Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify agent configuration UI by replacing dialogs with inline forms, removing redundant advanced tab, and adding dedicated config editor for OpenClaw.

**Architecture:** Modify AgentBasicConfig to handle inline navigation with state management. Remove AgentAdvancedConfig component entirely. Add conditional "Edit Config" button for OpenClaw.

**Tech Stack:** React, TypeScript, Tauri, i18next, Framer Motion

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `src/components/agents/AgentConfigView.tsx` | Modify | Remove advanced tab |
| `src/components/agents/AgentBasicConfig.tsx` | Modify | Add inline form navigation + OpenClaw config editor |
| `src/components/agents/AgentAdvancedConfig.tsx` | Delete | No longer needed |

---

### Task 1: Remove Advanced Tab from AgentConfigView

**Files:**
- Modify: `src/components/agents/AgentConfigView.tsx`

- [ ] **Step 1: Remove advanced tab from AGENT_TABS**

Remove the advanced entry from the array (line ~22):
```typescript
// REMOVE THIS LINE:
{ id: "advanced", labelKey: "agent.config.advanced", labelFallback: "高级设置", icon: FileJson },
```

- [ ] **Step 2: Remove AgentAdvancedConfig import and usage**

1. Remove import (line ~11):
```typescript
// REMOVE THIS LINE:
import { AgentAdvancedConfig } from "./AgentAdvancedConfig";
```

2. Remove the render case (lines ~119-121):
```typescript
// REMOVE THIS BLOCK:
{activeTab === "advanced" && (
  <AgentAdvancedConfig appId={activeApp} />
)}
```

- [ ] **Step 3: Remove FileJson import if no longer used**

Check if `FileJson` is still used elsewhere. If not, remove from imports (line ~4):
```typescript
// If unused, remove FileJson from:
import { Settings2, Code2, Plug, FileText, Terminal, FileJson } from "lucide-react";
```

- [ ] **Step 4: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors related to AgentConfigView

- [ ] **Step 5: Commit**

```bash
git add src/components/agents/AgentConfigView.tsx
git commit -m "refactor: remove advanced tab from AgentConfigView"
```

---

### Task 2: Add Inline Form Navigation to AgentBasicConfig

**Files:**
- Modify: `src/components/agents/AgentBasicConfig.tsx`

- [ ] **Step 1: Add state for inline editing**

Add new state variables after existing useState hooks (after line ~32):
```typescript
const [editingProviderId, setEditingProviderId] = useState<string | null>(null);
const [showConfigEditor, setShowConfigEditor] = useState(false);
```

- [ ] **Step 2: Modify ProviderList click handlers**

Change `onEdit` handler to set editingProviderId instead of opening dialog:
```typescript
// Change from:
onEdit={setEditingProvider}
// To:
onEdit={(provider) => setEditingProviderId(provider.id)}
```

- [ ] **Step 3: Add function to get editing provider**

Add after the state declarations:
```typescript
const editingProvider = editingProviderId
  ? providers[editingProviderId] ?? null
  : null;
```

- [ ] **Step 4: Add Back button and form rendering logic**

Replace the entire return statement with conditional rendering:

```typescript
// OpenClaw config editor mode
if (showConfigEditor && appId === "openclaw") {
  return (
    <OpenClawConfigEditor
      onBack={() => setShowConfigEditor(false)}
    />
  );
}

// Provider edit mode
if (editingProvider) {
  return (
    <ProviderEditView
      provider={editingProvider}
      appId={appId}
      isProxyTakeover={isProxyRunning && isCurrentAppTakeoverActive}
      onBack={() => setEditingProviderId(null)}
      onSave={handleEditProvider}
    />
  );
}

// Default: Provider list view
return (
  <div className="space-y-4">
    {/* Header with Add button */}
    <div className="flex items-center justify-between">
      <div>
        <h3 className="text-sm font-semibold">
          {t("agent.config.models", { defaultValue: "模型配置" })}
        </h3>
        <p className="text-xs text-muted-foreground">
          {t("agent.config.modelsDescription", {
            defaultValue: "管理此 Agent 的模型，切换当前使用的模型",
          })}
        </p>
      </div>
      <div className="flex gap-2">
        {appId === "openclaw" && (
          <Button
            onClick={() => setShowConfigEditor(true)}
            size="sm"
            variant="outline"
            className="gap-1"
          >
            <FileJson className="w-3.5 h-3.5" />
            {t("agent.config.editConfig", { defaultValue: "编辑配置" })}
          </Button>
        )}
        <Button
          onClick={() => setIsAddOpen(true)}
          size="sm"
          variant="outline"
          className="gap-1"
        >
          <Plus className="w-3.5 h-3.5" />
          {t("common.add", { defaultValue: "添加" })}
        </Button>
      </div>
    </div>

    {/* Provider List */}
    {isLoading ? (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    ) : (
      <ProviderList
        providers={providers}
        currentProviderId={currentProviderId}
        appId={appId}
        isLoading={isLoading}
        isProxyRunning={isProxyRunning}
        isProxyTakeover={isProxyRunning && isCurrentAppTakeoverActive}
        activeProviderId={activeProviderId}
        onSwitch={switchProvider}
        onEdit={(provider) => setEditingProviderId(provider.id)}
        onDelete={(provider) =>
          setConfirmAction({ provider, action: "delete" })
        }
        onRemoveFromConfig={
          appId === "opencode" || appId === "openclaw"
            ? (provider) =>
                setConfirmAction({ provider, action: "remove" })
            : undefined
        }
        onDuplicate={handleDuplicateProvider}
        onOpenWebsite={handleOpenWebsite}
        onCreate={() => setIsAddOpen(true)}
        onSetAsDefault={
          appId === "openclaw" ? setAsDefaultModel : undefined
        }
      />
    )}

    {/* Add Provider Dialog */}
    <AddProviderDialog
      open={isAddOpen}
      onOpenChange={setIsAddOpen}
      appId={appId}
      onSubmit={addProvider}
    />

    {/* Confirm Dialog */}
    <ConfirmDialog
      isOpen={Boolean(confirmAction)}
      title={
        confirmAction?.action === "remove"
          ? t("confirm.removeProvider")
          : t("confirm.deleteProvider")
      }
      message={
        confirmAction
          ? confirmAction.action === "remove"
            ? t("confirm.removeProviderMessage", {
                name: confirmAction.provider.name,
              })
            : t("confirm.deleteProviderMessage", {
                name: confirmAction.provider.name,
              })
          : ""
      }
      onConfirm={() => void handleConfirmAction()}
      onCancel={() => setConfirmAction(null)}
    />
  </div>
);
```

- [ ] **Step 5: Add FileJson import**

Add to lucide-react import:
```typescript
import { Loader2, Plus, FileJson, ArrowLeft } from "lucide-react";
```

- [ ] **Step 6: Remove EditProviderDialog usage**

Remove the EditProviderDialog component and its related state:
```typescript
// Remove this state:
const [editingProvider, setEditingProvider] = useState<Provider | null>(null);

// Remove this:
const effectiveEditingProvider = useLastValidValue(editingProvider);

// Remove the EditProviderDialog JSX block
```

- [ ] **Step 7: Run TypeScript check**

Run: `bun run typecheck`
Expected: Errors about missing ProviderEditView and OpenClawConfigEditor (will be created in next tasks)

- [ ] **Step 8: Commit**

```bash
git add src/components/agents/AgentBasicConfig.tsx
git commit -m "refactor: add inline form navigation to AgentBasicConfig"
```

---

### Task 3: Create ProviderEditView Component

**Files:**
- Create: `src/components/agents/ProviderEditView.tsx`

- [ ] **Step 1: Create ProviderEditView component**

Create new file `src/components/agents/ProviderEditView.tsx`:

```typescript
import { useState, useMemo } from "react";
import { useTranslation } from "react-i18next";
import { ArrowLeft, Save } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ProviderForm, type ProviderFormValues } from "@/components/providers/forms/ProviderForm";
import { openclawApi, providersApi, vscodeApi, type AppId } from "@/lib/api";
import type { Provider } from "@/types";

interface ProviderEditViewProps {
  provider: Provider;
  appId: AppId;
  isProxyTakeover: boolean;
  onBack: () => void;
  onSave: (provider: Provider) => Promise<void>;
}

export function ProviderEditView({
  provider,
  appId,
  isProxyTakeover,
  onBack,
  onSave,
}: ProviderEditViewProps) {
  const { t } = useTranslation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [liveSettings, setLiveSettings] = useState<Record<string, unknown> | null>(null);
  const [hasLoadedLive, setHasLoadedLive] = useState(false);

  // Load live settings on mount
  useMemo(() => {
    if (hasLoadedLive) return;

    const load = async () => {
      if (isProxyTakeover || appId === "opencode") {
        setLiveSettings(null);
        setHasLoadedLive(true);
        return;
      }

      if (appId === "openclaw") {
        try {
          const live = await openclawApi.getLiveProvider(provider.id);
          if (live && typeof live === "object") {
            setLiveSettings(live);
          }
        } catch {
          setLiveSettings(null);
        } finally {
          setHasLoadedLive(true);
        }
        return;
      }

      try {
        const currentId = await providersApi.getCurrent(appId);
        if (currentId && provider.id === currentId) {
          const live = await vscodeApi.getLiveProviderSettings(appId) as Record<string, unknown>;
          if (live && typeof live === "object") {
            setLiveSettings(live);
          }
        }
      } catch {
        setLiveSettings(null);
      } finally {
        setHasLoadedLive(true);
      }
    };

    void load();
  }, [provider.id, appId, isProxyTakeover, hasLoadedLive]);

  const initialData = useMemo(() => ({
    name: provider.name,
    notes: provider.notes,
    websiteUrl: provider.websiteUrl,
    settingsConfig: liveSettings ?? provider.settingsConfig ?? {},
    category: provider.category,
    meta: provider.meta,
    icon: provider.icon,
    iconColor: provider.iconColor,
  }), [provider, liveSettings]);

  const handleSubmit = async (values: ProviderFormValues) => {
    setIsSubmitting(true);
    try {
      const parsedConfig = JSON.parse(values.settingsConfig) as Record<string, unknown>;
      const updatedProvider: Provider = {
        ...provider,
        name: values.name.trim(),
        notes: values.notes?.trim() || undefined,
        websiteUrl: values.websiteUrl?.trim() || undefined,
        settingsConfig: parsedConfig,
        icon: values.icon?.trim() || undefined,
        iconColor: values.iconColor?.trim() || undefined,
        ...(values.presetCategory ? { category: values.presetCategory } : {}),
        ...(values.meta ? { meta: values.meta } : {}),
      };
      await onSave(updatedProvider);
      onBack();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 pb-4 border-b shrink-0">
        <Button
          variant="ghost"
          size="sm"
          onClick={onBack}
          className="gap-1"
        >
          <ArrowLeft className="w-4 h-4" />
          {t("common.back", { defaultValue: "返回" })}
        </Button>
        <div className="flex-1">
          <h3 className="text-sm font-semibold">
            {t("provider.editProvider", { defaultValue: "编辑供应商" })}
          </h3>
          <p className="text-xs text-muted-foreground">{provider.name}</p>
        </div>
      </div>

      {/* Form */}
      <div className="flex-1 overflow-y-auto py-4">
        <ProviderForm
          appId={appId}
          providerId={provider.id}
          submitLabel={t("common.save")}
          onSubmit={handleSubmit}
          onCancel={onBack}
          onSubmittingChange={setIsSubmitting}
          initialData={initialData}
          showButtons={true}
        />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors related to ProviderEditView

- [ ] **Step 3: Commit**

```bash
git add src/components/agents/ProviderEditView.tsx
git commit -m "feat: create ProviderEditView for inline provider editing"
```

---

### Task 4: Create OpenClawConfigEditor Component

**Files:**
- Create: `src/components/agents/OpenClawConfigEditor.tsx`

- [ ] **Step 1: Create OpenClawConfigEditor component**

Create new file `src/components/agents/OpenClawConfigEditor.tsx`:

```typescript
import { useState, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { ArrowLeft, Save, Loader2, FolderOpen } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import JsonEditor from "@/components/JsonEditor";
import { invoke } from "@tauri-apps/api/core";

interface OpenClawConfigEditorProps {
  onBack: () => void;
}

export function OpenClawConfigEditor({ onBack }: OpenClawConfigEditorProps) {
  const { t } = useTranslation();
  const [editorValue, setEditorValue] = useState<string>("");
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isDarkMode, setIsDarkMode] = useState(false);

  // Load config content
  useEffect(() => {
    const load = async () => {
      setIsLoading(true);
      try {
        const content = await invoke<string>("read_openclaw_json_raw");
        setEditorValue(content || "{}");
      } catch (error) {
        console.error("Failed to load openclaw.json:", error);
        toast.error(
          t("agent.config.loadFailed", { defaultValue: "加载配置文件失败" })
        );
        setEditorValue("{}");
      } finally {
        setIsLoading(false);
      }
    };
    void load();
  }, []);

  // Dark mode detection
  useEffect(() => {
    setIsDarkMode(document.documentElement.classList.contains("dark"));
    const observer = new MutationObserver(() => {
      setIsDarkMode(document.documentElement.classList.contains("dark"));
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });
    return () => observer.disconnect();
  }, []);

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await invoke("write_openclaw_json_raw", { content: editorValue });
      toast.success(t("agent.config.saveSuccess", { defaultValue: "配置已保存" }));
    } catch (error) {
      console.error("Failed to save openclaw.json:", error);
      toast.error(
        t("agent.config.saveFailed", {
          error: error instanceof Error ? error.message : String(error),
          defaultValue: "保存配置失败: {{error}}",
        })
      );
    } finally {
      setIsSaving(false);
    }
  };

  const handleOpenConfigDir = async () => {
    try {
      await invoke("reveal_in_finder", { path: "~/.openclaw" });
    } catch (error) {
      console.error("Failed to open config dir:", error);
      toast.error(
        t("agent.config.openDirFailed", { defaultValue: "打开配置目录失败" })
      );
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 pb-4 border-b shrink-0">
        <Button
          variant="ghost"
          size="sm"
          onClick={onBack}
          className="gap-1"
        >
          <ArrowLeft className="w-4 h-4" />
          {t("common.back", { defaultValue: "返回" })}
        </Button>
        <div className="flex-1">
          <h3 className="text-sm font-semibold">
            {t("agent.config.openclawConfig", { defaultValue: "OpenClaw 配置" })}
          </h3>
          <p className="text-xs text-muted-foreground font-mono">
            ~/.openclaw/openclaw.json
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            onClick={handleOpenConfigDir}
            size="sm"
            variant="outline"
            className="gap-1"
          >
            <FolderOpen className="w-3.5 h-3.5" />
            {t("agent.config.openDir", { defaultValue: "打开目录" })}
          </Button>
          <Button
            onClick={handleSave}
            disabled={isSaving}
            size="sm"
            className="gap-1"
          >
            {isSaving ? (
              <Loader2 className="w-3.5 h-3.5 animate-spin" />
            ) : (
              <Save className="w-3.5 h-3.5" />
            )}
            {t("common.save", { defaultValue: "保存" })}
          </Button>
        </div>
      </div>

      {/* JSON Editor - fills remaining space */}
      <div className="flex-1 min-h-0 py-4">
        <div className="h-full border rounded-lg overflow-hidden">
          <JsonEditor
            value={editorValue}
            onChange={setEditorValue}
            height="100%"
            darkMode={isDarkMode}
          />
        </div>
      </div>

      {/* Warning */}
      <div className="rounded-lg bg-amber-500/10 border border-amber-500/20 p-3 shrink-0">
        <p className="text-xs text-amber-600 dark:text-amber-400">
          {t("agent.config.advancedWarning", {
            defaultValue:
              "直接编辑配置文件可能会影响应用行为，请确保您了解正在修改的内容。保存前请备份重要数据。",
          })}
        </p>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/components/agents/OpenClawConfigEditor.tsx
git commit -m "feat: create OpenClawConfigEditor for full config editing"
```

---

### Task 5: Update AgentBasicConfig Imports and Usage

**Files:**
- Modify: `src/components/agents/AgentBasicConfig.tsx`

- [ ] **Step 1: Add imports for new components**

Add imports at the top:
```typescript
import { ProviderEditView } from "./ProviderEditView";
import { OpenClawConfigEditor } from "./OpenClawConfigEditor";
```

- [ ] **Step 2: Remove unused imports**

Remove:
```typescript
import { EditProviderDialog } from "@/components/providers/EditProviderDialog";
import { useLastValidValue } from "@/hooks/useLastValidValue";
```

- [ ] **Step 3: Update handleEditProvider**

Change the function to just call onSave and go back:
```typescript
const handleEditProvider = async (provider: Provider) => {
  await updateProvider(provider);
  setEditingProviderId(null);
};
```

- [ ] **Step 4: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add src/components/agents/AgentBasicConfig.tsx
git commit -m "refactor: integrate ProviderEditView and OpenClawConfigEditor"
```

---

### Task 6: Delete AgentAdvancedConfig

**Files:**
- Delete: `src/components/agents/AgentAdvancedConfig.tsx`

- [ ] **Step 1: Delete the file**

```bash
git rm src/components/agents/AgentAdvancedConfig.tsx
```

- [ ] **Step 2: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: remove AgentAdvancedConfig (no longer needed)"
```

---

### Task 7: Update i18n Translations

**Files:**
- Modify: `src/i18n/locales/zh.json`
- Modify: `src/i18n/locales/en.json`

- [ ] **Step 1: Add new translation keys in zh.json**

Add under `agent.config`:
```json
"editConfig": "编辑配置",
"openclawConfig": "OpenClaw 配置"
```

- [ ] **Step 2: Add new translation keys in en.json**

Add under `agent.config`:
```json
"editConfig": "Edit Config",
"openclawConfig": "OpenClaw Configuration"
```

- [ ] **Step 3: Commit**

```bash
git add src/i18n/locales/zh.json src/i18n/locales/en.json
git commit -m "feat: add translation keys for config editor"
```

---

### Task 8: Final Verification

- [ ] **Step 1: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 2: Run unit tests**

Run: `bun run test:unit`
Expected: All tests pass

- [ ] **Step 3: Manual testing checklist**

1. Open Settings > Agent设置 tab
2. Verify only 5 tabs remain (no 高级设置)
3. Click on a provider card
4. Verify form appears inline (no dialog)
5. Click Back button, verify return to list
6. Switch to OpenClaw agent
7. Verify "编辑配置" button appears in header
8. Click "编辑配置", verify full-height JSON editor opens
9. Verify JSON shows entire openclaw.json
10. Test Save and Back functionality

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: final adjustments for agent config UI simplification"
```

---

## Summary of Changes

1. **Removed "高级设置" tab** - Cleaned up AgentConfigView, deleted AgentAdvancedConfig
2. **Inline provider editing** - Click provider → form replaces list, Back button returns
3. **OpenClaw dedicated editor** - "Edit Config" button opens full-page JSON editor
4. **Better UX** - No more popup dialogs, better use of screen space