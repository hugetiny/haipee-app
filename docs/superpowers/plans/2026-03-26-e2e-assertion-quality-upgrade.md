# E2E Test Assertion Quality Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace weak assertion patterns (`expect(true).toBe(true)`, `expect(typeof x).toBe('type')`) with meaningful assertions that verify actual application behavior.

**Architecture:** Systematically upgrade test files in priority order (user-journeys → errors → integration → platform). Each upgrade replaces fallback patterns with real behavioral checks that will fail when features are broken.

**Tech Stack:** WebdriverIO, Mocha, TypeScript, Page Object Model pattern

---

## Background: The Problem

### Current Weak Patterns

```typescript
// Pattern 1: Always passes (useless)
if (!element.isExisting()) {
  expect(true).toBe(true);  // ❌ No verification
  return;
}

// Pattern 2: Type check only (weak)
expect(typeof count).toBe('number');  // ❌ Passes for ANY number, even wrong ones

// Pattern 3: Boolean typeof (very weak)
expect(typeof isVisible).toBe('boolean');  // ❌ Passes for true OR false
```

### Target Strong Patterns

```typescript
// Pattern 1: Verify actual state
if (!element.isExisting()) {
  // Verify we're somewhere valid instead
  const hasContent = await browser.execute(() => document.body.textContent!.length > 0);
  expect(hasContent).toBe(true);  // ✅ Actually verifies something
  return;
}

// Pattern 2: Verify specific value
expect(count).toBeGreaterThanOrEqual(0);  // ✅ Any non-negative is valid
expect(count).toBe(3);  // ✅ Specific expected value

// Pattern 3: Verify expected boolean
expect(isVisible).toBe(true);  // ✅ Explicit expected value
```

---

## Files Overview

### Priority 1: user-journeys/ (10 files, ~218 weak assertions)

| File | Fallback | Typeof | Priority |
|------|----------|--------|----------|
| provider-lifecycle-journey.spec.ts | 21 | 12 | HIGH |
| multi-app-switching.spec.ts | 21 | 7 | HIGH |
| settings-workflow.spec.ts | 17 | 8 | MEDIUM |
| session-chat.spec.ts | 16 | 13 | MEDIUM |
| error-recovery.spec.ts | 10 | 8 | MEDIUM |
| first-launch.spec.ts | 8 | 6 | MEDIUM |
| mcp-integration.spec.ts | 12 | 9 | MEDIUM |
| provider-management.spec.ts | 7 | 11 | LOW |
| skill-workflow.spec.ts | 6 | 10 | LOW |
| data-portability.spec.ts | 8 | 8 | LOW |

### Priority 2: errors/ (6 files, ~148 weak assertions)

| File | Fallback | Typeof | Priority |
|------|----------|--------|----------|
| boundary-conditions.spec.ts | 20 | 16 | HIGH |
| form-validation.spec.ts | 8 | 20 | HIGH |
| concurrent-operations.spec.ts | 6 | 17 | MEDIUM |
| data-corruption.spec.ts | 11 | 15 | MEDIUM |
| network-errors.spec.ts | 12 | 9 | MEDIUM |
| error-handling.spec.ts | 3 | 11 | LOW |

### Priority 3: integration/ (5 files, ~90 weak assertions)

| File | Fallback | Typeof | Priority |
|------|----------|--------|----------|
| session-state-persistence.spec.ts | 18 | 3 | MEDIUM |
| cross-app-state-sync.spec.ts | 9 | 15 | MEDIUM |
| provider-mcp-integration.spec.ts | 6 | 10 | LOW |
| settings-propagation.spec.ts | 4 | 12 | LOW |
| provider-session-integration.spec.ts | 5 | 8 | LOW |

### Priority 4: platform/ (2 files, ~41 weak assertions)

| File | Fallback | Typeof | Priority |
|------|----------|--------|----------|
| keyboard-shortcuts.spec.ts | 8 | 20 | MEDIUM |
| accessibility.spec.ts | 0 | 13 | LOW |

---

## Phase 1: Helper Utilities

### Task 1.1: Add Assertion Helper Methods to JourneyHelpers

**Files:**
- Modify: `tests/e2e/crabnebula/user-journeys/journey-helpers.ts`

- [ ] **Step 1: Add meaningful assertion helpers**

Add these methods to the JourneyHelpers class:

