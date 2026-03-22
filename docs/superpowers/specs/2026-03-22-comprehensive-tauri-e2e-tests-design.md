# Comprehensive Tauri E2E Tests Design

## Overview

This document specifies a comprehensive E2E test suite for Haipee, a Tauri v2 desktop application. The tests will cover every UI component, interaction, and edge case to enable AI-driven autonomous development.

## Goals

1. **Maximum Coverage**: Test every view, panel, dialog, form, and interaction
2. **Maximum Depth**: Include happy paths, validation errors, API failures, and edge cases
3. **AI-Ready**: Replace existing tauri-e2e layer in ai-dev-loop for autonomous development
4. **Maintainability**: Use Page Object Model pattern for easy updates when UI changes

## WKWebView Constraints

**CRITICAL**: The app runs in WKWebView on macOS, which has significant WebDriver limitations:

| Limitation | Workaround |
|------------|------------|
| `:has-text()` pseudo-selector not supported | Use `browser.execute()` with JavaScript text search |
| `:contains()` selector not standard | Use `browser.execute()` to find elements by text |
| `isDisplayed()` always returns false | Check CSS properties: `display`, `visibility`, `opacity` |
| Element references from `execute()` return null | Use temp attribute marking pattern |

**Example pattern for text-based element finding:**
```typescript
// Instead of: await $('button:has-text("Add Provider")')
const uid = `wdio-${Date.now()}`;
await browser.execute((attrKey) => {
  const btn = Array.from(document.querySelectorAll('button'))
    .find(b => b.textContent?.includes('Add Provider'));
  if (btn) btn.setAttribute(attrKey, 'true');
}, uid);
const element = await $(`[${uid}]`);
```

**Example pattern for visibility check:**
```typescript
// Instead of: await element.isDisplayed()
async function isElementVisible(element: WebdriverIO.Element): Promise<boolean> {
  const display = await element.getCSSProperty('display');
  if (display.value === 'none') return false;
  const visibility = await element.getCSSProperty('visibility');
  if (visibility.value === 'hidden') return false;
  const opacity = await element.getCSSProperty('opacity');
  if (parseFloat(String(opacity.value)) === 0) return false;
  return true;
}
```

## Test Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Framework | WebdriverIO + Mocha | E2E testing |
| Runner | tauri-plugin-webdriver | Real WKWebView testing |
| Pattern | Page Object Model (POM) | Maintainable selectors |
| Organization | Feature-based | One spec per major feature |

## File Structure

**Migration Note**: Existing tests in `tests/e2e/tauri/flows/` and `tests/e2e/tauri/views/` will be migrated to the new feature-based structure. The `tests/e2e-tauri/` directory is a separate test suite and remains unchanged.

