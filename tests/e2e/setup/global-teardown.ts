import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';

/**
 * Global teardown for E2E tests
 * - Generates test report
 * - Cleans up resources
 */
async function globalTeardown() {
  console.log('\n🧹 E2E Test Global Teardown');

  const testRunId = process.env.TEST_RUN_ID || 'unknown';
  const startTime = new Date(process.env.TEST_START_TIME || Date.now());
  const endTime = new Date();
  const duration = endTime.getTime() - startTime.getTime();

  // Generate summary report
  const report = {
    testRunId,
    startTime: startTime.toISOString(),
    endTime: endTime.toISOString(),
    duration: `${(duration / 1000).toFixed(2)}s`,
    environment: {
      nodeVersion: process.version,
      platform: process.platform,
      ci: !!process.env.CI,
    },
    apiTokens: {
      nvidia: !!process.env.NVIDIA_TOKEN,
      openai: !!process.env.OPENAI_TOKEN,
      gemini: !!process.env.GEMINI_TOKEN,
      opencode: !!process.env.OPENCODE_TOKEN,
      kilo: !!process.env.KILO_TOKEN,
      huawei: !!process.env.HUAWEI_TOKEN,
      cloudflare: !!process.env.CLOUDFLARE_API_TOKEN,
      poe: !!process.env.POE_TOKEN,
    },
  };

  // Ensure report directory exists
  const reportDir = join(process.cwd(), 'playwright-report');
  if (!existsSync(reportDir)) {
    mkdirSync(reportDir, { recursive: true });
  }

  // Write summary report
  const reportPath = join(reportDir, 'test-summary.json');
  writeFileSync(reportPath, JSON.stringify(report, null, 2));

  console.log(`📊 Test summary saved to: ${reportPath}`);
  console.log(`⏱️  Total duration: ${report.duration}`);
  console.log('✅ Global teardown complete\n');
}

export default globalTeardown;
