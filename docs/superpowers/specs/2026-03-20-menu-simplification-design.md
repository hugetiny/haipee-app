# Menu Simplification Design: Merge Agent配置 into Settings

**Date:** 2026-03-20
**Status:** Approved

## Problem Statement

The current menu structure has overlapping functionality:
- **一级菜单 "Agent配置"** provides per-agent configuration (基础配置, Skills, MCP, 提示词, 环境变量, 高级设置)
- **设置 > 模型 tab** also manages per-agent provider configurations

This creates confusion and redundancy. Users need to navigate two different places for related settings.

## Solution

Remove the top-level "Agent配置" menu and merge all its functionality into Settings.

## Changes

### 1. Remove from App

**File:** `src/App.tsx`
- Remove `agentConfig` from `View` type
- Remove `agentConfig` from `VALID_VIEWS`
- Remove the `case "agentConfig"` render block
- Remove import of `AgentConfigView` (but keep for use in Settings)

### 2. Remove from MainLayout

**File:** `src/components/layout/MainLayout.tsx`
- Remove `agentConfig` from `MainView` type
- Remove `agentConfig` from `MAIN_MENU_ITEMS` array
- Update `activeMainMenu` logic to remove `agentConfig` case

### 3. Update SettingsPage

**File:** `src/components/settings/SettingsPage.tsx`

Replace the current "模型" tab with an expanded "Agent设置" tab that includes:
- Agent selector (same as current AgentConfigView)
- Sub-tabs: 基础配置, Skills, MCP, 提示词, 环境变量, 高级设置

Structure:
```
<TabsContent value="agentSettings">
  <AgentConfigView />  {/* Reuse existing component */}
</TabsContent>
```

Tab renaming:
- "模型" → "Agent设置"
- Update i18n keys accordingly

### 4. Restructure AgentBasicConfig

**File:** `src/components/agents/AgentBasicConfig.tsx`

Move JSON editing functionality to 高级设置:
- Identify all JSON editor sections
- Keep UI controls (dropdowns, toggles, inputs) in 基础配置
- Move raw JSON editors to AgentAdvancedConfig

### 5. Update AgentAdvancedConfig

**File:** `src/components/agents/AgentAdvancedConfig.tsx`

Add JSON editors migrated from 基础配置:
- Accept new props for JSON editing sections
- Ensure consistent styling with existing advanced config UI

### 6. Update i18n

**Files:** `src/i18n/locales/zh.json`, `src/i18n/locales/en.json`

- Rename `settings.tabModels` to `settings.tabAgentSettings`
- Add any new translation keys needed

## File Changes Summary

| File | Action |
|------|--------|
| `src/App.tsx` | Remove agentConfig view |
| `src/components/layout/MainLayout.tsx` | Remove agentConfig menu item |
| `src/components/settings/SettingsPage.tsx` | Replace ModelsPanel with AgentConfigView |
| `src/components/agents/AgentBasicConfig.tsx` | Extract JSON editors |
| `src/components/agents/AgentAdvancedConfig.tsx` | Add JSON editors from 基础配置 |
| `src/i18n/locales/*.json` | Update translations |

## UI Design Principle

- **基础配置**: User-friendly UI controls (dropdowns, toggles, inputs)
- **高级设置**: Raw JSON editing for power users

## Verification

1. All existing Agent配置 features remain accessible in Settings > Agent设置
2. No functionality is lost
3. Settings dialog still closes/opens correctly
4. All sub-tabs work correctly within the new location
5. Mobile navigation updated to remove Agent配置