```
tests/e2e/tauri/
├── providers/                     # Provider management tests
│   ├── provider-list.spec.ts      # List display, search, sort
│   ├── provider-crud.spec.ts      # Add, edit, delete, duplicate
│   ├── provider-switch.spec.ts    # Switch, takeover, failover
│   └── provider-actions.spec.ts   # Terminal, website, usage script
├── settings/                      # Settings tests
│   ├── settings-general.spec.ts   # Language, theme, window, terminal
│   ├── settings-proxy.spec.ts     # Proxy toggle, config, failover
│   ├── settings-auth.spec.ts      # Auth center, OAuth
│   ├── settings-advanced.spec.ts  # Directory, import/export, backup
│   ├── settings-usage.spec.ts     # Usage dashboard
│   └── settings-about.spec.ts     # Version info
├── agents/                        # Per-agent config tests
│   ├── agent-claude.spec.ts       # Claude-specific config
│   ├── agent-codex.spec.ts        # Codex-specific config
│   ├── agent-gemini.spec.ts       # Gemini-specific config
│   ├── agent-opencode.spec.ts     # OpenCode-specific config
│   └── agent-openclaw.spec.ts     # OpenClaw-specific config
├── skills/                        # Skills management tests
│   ├── skills-list.spec.ts        # Skills display, search
│   ├── skills-crud.spec.ts        # Add, edit, delete skills
│   └── skills-discovery.spec.ts   # Skill discovery page
├── mcp/                           # MCP server tests
│   └── mcp-servers.spec.ts        # MCP server CRUD
├── prompts/                       # Prompts tests
│   └── prompts-crud.spec.ts       # Prompts CRUD
├── sessions/                      # Session manager tests
│   └── sessions-management.spec.ts
├── navigation/                    # Navigation tests
│   └── navigation.spec.ts         # App/view switching
├── openclaw/                      # OpenClaw-specific tests
│   ├── openclaw-gateway.spec.ts   # Gateway panel
│   ├── openclaw-channels.spec.ts  # Channels panel
│   └── openclaw-env-tools.spec.ts # Env & Tools panels
├── universal/                     # Universal provider tests
│   └── universal-provider.spec.ts
├── pages/                         # Page Object Models
│   ├── DashboardPage.ts           # Provider list page
│   ├── SettingsPage.ts            # Settings page
│   ├── AgentConfigPage.ts         # Agent config page
│   ├── SkillsPage.ts              # Skills page
│   ├── McpPage.ts                 # MCP page
│   ├── PromptsPage.ts             # Prompts page
│   ├── SessionManagerPage.ts      # Sessions page
│   ├── NavigationPage.ts          # Navigation helpers
│   ├── OpenClawPages.ts           # OpenClaw-specific pages
│   └── UniversalProviderPage.ts   # Universal provider page
└── utils/                         # Test utilities
    ├── test-helpers.ts            # Common test helpers
    ├── data-manager.ts            # Test data management
    └── assertions.ts              # Custom assertions
```

## Prerequisite: data-testid Infrastructure

**CRITICAL**: The current UI components do not have `data-testid` attributes. These must be added before tests can be written reliably.

### Phase 0: Add data-testid Attributes

Add `data-testid` attributes to all key UI elements:

| Component | data-testid | File |
|-----------|-------------|------|
| Provider grid | `provider-grid` | ProviderList.tsx |
| Provider card | `provider-card` | ProviderCard.tsx |
| Add provider button | `add-provider-btn` | ProviderList.tsx |
| Edit provider button | `edit-provider-btn` | ProviderCard.tsx |
| Delete provider button | `delete-provider-btn` | ProviderCard.tsx |
| Provider search input | `provider-search` | ProviderList.tsx |
| Settings tab | `settings-tab-{name}` | SettingsPage.tsx |
| Language selector | `language-selector` | LanguageSettings.tsx |
| Theme buttons | `theme-btn-{light\|dark\|system}` | ThemeSettings.tsx |
| Proxy toggle | `proxy-toggle` | ProxyToggle.tsx |
| Failover toggle | `failover-toggle` | FailoverToggle.tsx |
| ... | ... | ... |

**Implementation approach:**
1. Create a PR adding all `data-testid` attributes
2. Run existing tests to verify no breakage
3. Merge before starting test implementation

### Alternative: Text-Based Selectors (Fallback)

If `data-testid` cannot be added immediately, use text-based selectors via `browser.execute()`:

```typescript
// Find button by text content
const btn = await browser.execute(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  return buttons.find(b => b.textContent?.includes('Add Provider'));
});
```

## Async State Handling

All tests must handle async UI updates properly:

### Wait Strategies

```typescript
// 1. Wait for element to exist
await browser.waitUntil(
  async () => await element.isExisting(),
  { timeout: 5000, timeoutMsg: 'Element not found' }
);

// 2. Wait for loading to complete
await browser.waitUntil(
  async () => !(await loadingSpinner.isExisting()),
  { timeout: 10000, timeoutMsg: 'Loading did not complete' }
);

// 3. Wait for toast notification
await browser.waitUntil(
  async () => {
    const toast = await $('[role="alert"]');
    return await toast.isExisting();
  },
  { timeout: 5000, timeoutMsg: 'Toast did not appear' }
);

// 4. Wait for React Query data
await browser.waitUntil(
  async () => {
    const count = await browser.execute(() =>
      document.querySelectorAll('[data-provider-id]').length
    );
    return count > 0;
  },
  { timeout: 10000, timeoutMsg: 'Providers did not load' }
);
```

