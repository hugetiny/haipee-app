# Comprehensive Tauri E2E Test Coverage Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand Tauri E2E tests to cover all critical user flows, error scenarios, and the newly fixed OpenClaw HTTP messaging.

**Architecture:** Add new test files for uncovered areas and enhance existing tests with behavior verification (not just UI presence). Focus on real user workflows.

**Tech Stack:** WebdriverIO + tauri-plugin-webdriver (WKWebView), TypeScript, Page Object Model pattern

---

## Test Coverage Gaps Analysis

### Currently Covered (31 spec files, ~340 tests)
| Category | Spec Files | Status |
|----------|------------|--------|
| Providers | 5 | ✅ CRUD, switching, actions |
| Settings | 6 | ✅ General, proxy, auth, usage, advanced, about |
| Agents/Skills/MCP/Prompts/Sessions | 5 | ⚠️ UI-only tests |
| Navigation/OpenClaw/Universal | 5 | ⚠️ Missing messaging tests |
| Flows | 3 | ⚠️ Limited integration |
| Views | 5 | ✅ View rendering |
| Channel Communication | 1 | ⚠️ Basic tests |
| Legacy | 6 | ✅ Covered |

### Identified Gaps

1. **OpenClaw Messaging** - No tests for HTTP-based messaging
2. **Proxy Integration** - UI-only, no behavior verification
3. **WebDAV Sync** - No tests
4. **Error Handling** - Limited coverage
5. **Session Operations** - Missing CRUD operations

---

## New Test Files

### 1. OpenClaw Messaging (`tests/e2e/tauri/openclaw/openclaw-messaging.spec.ts`)

**Purpose:** Test HTTP-based messaging with OpenClaw Gateway

**Test Cases:**
- Gateway connection initialization
- Send message and receive AI response
- Error handling (gateway not running, invalid token)
- Connection status indicators
- Default model configuration

**Dependencies:**
- Requires OpenClaw Gateway running (or mock)
- Uses `OpenClawGatewayPage` page object

### 2. WebDAV Sync (`tests/e2e/tauri/settings/settings-webdav.spec.ts`)

**Purpose:** Test WebDAV synchronization flow

**Test Cases:**
- Configure WebDAV URL and credentials
- Trigger manual sync
- Verify sync status indicators
- Handle sync errors

### 3. Error Scenarios (`tests/e2e/tauri/errors/error-handling.spec.ts`)

**Purpose:** Test error handling and recovery

**Test Cases:**
- Network timeout scenarios
- Invalid API key handling
- Database error recovery
- Toast notification display

---

## Enhanced Existing Tests

### Proxy Integration (enhance `settings-proxy.spec.ts`)

**Add behavior tests:**
- Verify proxy actually starts on configured port
- Verify requests route through proxy
- Test failover triggers correctly

### Session Management (enhance `sessions-management.spec.ts`)

**Add CRUD operations:**
- Create new session
- Rename session
- Delete session
- Switch between sessions

### Channel Communication (enhance `channel-communication.spec.ts`)

**Add real IPC tests:**
- Verify MCP channel initialization
- Test message sending via channel

---

## Page Object Updates

### New Methods for `OpenClawGatewayPage`:
- `connect()` - Connect to gateway
- `sendMessage(message: string)` - Send message via HTTP
- `waitForResponse(timeout: number)` - Wait for AI response
- `getLastError()` - Get last error message

### New Page Object: `WebDavPage`:
- `configure(url: string, username: string, password: string)`
- `sync()`
- `getSyncStatus()`

---

## Verification Checklist

- [ ] All new spec files pass
- [ ] Existing tests still pass
- [ ] Test count increases by 50+ tests
- [ ] OpenClaw messaging flow verified end-to-end
- [ ] Error scenarios covered