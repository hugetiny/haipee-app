# CrabNebula DevTools Trial - Removal Checklist

**Trial Period**: 14 days (remove after 2026-04-01)

## What Was Added

### 1. Rust Side (Feature Flag)
- `src-tauri/Cargo.toml` - Added `devtools` feature flag + optional `tauri-plugin-devtools` dependency
- `src-tauri/src/lib.rs` - Added `#[cfg(feature = "devtools")]` plugin initialization block

### 2. TypeScript Side
- `scripts/ai-dev-loop/diagnostics/crabnebula-capture.ts` - **NEW FILE** - DevTools WebSocket client
- `scripts/ai-dev-loop/types.ts` - Added `CrabNebulaTimelineEvent`, `CrabNebulaPerformanceSnapshot`, `CrabNebulaRustLog`, `CrabNebulaDevToolsData` types
- `scripts/ai-dev-loop/diagnostics/index.ts` - Added CrabNebula capture to `collectDiagnostics()` and `formatDiagnosticsForPrompt()`
- `package.json` - Added `dev:devtools` and `build:devtools` scripts

### 3. Documentation
- All CrabNebula code is tagged with `# TRIAL:` or `TRIAL:` comments
- This file serves as the removal guide

---

## Usage During Trial

```bash
# Run with DevTools enabled
bun run dev:devtools

# Build with DevTools enabled
bun run build:devtools

# Connect to DevTools UI
open https://app.crabnebula.dev
```

---

## Removal Steps (After Trial)

### Step 1: Delete New Files
```bash
rm scripts/ai-dev-loop/diagnostics/crabnebula-capture.ts
rm docs/CRABNEBULA-TRIAL-REMOVAL.md
```

### Step 2: Clean `src-tauri/Cargo.toml`
Remove these lines:
```toml
# From [features] section:
devtools = ["tauri-plugin-devtools"]  # TRIAL: CrabNebula DevTools - remove after 2026-04-01

# From [dependencies] section:
tauri-plugin-devtools = { version = "2", optional = true }  # TRIAL: CrabNebula DevTools - remove after 2026-04-01
```

### Step 3: Clean `src-tauri/src/lib.rs`
Remove this block (around line 205-209):
```rust
// TRIAL: CrabNebula DevTools (remove after 2026-04-01)
// Enable DevTools for performance monitoring and IPC tracing
#[cfg(feature = "devtools")]
{
    builder = builder.plugin(tauri_plugin_devtools::init());
}
```

### Step 4: Clean `scripts/ai-dev-loop/types.ts`
Remove these sections (lines 56-91):
```typescript
// ═══════════════════════════════════════════════════════════════════
// CrabNebula DevTools Types (TRIAL - remove after 2026-04-01)
// ═══════════════════════════════════════════════════════════════════

export interface CrabNebulaTimelineEvent { ... }
export interface CrabNebulaPerformanceSnapshot { ... }
export interface CrabNebulaRustLog { ... }
export interface CrabNebulaDevToolsData { ... }
```

Also update `DiagnosticData` interface - remove this line:
```typescript
crabnebulaData?: CrabNebulaDevToolsData;  // TRIAL: CrabNebula DevTools - remove after 2026-04-01
```

### Step 5: Clean `scripts/ai-dev-loop/diagnostics/index.ts`

Remove exports (lines 29-36):
```typescript
// TRIAL: CrabNebula DevTools exports (remove after 2026-04-01)
export {
  getCrabNebulaCapture,
  formatCrabNebulaDataForPrompt,
  checkCrabNebulaAvailability,
  type CrabNebulaCapture,
  type CrabNebulaCaptureData,
} from './crabnebula-capture.ts';
```

Remove imports (line 42):
```typescript
import { getCrabNebulaCapture, formatCrabNebulaDataForPrompt } from './crabnebula-capture.ts';  // TRIAL: remove after 2026-04-01
```

Remove `captureCrabNebula` option from `collectDiagnostics()` function signature.

Remove capture logic block (search for "TRIAL: Capture CrabNebula").

Remove CrabNebula section from `formatDiagnosticsForPrompt()` function (search for "TRIAL: CrabNebula DevTools data").

### Step 6: Clean `package.json`
Remove these scripts:
```json
"dev:devtools": "pnpm tauri dev --features devtools",
"build:devtools": "pnpm tauri build --features devtools"
```

### Step 7: Verify Removal
```bash
cargo check --manifest-path src-tauri/Cargo.toml
bun run typecheck
bun run test:unit
```

---

## Quick Search for Remaining References

```bash
# Find all TRIAL comments
grep -rn "TRIAL:" scripts/ src-tauri/src/ --include="*.ts" --include="*.rs"

# Find CrabNebula references
grep -rn "crabnebula\|CrabNebula\|devtools" scripts/ src-tauri/src/ --include="*.ts" --include="*.rs"
```