### Animation Handling

```typescript
// Wait for Framer Motion animation
await browser.pause(300); // 300ms for most animations

// Or wait for specific animation state
await browser.waitUntil(
  async () => {
    const opacity = await element.getCSSProperty('opacity');
    return opacity.value === '1';
  },
  { timeout: 1000 }
);
```

## External Services & Mocking

### Tests Requiring External Services

| Test | Service | Strategy |
|------|---------|----------|
| OAuth login | GitHub API | Skip in CI, manual test only |
| WebDAV sync | Remote server | Mock responses, skip real sync |
| Usage stats | Internal DB | Use test fixtures |
| Gateway health | OpenClaw process | Mock health check |

### CI-Safe Test Markers

```typescript
// Mark tests that require external services
describe('@integration Auth Tests', () => {
  before(function() {
    // Skip in CI environment
    if (process.env.CI) {
      this.skip();
    }
  });

  it('should complete OAuth flow', async () => {
    // ...
  });
});
```

### Mock Data Fixtures

```typescript
// tests/e2e/tauri/fixtures/mock-providers.ts
export const mockProviders = [
  { id: 'test-1', name: 'Test Provider 1', apiKey: 'sk-test-1' },
  { id: 'test-2', name: 'Test Provider 2', apiKey: 'sk-test-2' },
];

// Use in tests
before(async () => {
  await invokeIPC('test_seed_providers', mockProviders);
});
```

## Error Scenarios & Recovery Tests

### Network Failure Tests

| Scenario | Test |
|----------|------|
| Offline mode | Provider switch fails gracefully |
| API timeout | Show error toast, allow retry |
| Invalid response | Parse error handled |
| Connection refused | Proxy start failure message |

### IPC Failure Tests

| Scenario | Test |
|----------|------|
| Command timeout | Settings save timeout |
| Unknown command | Error message displayed |
| Permission denied | File access error |
| Database locked | Retry mechanism works |

### Config Corruption Tests

| Scenario | Test |
|----------|------|
| Invalid JSON | Import shows parse error |
| Missing fields | Config migration handles |
| Wrong version | Migration prompt shown |

### App Crash Recovery

| Scenario | Test |
|----------|------|
| Unexpected exit | Session restored |
| Memory limit | Graceful shutdown |
| Render error | Error boundary catches |

## Additional Test Coverage

### Missing from Original Design

| Area | Tests |
|------|-------|
| Deep Link Import | `deeplink-import.spec.ts` - Handle `haipee://` URLs |
| Migration Notifications | Verify config/skills migration toasts |
| MCP Channel Init | Channel initialization status |
| Provider Reorder | Drag-and-drop sortIndex updates |
| Failover Priority | Queue management, priority badges |
| OMO Disable | OpenCode-specific disable flow |
| WebDAV Events | Sync status event handling |
| Health Badges | Provider health status display |
| Rectifier Config | RectifierConfigPanel tests |
| Remote Connect | RemoteConnectPanel tests |

## Test Coverage Details

### 1. Providers (35 tests)

#### provider-list.spec.ts - List Display & Search
- Display providers in grid layout
- Show provider icons and names correctly
- Show current provider indicator (checkmark)
- Show proxy takeover status badge
- Show health status indicator
- Empty state when no providers
- Loading skeleton during fetch
- Search with Cmd/Ctrl+F opens search
- Search filters by provider name
- Search filters by notes
- Search shows "no results" for unmatched query
- Close search with Escape
- Clear search button works

