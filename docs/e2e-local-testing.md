# Local E2E Testing with act + OrbStack

## Why Local Testing?

GitHub Actions free tier: **2,000 minutes/month**
- Full E2E run: ~67 minutes
- Only ~30 runs/month before hitting limit

Solution: Run GitHub Actions locally with `act` + OrbStack

## Prerequisites

```bash
# Install OrbStack (faster Docker alternative for macOS)
brew install orbstack

# Install act (GitHub Actions local runner)
brew install act

# Verify
orb version
act --version
```

## Quick Start

```bash
# Run E2E tests locally (uses .actrc config)
bun run test:e2e:local

# Or run directly with act
act -W .github/workflows/crabnebula-e2e.yml
```

## Configuration Files

### .actrc (act configuration)
```
-P ubuntu-latest=node:20-bookworm
--container-architecture linux/amd64
--secret-file .secrets.local
-v
```

### .secrets.local (create this file)
```
CN_API_KEY=your_key_here
```

## Performance Comparison

| Environment | Time | Cost |
|-------------|------|------|
| GitHub Actions | 67 min | 2000 min/month limit |
| Local (OrbStack) | 15-20 min | Unlimited |
| Local (native) | 10-15 min | Unlimited |

## Optimizing Test Speed

### 1. Increase Parallelism (wdio.crabnebula.conf.ts)

```typescript
// Change from:
maxInstances: 1,

// To:
maxInstances: process.env.CI ? 4 : 6,  // 4 for CI, 6 for local
```

### 2. Reduce Wait Times

```typescript
// In test files, replace:
await browser.pause(500);

// With shorter waits:
await browser.pause(200);

// Or better, use explicit waits:
await browser.waitUntil(async () => {
  return await element.isDisplayed();
}, { timeout: 2000 });
```

### 3. Run Subset of Tests

```bash
# Run only provider tests
act -W .github/workflows/crabnebula-e2e.yml \
  --env TEST_PATTERN="providers/*.spec.ts"

# Run specific test file
bun run test:e2e -- --spec tests/e2e/crabnebula/providers/provider-crud.spec.ts
```

## OrbStack Benefits

- **3-5x faster** than Docker Desktop
- Native Apple Silicon support
- Lower memory usage
- Seamless Kubernetes integration

## CI/CD Strategy

1. **Local development**: Run full E2E with `act` before pushing
2. **PR checks**: Run subset of critical tests on GitHub Actions
3. **Main branch**: Full E2E suite (use GitHub Actions sparingly)

## Running Optimized Tests

```bash
# Build for E2E (once)
bun run test:e2e:build

# Run locally with 6 parallel instances
MAX_INSTANCES=6 xvfb-run bun run test:e2e

# Or use act for full GitHub Actions simulation
act -W .github/workflows/crabnebula-e2e.yml
```