```typescript
/**
 * Assert element exists or verify fallback state
 * Replaces: expect(true).toBe(true) with actual verification
 */
static async assertElementOrFallback(
  element: WebdriverIO.Element,
  fallbackCheck: () => Promise<boolean>,
  elementName: string
): Promise<boolean> {
  if (await element.isExisting()) {
    return true;
  }
  // Fallback: verify app is in a valid state
  const isValidState = await fallbackCheck();
  if (!isValidState) {
    console.log(`[assertElementOrFallback] ${elementName} not found and fallback check failed`);
  }
  return isValidState;
}

/**
 * Assert numeric value is valid (non-negative, or within range)
 * Replaces: expect(typeof count).toBe('number')
 */
static assertValidNumber(
  value: number,
  options: { min?: number; max?: number; allowZero?: boolean } = {}
): void {
  const { min = 0, max = Infinity, allowZero = true } = options;

  if (!allowZero && value === 0) {
    throw new Error(`Expected non-zero number, got 0`);
  }

  if (value < min) {
    throw new Error(`Expected number >= ${min}, got ${value}`);
  }

  if (value > max) {
    throw new Error(`Expected number <= ${max}, got ${value}`);
  }
}

/**
 * Assert page is in a valid state (has content, no crash)
 * Use as fallback when specific element not found
 */
static async assertValidPageState(): Promise<boolean> {
  const state = await browser.execute(() => {
    const body = document.body;
    const hasContent = (body.textContent || '').trim().length > 100;
    const hasCrash = body.textContent?.includes('Error') && body.textContent?.includes('crash');
    const hasReactRoot = document.querySelector('#root, [data-reactroot], .app') !== null;
    return {
      hasContent,
      hasCrash: !!hasCrash,
      hasReactRoot
    };
  });

  return state.hasContent && !state.hasCrash && state.hasReactRoot;
}

/**
 * Wait for and assert toast contains expected text
 * Replaces: expect(typeof toast).toBe('string')
 */
static async assertToastContains(expectedText: string | RegExp, timeout = 5000): Promise<boolean> {
  const toast = await this.waitForToast(timeout);
  if (!toast) {
    throw new Error(`No toast appeared within ${timeout}ms`);
  }

  if (expectedText instanceof RegExp) {
    if (!expectedText.test(toast)) {
      throw new Error(`Toast "${toast}" did not match pattern ${expectedText}`);
    }
  } else {
    if (!toast.includes(expectedText)) {
      throw new Error(`Toast "${toast}" did not contain "${expectedText}"`);
    }
  }
  return true;
}

/**
 * Assert provider was created or UI is valid
 */
static async assertProviderCreated(
  dashboard: DashboardPage,
  providerName: string
): Promise<{ created: boolean; count: number }> {
  const exists = await dashboard.providerExists(providerName);
  const count = await dashboard.getProviderCount();

  // Either provider exists, or we have some providers (UI valid)
  if (!exists && count === 0) {
    // Check if UI is still functional
    const validState = await this.assertValidPageState();
    if (!validState) {
      throw new Error(`Provider "${providerName}" not created and UI in invalid state`);
    }
  }

  return { created: exists, count };
}
```

- [ ] **Step 2: Run typecheck**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/crabnebula/user-journeys/journey-helpers.ts
git commit -m "feat(e2e): add assertion helper methods for test quality upgrade"
```

---

## Phase 2: Upgrade user-journeys Tests

### Task 2.1: Upgrade provider-lifecycle-journey.spec.ts

**Files:**
- Modify: `tests/e2e/crabnebula/user-journeys/provider-lifecycle-journey.spec.ts`

- [ ] **Step 1: Replace fallback assertions in Create Provider Journey**

Find and replace patterns:

**Lines 69-72 (auto-detect test):**
```typescript
// BEFORE
if (await typeSelect.isExisting()) {
  const value = await typeSelect.getValue();
  expect(typeof value).toBe('string');
} else {
  expect(true).toBe(true);
}

// AFTER
if (await typeSelect.isExisting()) {
  const value = await typeSelect.getValue();
  // Type should be auto-detected to something like 'openai' or 'anthropic'
  expect(value.length).toBeGreaterThan(0);
} else {
  // No type selector - verify form still has URL input
  const urlStillExists = await urlInput.isExisting();
  expect(urlStillExists).toBe(true);
}
```

**Lines 73-75:**
```typescript
// BEFORE
} else {
  expect(true).toBe(true);
}