#### provider-crud.spec.ts - CRUD Operations
- Open add provider dialog
- Add provider with required fields only
- Add provider with all optional fields
- Validation: empty name shows error
- Validation: invalid API key format shows error
- Validation: invalid URL shows error
- Cancel add dialog doesn't create provider
- Edit provider name
- Edit provider notes
- Edit provider API key
- Edit provider base URL
- Edit advanced settings (model, headers)
- Duplicate provider with correct name
- Delete provider shows confirmation
- Cancel delete doesn't remove provider
- Confirm delete removes provider
- Remove from config (OpenCode/OpenClaw) vs delete distinction

#### provider-switch.spec.ts - Switching & Takeover
- Click provider to switch
- Switch shows toast notification
- Switch updates current provider indicator
- Switch updates tray menu
- Proxy takeover toggle works
- Takeover activates when proxy running
- Active provider badge shows during takeover
- Switch persists across app restart

#### provider-actions.spec.ts - Additional Actions
- Open website in browser
- Open terminal (Claude only)
- Configure usage script modal
- Set as default model (OpenClaw only)
- Disable OMO (OpenCode only)
- Copy API key to clipboard

### 2. Settings (55 tests)

#### settings-general.spec.ts - General Tab
**Language Settings:**
- Display language options (中文, English)
- Switch to English
- Switch to Chinese
- Language persists after app restart

**Theme Settings:**
- Display theme options (light, dark, system)
- Switch to light theme
- Switch to dark theme
- Switch to system theme
- Theme applies to document root

**Window Settings:**
- Toggle "launch at login"
- Toggle "minimize to tray"
- Toggle "show in dock"
- Toggle "always on top"

**Skill Sync Settings:**
- Select sync method (auto, git, manual)
- Sync method persists

**Terminal Settings:**
- Display installed terminals (scanned)
- Select preferred terminal
- Terminal selection persists

#### settings-proxy.spec.ts - Proxy Tab
**Local Proxy:**
- Display proxy toggle
- Toggle proxy on
- Toggle proxy off
- Show proxy status (running/stopped)
- Show proxy port (default 8877)
- Change proxy port
- Invalid port shows validation error

**Failover:**
- Toggle failover on
- Toggle failover off
- Show failover queue count
- Clear failover queue

**Circuit Breaker:**
- Configure failure threshold
- Configure recovery timeout
- Show circuit breaker status

#### settings-auth.spec.ts - Auth Tab
- Display auth center panel
- Show GitHub Copilot option
- Show login status
- OAuth flow initiates
- Logout works
- Show auth error states

#### settings-advanced.spec.ts - Advanced Tab
**Directory Settings:**
- Show current config directories
- Browse and select new directory
- Reset directory to default
- Invalid path shows error
- Persist directory change

**Import/Export:**
- Select import file
- Import valid configuration
- Show error for invalid import file
- Export configuration
- Create backup before import

**Backup:**
- Show backup list
- Create manual backup
- Restore from backup
- Delete backup
- Configure backup interval
- Configure backup retention count

**Cloud Sync (WebDAV):**
- Configure WebDAV URL
- Configure WebDAV credentials
- Test connection
- Sync now
- Show sync status
- Show sync error

**Model Test:**
- Configure test endpoint
- Run model test
- Show test results

**Log Config:**
- Configure log level
- Configure log output path

#### settings-usage.spec.ts - Usage Tab
- Show usage dashboard
- Show token usage charts
- Show request count
- Show usage by provider
- Export usage data

#### settings-about.spec.ts - About Tab
- Show app version
- Show installed tool versions (claude, codex, gemini, opencode)
- Show GitHub link
- Open GitHub in browser

### 3. Agents (25 tests)

Each agent config test file follows the same pattern:

#### agent-[app].spec.ts
- Display config tabs
- Show basic config panel
- Edit model selection
- Edit environment variables (app-specific)
- Show Skills/MCP panel
- View installed skills
- View MCP servers

**App-specific tests:**
- Claude: max tokens, temperature
- Codex: Copilot auth integration
- Gemini: GCP project settings
- OpenCode: live providers toggle
- OpenClaw: Env/Tools/Agents defaults panels

### 4. Skills (20 tests)

