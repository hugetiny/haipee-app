---
description: How Antigravity automatically detects and debugs Tauri frontend console errors
---

# Antigravity Automated Frontend Error Detection Workflow

Antigravity can automatically audit the Tauri frontend for runtime errors by utilizing the `browser_subagent` against the development server.

## 1. Prerequisites
- Ensure the dev server is running (usually on `http://localhost:3000`).
- Ensure `src/lib/browser-mock.ts` is imported in `main.tsx` to provide a safe execution environment.

## 2. The Verification Loop
When Antigravity needs to verify visual changes or check for hidden crashes:

1. **Start Dev Server**: Run `bun run dev:renderer` if not already active.
2. **Launch Subagent**: Call `browser_subagent` with a task like:
   > "Navigate to http://localhost:3000. Interact with the app (e.g., click Settings). Then call capture_browser_console_logs and report any stderr or Uncaught ReferenceErrors."
3. **Analyze Logs**: Antigravity reads the returned logs.
4. **Auto-Fix**: If the log contains a Traceback or a component name, Antigravity immediately reads the relevant file and proposes a fix.

## 3. Best Practices
- **Mocking**: If a specific Native API call (e.g., `invoke('do_action')`) is causing a crash in the browser, update `src/lib/browser-mock.ts` to include that command name in the `Tauri Mock`.
- **Snapshots**: Use `capture_browser_screenshot` along with logs to correlate visual glitches with console errors.

// turbo-all
