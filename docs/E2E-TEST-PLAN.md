# Comprehensive Tauri E2E Test Plan

This document outlines the complete E2E testing strategy for the Haipee Tauri application, covering every UI element and operation.

## Test Architecture

### Page Object Models (Existing)
- `TauriBasePage` - Base class with common utilities
- `DashboardPage` - Provider list and management
- `SettingsPage` - Settings with 8 tabs
- `NavigationPage` - App switching and navigation
- `OpenClawChatPage` - OpenClaw chat interface
- `AgentConfigPage` - Agent configuration
- `SessionManagerPage` - Session management
- `McpPage` - MCP server management
- `PromptsPage` - Prompt management
- `SkillsPage` - Skills management

### Test Categories
1. **Flow Tests** (`tests/e2e/tauri/flows/`) - End-to-end user journeys
2. **View Tests** (`tests/e2e/tauri/views/`) - UI component testing
3. **Settings Tests** (`settings-full.spec.ts`) - Settings page operations

---

## 1. Navigation Tests

### 1.1 App Switching (Sidebar)
- [ ] Click on Claude app icon → Switch to Claude view
- [ ] Click on Codex app icon → Switch to Codex view
- [ ] Click on Gemini app icon → Switch to Gemini view
- [ ] Click on OpenCode app icon → Switch to OpenCode view
- [ ] Click on OpenClaw app icon → Switch to OpenClaw view
- [ ] Verify active app indicator (highlighted icon)
- [ ] Verify disabled apps (greyed out, not clickable)
- [ ] Verify app status icons (checkmark for installed, warning for errors)

### 1.2 View Navigation
- [ ] Click sessions menu → Navigate to sessions view
- [ ] Click settings menu → Navigate to settings view
- [ ] Keyboard shortcut Cmd/Ctrl+, → Open settings
- [ ] Escape key → Return to providers view
- [ ] Verify view persistence across app switches

### 1.3 Mobile Navigation
- [ ] Mobile hamburger menu → Open sidebar
- [ ] Mobile bottom nav → Sessions/Settings navigation
- [ ] Mobile back gesture → Close overlay

---

## 2. Provider Management Tests

### 2.1 Provider List Display
- [ ] Display loading skeleton while loading
- [ ] Display empty state when no providers
- [ ] Display provider cards in grid layout
- [ ] Display current provider indicator (highlighted border)
- [ ] Display active provider indicator (green border in failover mode)
- [ ] Display failover priority badges
- [ ] Display provider health status

### 2.2 Provider Search
- [ ] Cmd/Ctrl+F → Open search overlay
- [ ] Search by name → Filter providers
- [ ] Search by notes → Filter providers
- [ ] Search by URL → Filter providers
- [ ] Clear search → Reset filter
- [ ] Escape → Close search overlay

### 2.3 Provider CRUD Operations
- [ ] Click "Add Provider" button → Open add dialog
- [ ] Fill form with valid data → Create provider
- [ ] Fill form with invalid data → Show validation errors
- [ ] Click edit on provider → Open edit dialog
- [ ] Modify provider → Save changes
- [ ] Click delete → Show confirm dialog
- [ ] Confirm delete → Remove provider
- [ ] Click duplicate → Create copy of provider

### 2.4 Provider Switch
- [ ] Click provider card → Switch to that provider
- [ ] Verify toast notification on switch
- [ ] Verify current provider indicator updates
- [ ] Verify proxy target updates (if proxy running)

### 2.5 Provider Actions (Context Menu)
- [ ] Open website → External link opens
- [ ] Open terminal → Terminal opens with env vars
- [ ] Test endpoint → Speed test runs
- [ ] Configure usage → Usage script dialog opens
- [ ] Set as default model (OpenClaw) → Default model updates

### 2.6 Drag and Drop Sort
- [ ] Drag provider card → Reorder in list
- [ ] Drop in new position → Sort order persists
- [ ] Verify sort order updates in database

### 2.7 OpenCode/OpenClaw Specific
- [ ] Add to config → Provider added to live config
- [ ] Remove from config → Provider removed from live config
- [ ] Import from live config → Create provider from config
- [ ] Set as default model (OpenClaw) → Default model badge appears