// AFTER
} else {
  // URL input not found - verify we're on a valid page
  const validState = await JourneyHelpers.assertValidPageState();
  expect(validState).toBe(true);
}
```

- [ ] **Step 2: Replace fallback assertions in Configure Provider**

Find all `expect(true).toBe(true)` in Configure Provider section and replace:

```typescript
// Pattern to find:
expect(true).toBe(true);

// Replace with (context-dependent):
// Option A: Verify sidebar still visible
const sidebarVisible = await navigation.isSidebarVisible();
expect(sidebarVisible).toBe(true);

// Option B: Verify page state
const validState = await JourneyHelpers.assertValidPageState();
expect(validState).toBe(true);

// Option C: Verify specific element state
expect(await card.$('button').isExisting()).toBe(true);
```

- [ ] **Step 3: Replace typeof assertions**

```typescript
// BEFORE
expect(typeof count).toBe('number');

// AFTER
expect(count).toBeGreaterThanOrEqual(0);
```

```typescript
// BEFORE
expect(typeof toast).toBe('string');

// AFTER
expect(toast!.length).toBeGreaterThan(0);
```

- [ ] **Step 4: Run typecheck**

Run: `bun run typecheck`

- [ ] **Step 5: Commit**

```bash
git add tests/e2e/crabnebula/user-journeys/provider-lifecycle-journey.spec.ts
git commit -m "fix(e2e): upgrade provider-lifecycle-journey assertions"
```

---

### Task 2.2: Upgrade multi-app-switching.spec.ts

**Files:**
- Modify: `tests/e2e/crabnebula/user-journeys/multi-app-switching.spec.ts`

- [ ] **Step 1: Replace fallback assertions (21 instances)**

For each `expect(true).toBe(true)` in the file, replace with context-appropriate assertion:

```typescript
// App switching tests - verify sidebar after switch
expect(true).toBe(true);
// becomes:
const sidebarVisible = await navigation.isSidebarVisible();
expect(sidebarVisible).toBe(true);

// State persistence tests - verify data matches
expect(true).toBe(true);
// becomes verification that state is preserved
```

- [ ] **Step 2: Replace typeof assertions**

```typescript
// BEFORE
expect(typeof sessions2).toBe('number');

// AFTER
expect(sessions2).toBeGreaterThanOrEqual(0);
```

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/crabnebula/user-journeys/multi-app-switching.spec.ts
git commit -m "fix(e2e): upgrade multi-app-switching assertions"
```

---

### Task 2.3: Upgrade settings-workflow.spec.ts

**Files:**
- Modify: `tests/e2e/crabnebula/user-journeys/settings-workflow.spec.ts`

- [ ] **Step 1: Replace fallback assertions in General Settings**

In tests for theme/language, replace weak patterns with actual verification:

```typescript
// BEFORE
expect(true).toBe(true);

// AFTER - verify settings actually changed
const theme = await browser.execute(() =>
  document.documentElement.getAttribute('data-theme')
);
expect(['dark', 'light', 'system']).toContain(theme);
```

- [ ] **Step 2: Replace typeof assertions**

```typescript
// BEFORE
expect(typeof hasEnglish).toBe('boolean');

// AFTER
expect(hasEnglish).toBe(true); // We expect English to be detected
```

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/crabnebula/user-journeys/settings-workflow.spec.ts
git commit -m "fix(e2e): upgrade settings-workflow assertions"
```

---

### Task 2.4: Upgrade session-chat.spec.ts

**Files:**
- Modify: `tests/e2e/crabnebula/user-journeys/session-chat.spec.ts`

- [ ] **Step 1: Replace fallback assertions**

For session-related tests, verify actual session state:

```typescript
// BEFORE
expect(true).toBe(true);

// AFTER
const messageCount = await sessionPage.getMessageCount();
expect(messageCount).toBeGreaterThanOrEqual(0);
```

- [ ] **Step 2: Replace typeof assertions**

```typescript
// BEFORE
expect(typeof inputValue).toBe('string');

// AFTER
expect(inputValue.length).toBeGreaterThan(0);
```

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/crabnebula/user-journeys/session-chat.spec.ts
git commit -m "fix(e2e): upgrade session-chat assertions"
```

---

### Task 2.5-2.10: Upgrade Remaining user-journeys Files

Follow the same pattern for:

- `error-recovery.spec.ts` (10 fallbacks, 8 typeof)
- `first-launch.spec.ts` (8 fallbacks, 6 typeof)
- `mcp-integration.spec.ts` (12 fallbacks, 9 typeof)
- `provider-management.spec.ts` (7 fallbacks, 11 typeof)
- `skill-workflow.spec.ts` (6 fallbacks, 10 typeof)
- `data-portability.spec.ts` (8 fallbacks, 8 typeof)

Each task follows the same steps:
1. Replace `expect(true).toBe(true)` with context-appropriate assertions
2. Replace `expect(typeof x).toBe('type')` with value assertions
3. Run typecheck
4. Commit

---

## Phase 3: Upgrade errors Tests

### Task 3.1: Upgrade boundary-conditions.spec.ts

**Files:**
- Modify: `tests/e2e/crabnebula/errors/boundary-conditions.spec.ts`

- [ ] **Step 1: Replace fallback assertions (20 instances)**

Boundary tests should verify the boundary condition actually works:

```typescript
// BEFORE - empty state test
expect(true).toBe(true);

// AFTER - verify empty state UI
const hasEmptyState = await browser.execute(() => {
  const text = document.body.textContent || '';
  return text.includes('No provider') || text.includes('没有') || text.includes('暂无');
});
expect(hasEmptyState).toBe(true);
```

- [ ] **Step 2: Replace typeof assertions (16 instances)**

```typescript
// BEFORE
expect(typeof result).toBe('number');

// AFTER
expect(result).toBeGreaterThanOrEqual(0);
expect(result).toBeLessThanOrEqual(maxExpected);
```

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/crabnebula/errors/boundary-conditions.spec.ts
git commit -m "fix(e2e): upgrade boundary-conditions assertions"
```

---

### Task 3.2-3.6: Upgrade Remaining errors Files

Follow the same pattern for:

- `form-validation.spec.ts` (8 fallbacks, 20 typeof)
- `concurrent-operations.spec.ts` (6 fallbacks, 17 typeof)
- `data-corruption.spec.ts` (11 fallbacks, 15 typeof)
- `network-errors.spec.ts` (12 fallbacks, 9 typeof)
- `error-handling.spec.ts` (3 fallbacks, 11 typeof)

---

## Phase 4: Upgrade integration Tests

### Task 4.1-4.5: Upgrade integration Files

Files to upgrade:

- `session-state-persistence.spec.ts` (18 fallbacks, 3 typeof)
- `cross-app-state-sync.spec.ts` (9 fallbacks, 15 typeof)
- `provider-mcp-integration.spec.ts` (6 fallbacks, 10 typeof)
- `settings-propagation.spec.ts` (4 fallbacks, 12 typeof)
- `provider-session-integration.spec.ts` (5 fallbacks, 8 typeof)

---

## Phase 5: Upgrade platform Tests

### Task 5.1-5.2: Upgrade platform Files

Files to upgrade:

- `keyboard-shortcuts.spec.ts` (8 fallbacks, 20 typeof)
- `accessibility.spec.ts` (0 fallbacks, 13 typeof)

---

## Phase 6: Verification

### Task 6.1: Run Full Test Suite

- [ ] **Step 1: Run typecheck**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 2: Run E2E tests (if CN_API_KEY available)**

Run: `CN_API_KEY=xxx bun run test:e2e`
Expected: Tests pass or fail with meaningful errors

- [ ] **Step 3: Review any failures**

If tests fail, they should fail because:
- A feature is genuinely broken
- An assertion expectation needs adjustment

NOT because of weak assertion patterns.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(e2e): complete assertion quality upgrade

- Replace expect(true).toBe(true) with meaningful assertions
- Replace typeof checks with value assertions
- Add assertion helper methods to JourneyHelpers
- ~500 weak assertions upgraded to meaningful checks

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Summary

| Phase | Tasks | Files | Assertions Upgraded |
|-------|-------|-------|---------------------|
| 1. Helpers | 1 | 1 | N/A (adds utilities) |
| 2. user-journeys | 10 | 10 | ~218 |
| 3. errors | 6 | 6 | ~148 |
| 4. integration | 5 | 5 | ~90 |
| 5. platform | 2 | 2 | ~41 |
| 6. Verification | 1 | 0 | N/A |
| **Total** | **25** | **24** | **~500** |

## Notes for Implementation

1. **Each test file is a separate task** - Keep changes atomic
2. **Use JourneyHelpers.assertValidPageState()** for fallback when element not found
3. **Prefer specific values** over typeof checks
4. **Keep graceful degradation** but make it verify something real
5. **Test should fail if feature is broken** - that's the point