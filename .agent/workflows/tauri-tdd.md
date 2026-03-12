---
description: Antigravity Modern Tauri TDD & UI Automation Workflow
---

# Antigravity Tauri TDD & Automated UI Workflow (2026)

This workflow defines the standard operating procedure for Antigravity to perform Test-Driven Development (TDD) and frontend UI automation in this Tauri application. Since Antigravity possesses powerful built-in tools, no external MCPs (like puppeteer) are required.

## 1. Context & Task Management
- **Task Constraints**: Always read `task.md` and use the `task_boundary` tool properly. 
- **Persistent Knowledge**: Check Knowledge Items (KIs) or previous conversations if you encounter confusing architecture patterns. For this project, use `bun` exclusively instead of `pnpm`.

## 2. Backend TDD Loop (Rust)
1. **Red**: Write a failing test in `src-tauri/src/` or `src-tauri/tests/`. Use `run_command` to execute `cargo test --manifest-path src-tauri/Cargo.toml --color always` and verify it fails.
2. **Green**: Implement the minimal Rust code required to pass the test using `replace_file_content` or `multi_replace_file_content`.
3. **Verify**: Ensure the test passes.
4. **Refactor**: Clean up implementation. Run `cargo clippy --manifest-path src-tauri/Cargo.toml` to ensure no warnings.

## 3. Frontend TDD Loop (TypeScript/React)
1. **Red**: Write a failing test (`.test.tsx` or `.test.ts`) in `src/` using modern testing libraries (Vitest/RTL).
2. **Green**: Write the React component/logic to satisfy the test.
3. **Verify**: Run `bun test` via `run_command` and confirm tests pass.

## 4. Full-Auto Browser UI Automation
When a task involves visual changes or requires verifying the actual DOM rendering:
1. **Start Dev Server**: Ensure the Tauri development server is running in the background (e.g., `bun tauri dev` or `bun run dev:renderer`). Use `command_status` to check it.
2. **Launch Browser Subagent**: Call the `browser_subagent` tool. Provide a clear `Task` prompt instructing the subagent to:
   - Navigate to `http://localhost:3000` (or the relevant Vite port).
   - Perform user interactions (click buttons, fill forms).
   - Return visual state, errors observed in the console, or specific DOM elements.
3. **Iterate**: Based on the subagent's report, tweak the CSS/React code and rerun the subagent until the UI requirement is met.

## 5. End-to-End Build Verification
Before concluding major features, verify the native build:
- Run `bun tauri build` to ensure the Rust backend compiles and bundles correctly with the optimized Vite frontend.

// turbo-all