### 2.8 Failover Queue Management
- [ ] Toggle failover for provider → Add/remove from queue
- [ ] Verify failover priority badge updates
- [ ] Verify queue persistence

---

## 3. Settings Page Tests

### 3.1 Tab Navigation (8 Tabs)
- [ ] Models tab → AgentConfigView displayed
- [ ] General tab → Language/Theme/Window settings
- [ ] Proxy tab → Proxy configuration
- [ ] Auth tab → Auth center panel
- [ ] Env tab → System environment variables
- [ ] Advanced tab → Directory/Import/Export/Backup
- [ ] Usage tab → Usage dashboard
- [ ] About tab → Version info, tool versions

### 3.2 General Tab
- [ ] Language switch → UI language changes
- [ ] Theme toggle → Theme applies (light/dark/system)
- [ ] Window settings → Minimize to tray option
- [ ] Skill sync method → Change sync method
- [ ] Terminal preference → Change default terminal

### 3.3 Proxy Tab
- [ ] Proxy toggle → Start/stop proxy
- [ ] Failover toggle → Enable/disable failover
- [ ] Circuit breaker config → Configure thresholds
- [ ] Auto failover config → Configure settings

### 3.4 Auth Tab
- [ ] GitHub Copilot auth → OAuth flow
- [ ] View auth status
- [ ] Revoke auth

### 3.5 Environment Variables Tab
- [ ] Claude section → View ANTHROPIC_* vars
- [ ] Codex section → View OPENAI_* vars
- [ ] Gemini section → View GEMINI_* vars
- [ ] OpenCode section → View OPENCODE_* vars
- [ ] Add environment variable
- [ ] Edit environment variable
- [ ] Delete environment variable

### 3.6 Advanced Tab
- [ ] Directory settings → Browse/change directories
- [ ] Import config → Select file, import
- [ ] Export config → Generate export file
- [ ] Backup settings → Configure backup interval
- [ ] Cloud sync (WebDAV) → Configure sync
- [ ] Model test config → Configure test settings
- [ ] Log config → Configure logging

### 3.7 Usage Tab
- [ ] View usage statistics
- [ ] View token counts
- [ ] View request counts
- [ ] Date range filter

### 3.8 About Tab
- [ ] Display app version
- [ ] Display tool versions (Claude, Codex, etc.)
- [ ] GitHub link → Opens external
- [ ] Portable mode indicator

---

## 4. Session Management Tests

### 4.1 Session List
- [ ] Display sessions for selected app
- [ ] Display empty state when no sessions
- [ ] Search sessions → Filter list
- [ ] Filter by provider → Show filtered sessions
- [ ] Sort sessions (date, name)

### 4.2 Session Selection
- [ ] Click session → Load messages
- [ ] Display message history
- [ ] Display message roles (user/assistant)
- [ ] Display timestamps

### 4.3 Message Operations
- [ ] Type message in input
- [ ] Send message → Add to history
- [ ] Receive response → Display in chat
- [ ] Copy message text
- [ ] Delete message

### 4.4 Session Operations
- [ ] Create new session
- [ ] Delete session → Confirm dialog
- [ ] Export session
- [ ] Rename session

### 4.5 Channel Communication
- [ ] Claude session → MCP channel message
- [ ] OpenClaw session → WebSocket gateway message
- [ ] Codex session → Show "under development" toast
- [ ] Gemini session → Show "under development" toast
- [ ] OpenCode session → Show "under development" toast

---

## 5. MCP Server Management Tests

### 5.1 MCP List
- [ ] Display MCP servers for app
- [ ] Display server status (enabled/disabled)
- [ ] Display server type

### 5.2 MCP CRUD
- [ ] Add MCP server → Open dialog
- [ ] Configure server settings
- [ ] Toggle server enabled state
- [ ] Delete server

### 5.3 MCP Sync
- [ ] Import from Claude config
- [ ] Import from Codex config
- [ ] Import from Gemini config
- [ ] Sync to app config files

---

## 6. Skills Management Tests

### 6.1 Skills List
- [ ] Display skills for app
- [ ] Display skill categories
- [ ] Search skills

