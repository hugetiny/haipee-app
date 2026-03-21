# Agent Configuration UI Simplification

**Date:** 2026-03-20
**Status:** Approved

## Problem Statement

The current agent configuration UI has several issues:

1. **Dialog-based editing**: Provider edit forms appear as modal dialogs, which feel disconnected from the main UI and don't utilize available screen space well
2. **Redundant advanced config**: The "高级设置" tab exists for all agents but only OpenClaw has meaningful JSON editing; other agents show placeholder content
3. **Limited JSON view**: OpenClaw's advanced config shows a small JSON editor (400px height), not the entire openclaw.json file

## Solution

1. Replace dialog-based editing with inline navigation (list → form replacement)
2. Remove "高级设置" tab entirely from the tab list
3. For OpenClaw: Add a dedicated "Edit Config" button in Basic Config that opens a full-page JSON editor

## Changes

### 1. AgentBasicConfig: Inline Form Navigation

**Current Flow:**
```
ProviderList → Click Edit → Modal Dialog → Save → Close Dialog
```

**New Flow:**
```
ProviderList → Click Provider Card → Form Replaces List → Save → Back to List
```

**Implementation:**
- Add state `editingProviderId: string | null` to track which provider is being edited
- Add state `showConfigEditor: boolean` for OpenClaw config editing
- When `editingProviderId` is set: render `ProviderForm` with Back button instead of `ProviderList`
- When `showConfigEditor` is true (OpenClaw only): render full-height JSON editor

### 2. Remove Advanced Tab

**File:** `src/components/agents/AgentConfigView.tsx`

Remove `advanced` entry from `AGENT_TABS` array:
```typescript
const AGENT_TABS = [
  { id: "basic", labelKey: "agent.config.basic", labelFallback: "基础配置", icon: Settings2 },
  { id: "skills", labelKey: "agent.config.skills", labelFallback: "Skills", icon: Code2 },
  { id: "mcp", labelKey: "agent.config.mcp", labelFallback: "MCP", icon: Plug },
  { id: "prompts", labelKey: "agent.config.prompts", labelFallback: "提示词", icon: FileText },
  { id: "env", labelKey: "agent.config.env", labelFallback: "环境变量", icon: Terminal },
  // Remove: { id: "advanced", ... }
] as const;
```

### 3. OpenClaw: Full Config Editor

**Location:** Within `AgentBasicConfig` when `appId === "openclaw"`

**UI Structure:**
```
┌─────────────────────────────────────────────────────────┐
│ [← Back to Providers]                                   │
│ OpenClaw Configuration                                   │
│ Path: ~/.openclaw/openclaw.json                         │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ JSON Editor (fills remaining height)                │ │
│ │ - Full openclaw.json content                        │ │
│ │ - Editable                                          │ │
│ │ - Dark mode support                                 │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ [Open Directory] [Save]                                 │
└─────────────────────────────────────────────────────────┘
```

**Button Placement:** Add "Edit Config" button in the header row alongside "Add" button (OpenClaw only)

## File Changes Summary

| File | Action |
|------|--------|
| `src/components/agents/AgentConfigView.tsx` | Remove advanced tab |
| `src/components/agents/AgentBasicConfig.tsx` | Add inline form navigation + OpenClaw config editor |
| `src/components/agents/AgentAdvancedConfig.tsx` | Delete (no longer needed) |

## Verification

1. TypeScript compilation passes
2. Unit tests pass
3. Manual testing:
   - Click provider card → form appears in same area (no dialog)
   - Back button returns to provider list
   - For non-OpenClaw agents: "高级设置" tab is gone
   - For OpenClaw: "Edit Config" button opens full-page JSON editor
   - JSON editor shows entire openclaw.json
   - Save/Cancel work correctly