#### skills-list.spec.ts
- Display skills list
- Show skill categories
- Search skills by name
- Filter by app
- Show skill details
- Show skill status (installed/not installed)

#### skills-crud.spec.ts
- Add skill from file
- Add skill from URL
- Edit skill name
- Edit skill content
- Delete skill
- Install skill
- Uninstall skill
- Skill validation errors

#### skills-discovery.spec.ts
- Open discovery page
- Browse available skills
- Filter by category
- Preview skill content
- Install skill from discovery

### 5. MCP Servers (7 tests)

#### mcp-servers.spec.ts
- Display MCP server list
- Add MCP server
- Edit MCP server config
- Delete MCP server
- Toggle MCP server on/off
- Test MCP server connection
- Show MCP server status

### 6. Prompts (7 tests)

#### prompts-crud.spec.ts
- Display prompts list
- Add prompt
- Edit prompt name
- Edit prompt content
- Delete prompt
- Search prompts
- Copy prompt to clipboard

### 7. Sessions (9 tests)

#### sessions-management.spec.ts
- Display sessions list
- Show session provider
- Show session timestamp
- Filter by app (Claude, Codex, OpenCode, OpenClaw, Gemini)
- Search sessions
- Open session in terminal
- Delete session
- Delete all sessions
- Show empty state

### 8. Navigation (15 tests)

#### navigation.spec.ts
**App Switching:**
- Switch to Claude app
- Switch to Codex app
- Switch to Gemini app
- Switch to OpenCode app
- Switch to OpenClaw app
- Disabled apps show correct state

**View Navigation:**
- Navigate to Providers view
- Navigate to Sessions view
- Navigate to Settings view
- Navigate to Skills view
- Navigate to MCP view
- Navigate to Prompts view
- Navigate to Agents view
- Navigate to Universal view

**Keyboard Shortcuts:**
- Cmd/Ctrl+, opens settings
- Escape returns to providers
- Escape closes dialogs

**Sidebar:**
- Desktop sidebar visible
- Mobile sidebar opens/closes
- Navigation items displayed

**State Persistence:**
- Last view persisted
- Last app persisted
- State restored on reload

### 9. OpenClaw-specific (15 tests)

#### openclaw-gateway.spec.ts
- Display gateway status
- Show gateway URL
- Toggle gateway on/off
- Configure gateway settings
- Show gateway health

#### openclaw-channels.spec.ts
- Display channels list
- Add channel
- Edit channel
- Delete channel
- Toggle channel on/off
- Show channel status

#### openclaw-env-tools.spec.ts
**Env Panel:**
- Display environment variables
- Add env var
- Edit env var
- Delete env var
- Show in config file

**Tools Panel:**
- Display available tools
- Toggle tool on/off
- Configure tool settings

### 10. Universal Provider (6 tests)

#### universal-provider.spec.ts
- Display universal provider list
- Add universal provider
- Edit universal provider
- Delete universal provider
- Sync universal providers
- Show sync status

## Page Object Model Structure

Each Page Object should follow this pattern:

```typescript
// Example: DashboardPage.ts
export class DashboardPage extends TauriBasePage {
  // Selectors
  private get providerGrid() { return $('[data-testid="provider-grid"]'); }
  private get addProviderBtn() { return $('[data-testid="add-provider-btn"]'); }
  private get searchInput() { return $('[data-testid="provider-search"]'); }

  // Actions
  async addProvider(data: ProviderFormData): Promise<void> { ... }
  async editProvider(name: string, updates: Partial<ProviderFormData>): Promise<void> { ... }
  async deleteProvider(name: string): Promise<void> { ... }
  async switchProvider(name: string): Promise<boolean> { ... }
  async searchProviders(query: string): Promise<void> { ... }

  // Queries
  async getProviderCount(): Promise<number> { ... }
  async getVisibleProviderNames(): Promise<string[]> { ... }
  async providerExists(name: string): Promise<boolean> { ... }
  async getCurrentProvider(): Promise<string | null> { ... }

  // State checks
  async isLoading(): Promise<boolean> { ... }
  async hasEmptyState(): Promise<boolean> { ... }
}
```