### 6.2 Skills CRUD
- [ ] Add skill → Create new skill
- [ ] Edit skill → Modify skill
- [ ] Delete skill → Remove skill
- [ ] Duplicate skill

### 6.3 Skills Discovery
- [ ] Browse available skills
- [ ] Import skill from registry
- [ ] Skill preview

---

## 7. Prompts Management Tests

### 7.1 Prompts List
- [ ] Display prompts for app
- [ ] Search prompts
- [ ] Filter by category

### 7.2 Prompts CRUD
- [ ] Add prompt → Create new prompt
- [ ] Edit prompt → Modify prompt
- [ ] Delete prompt → Remove prompt
- [ ] Duplicate prompt

### 7.3 Prompt Operations
- [ ] Copy prompt to clipboard
- [ ] Use prompt in session
- [ ] Import prompts
- [ ] Export prompts

---

## 8. OpenClaw Dashboard Tests

### 8.1 OpenClaw Views
- [ ] Providers view → Provider list
- [ ] Sessions view → Chat interface
- [ ] Env panel → Environment variables
- [ ] Tools panel → Tool configuration
- [ ] Agents panel → Agent defaults
- [ ] Gateway panel → Gateway connection
- [ ] Channels panel → Channel management

### 8.2 OpenClaw Gateway
- [ ] Initialize profile on first use
- [ ] Connect to gateway
- [ ] Send message via WebSocket
- [ ] Receive streaming response
- [ ] Stop generation

### 8.3 OpenClaw Chat
- [ ] Multi-turn conversation
- [ ] Context management
- [ ] Model selection

---

## 9. Proxy Tests

### 9.1 Proxy Toggle
- [ ] Start proxy → Toggle on
- [ ] Stop proxy → Toggle off
- [ ] Verify proxy status indicator
- [ ] Verify takeover mode

### 9.2 Failover Tests
- [ ] Enable failover → Toggle on
- [ ] Configure failover queue
- [ ] Verify automatic failover
- [ ] Circuit breaker triggers

---

## 10. Deep Link Tests

### 10.1 Import Provider
- [ ] haipee://v1/import?resource=provider&app=claude&... → Import dialog
- [ ] Fill provider details
- [ ] Confirm import

### 10.2 Error Handling
- [ ] Invalid deep link → Show error
- [ ] Missing parameters → Show error

---

## 11. Error Handling Tests

### 11.1 Network Errors
- [ ] API timeout → Show error toast
- [ ] Network failure → Show error message
- [ ] Retry mechanism

### 11.2 Validation Errors
- [ ] Invalid form data → Show validation errors
- [ ] Missing required fields → Highlight fields

### 11.3 IPC Errors
- [ ] Tauri command failure → Show error toast
- [ ] Database error → Show error message

---

## 12. Accessibility Tests

### 12.1 Keyboard Navigation
- [ ] Tab through all interactive elements
- [ ] Enter/Space to activate buttons
- [ ] Escape to close dialogs
- [ ] Arrow keys for navigation

### 12.2 Screen Reader
- [ ] All images have alt text
- [ ] All buttons have aria-labels
- [ ] Form inputs have labels
- [ ] Headings are properly structured

---

## 13. Internationalization Tests

### 13.1 Language Switch
- [ ] Switch to Chinese → All text in Chinese
- [ ] Switch to English → All text in English
- [ ] Verify RTL support (if needed)

### 13.2 Date/Time Formatting
- [ ] Dates formatted according to locale
- [ ] Numbers formatted according to locale

---

## Implementation Priority

### Phase 1: Core Flows (Critical Path)
1. Navigation tests (app switching, view switching)
2. Provider CRUD operations
3. Settings tab navigation
4. Session management basics

### Phase 2: Feature Coverage
1. All provider actions
2. All settings tabs content
3. MCP management
4. Skills management
5. Prompts management

### Phase 3: Edge Cases & Errors
1. Error handling
2. Validation
3. Network failures
4. Accessibility

### Phase 4: Advanced Features
1. OpenClaw gateway
2. Channel communication
3. Failover testing
4. Deep link import