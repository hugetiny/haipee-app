import path from "node:path";
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./tests/setupGlobals.ts", "./tests/setupTests.ts"],
    globals: true,
    // Note: tests/e2e/**/* (Playwright) and tests/e2e-tauri/**/* (WebdriverIO)
    // are excluded because they use different test runners
    exclude: ["tests/e2e/**/*", "tests/e2e-tauri/**/*", "node_modules"],
    // Memory optimization for 16GB RAM - limit workers to prevent OOM
    maxWorkers: 2,
    coverage: {
      reporter: ["text", "lcov"],
    },
  },
});