## AI Dev Loop Integration

Replace the existing `tauri-e2e` layer in `scripts/ai-dev-loop/test-runner.ts`:

```typescript
// Before
{ name: 'tauri-e2e', command: 'bunx wdio run wdio.conf.ts', timeout: 20 * 60 * 1000, priority: 5 }

// After
{ name: 'tauri-e2e', command: 'bunx wdio run wdio.conf.ts', timeout: 30 * 60 * 1000, priority: 5 }
```

Update `wdio.conf.ts` specs to include all new test files:

```typescript
specs: [
  './tests/e2e/tauri/providers/*.spec.ts',
  './tests/e2e/tauri/settings/*.spec.ts',
  './tests/e2e/tauri/agents/*.spec.ts',
  './tests/e2e/tauri/skills/*.spec.ts',
  './tests/e2e/tauri/mcp/*.spec.ts',
  './tests/e2e/tauri/prompts/*.spec.ts',
  './tests/e2e/tauri/sessions/*.spec.ts',
  './tests/e2e/tauri/navigation/*.spec.ts',
  './tests/e2e/tauri/openclaw/*.spec.ts',
  './tests/e2e/tauri/universal/*.spec.ts',
],
```

## Test Data Management

Create test fixtures for:

1. **Test Providers**: Create/delete providers with unique names
2. **Test Skills**: Sample skill files for CRUD operations
3. **Test MCP Servers**: Sample server configs
4. **Test Prompts**: Sample prompt content
5. **Test Sessions**: Clean up after tests

Use `data-testid` attributes for reliable selectors:

```tsx
<button data-testid="add-provider-btn">Add Provider</button>
<div data-testid="provider-card" data-provider-id={provider.id}>
```

## Error Handling

Each test should handle:

1. **Element not found**: Use `waitForExist` with timeout
2. **Stale element reference**: Retry logic
3. **Async rendering**: Wait for loading states
4. **IPC failures**: Mock fallbacks for browser testing

## Execution Strategy

1. **Order**: Tests run in file order, randomized within describe blocks
2. **Parallelization**: Run provider/settings/agents in parallel
3. **Timeout**: 90s per test, 30min total suite
4. **Retry**: Failed tests retry once
5. **Screenshots**: Capture on failure

## Success Criteria

- [ ] All `data-testid` attributes added to UI components
- [ ] ~200 test cases passing
- [ ] All spec files created with WKWebView-compatible selectors
- [ ] All Page Objects implemented with proper async handling
- [ ] Integration with ai-dev-loop verified
- [ ] No flaky tests (3 consecutive runs pass)
- [ ] Error scenario tests included
- [ ] Test coverage documented

## Migration Plan

1. **Phase 0**: Add `data-testid` attributes to all UI components (PR #1)
2. **Phase 1**: Create new Page Objects with WKWebView-compatible selectors
3. **Phase 2**: Write providers/ and settings/ tests
4. **Phase 3**: Write agents/ and skills/ tests
5. **Phase 4**: Write remaining tests (mcp, prompts, sessions, navigation, openclaw, universal)
6. **Phase 5**: Migrate tests from flows/ and views/ to new structure
7. **Phase 6**: Remove old tests, update wdio.conf.ts
8. **Phase 7**: Verify ai-dev-loop integration

## Estimated Effort

| Phase | Tests | Time |
|-------|-------|------|
| Phase 0 | data-testid PR | 1h |
| Phase 1 | Page Objects | 2h |
| Phase 2 | 90 tests | 4h |
| Phase 3 | 45 tests | 2.5h |
| Phase 4 | 50 tests | 2.5h |
| Phase 5 | Migration | 1h |
| Phase 6 | Cleanup | 0.5h |
| Phase 7 | Verification | 0.5h |
| **Total** | **~200 tests** | **14h** |

**Note**: Original estimate of 8h was optimistic. Realistic estimate with proper WKWebView workarounds, async handling, and error scenario tests is ~14 hours.