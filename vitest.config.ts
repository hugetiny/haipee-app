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
    exclude: ["tests/e2e/**/*", "node_modules"],
    poolOptions: {
      forks: {
        maxWorkers: 2,
      },
    },
    coverage: {
      reporter: ["text", "lcov"],
    },
  },
});
