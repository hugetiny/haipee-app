# E2E Testing Suite for Haipee

This directory contains end-to-end tests for the Haipee Tauri application.

## Architecture

```
tests/e2e/
├── setup/
│   ├── global-setup.ts      # Global setup - validates env vars
│   └── global-teardown.ts   # Global teardown - generates reports
├── pages/
│   └── OpenClawDashboardPage.ts  # Page Object Model for OpenClaw
├── providers/
│   ├── nvidia.spec.ts       # NVIDIA NIM API tests
│   ├── openai.spec.ts       # OpenAI API tests
│   ├── gemini.spec.ts       # Google Gemini API tests
│   ├── opencode.spec.ts     # OpenCode API tests
│   └── kilo.spec.ts         # Kilo Code API tests
├── utils/
│   └── apiProviders.ts      # Provider configurations and utilities
├── summary.spec.ts          # Test summary and report generation
└── README.md                # This file
```

## Prerequisites

1. **Install Playwright browsers:**
   ```bash
   bunx playwright install chromium
   ```

2. **Configure API tokens in `.env`:**
   ```bash
   NVIDIA_TOKEN=your_token_here
   OPENAI_TOKEN=your_token_here
   GEMINI_TOKEN=your_token_here
   OPENCODE_TOKEN=your_token_here
   KILO_TOKEN=your_token_here
   HUAWEI_TOKEN=your_token_here
   CLOUDFLARE_API_TOKEN=your_token_here
   POE_TOKEN=your_token_here
   ```

## Running Tests

### Run all E2E tests:
```bash
bunx playwright test
```

### Run specific provider tests:
```bash
bunx playwright test providers/nvidia.spec.ts
bunx playwright test providers/openai.spec.ts
```

### Run with UI mode (for debugging):
```bash
bunx playwright test --ui
```

### Run in headless mode:
```bash
bunx playwright test --headless
```

### Generate HTML report:
```bash
bunx playwright test --reporter=html
```

## Test Categories

### 1. API Provider Tests
Tests direct API connectivity for each provider:
- Token validation
- Model fetching
- Chat completion
- Error handling

### 2. Summary Report
Generates a comprehensive report of:
- Configured vs missing providers
- Test results summary
- JSON report output

## Limitations

### What these tests CAN do:
- ✅ Test API connectivity directly
- ✅ Validate token configurations
- ✅ Test HTTP endpoints
- ✅ Generate detailed reports

### What these tests CANNOT do (requires Desktop app):
- ❌ Test Tauri-specific features
- ❌ Test native UI interactions
- ❌ Test file system operations
- ❌ Test system tray functionality

## Running Full Desktop E2E Tests

To test the actual Tauri desktop application:

1. Start the Tauri app in dev mode:
   ```bash
   bun run tauri dev
   ```

2. In another terminal, run tests:
   ```bash
   bunx playwright test
   ```

## CI/CD Integration

### GitHub Actions Example:
```yaml
name: E2E Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v1
      - run: bun install
      - run: bunx playwright install chromium
      - run: bunx playwright test
        env:
          NVIDIA_TOKEN: ${{ secrets.NVIDIA_TOKEN }}
          OPENAI_TOKEN: ${{ secrets.OPENAI_TOKEN }}
          # ... other tokens
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

## Troubleshooting

### Tests are skipped
- Check that API tokens are set in `.env`
- Verify tokens are valid and not expired
- Check network connectivity

### Timeouts
- Increase timeout in `playwright.config.ts`
- Some APIs may be slow in certain regions

### Screenshots/Videos
- Check `playwright-report/` directory after test run
- Artifacts are automatically captured on failure
