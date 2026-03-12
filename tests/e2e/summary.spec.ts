import { test, expect } from '@playwright/test';
import { API_PROVIDERS, hasValidToken, getActiveProviders } from './utils/apiProviders';

/**
 * E2E Test Summary Report
 * Generates a comprehensive report of all provider configurations
 */
test.describe('E2E Test Summary', () => {
  test('generate provider configuration report', async () => {
    const report = {
      timestamp: new Date().toISOString(),
      environment: {
        nodeVersion: process.version,
        platform: process.platform,
      },
      summary: {
        total: API_PROVIDERS.length,
        configured: 0,
        missing: 0,
      },
      providers: [] as any[],
    };

    for (const provider of API_PROVIDERS) {
      const isConfigured = hasValidToken(provider);
      const providerReport = {
        name: provider.name,
        configured: isConfigured,
        tokenVar: provider.tokenEnvVar,
        testModel: provider.testModel,
      };

      report.providers.push(providerReport);

      if (isConfigured) {
        report.summary.configured++;
      } else {
        report.summary.missing++;
      }
    }

    // Output report
    console.log('\n' + '='.repeat(60));
    console.log('📊 E2E API Provider Configuration Report');
    console.log('='.repeat(60));
    console.log(`\nTotal Providers: ${report.summary.total}`);
    console.log(`✅ Configured: ${report.summary.configured}`);
    console.log(`❌ Missing: ${report.summary.missing}`);
    console.log('\nProvider Details:');

    for (const p of report.providers) {
      const status = p.configured ? '✅' : '❌';
      console.log(`  ${status} ${p.name} (${p.tokenVar})`);
    }

    console.log('\n' + '='.repeat(60));

    // Save report to file
    const fs = await import('fs');
    const path = await import('path');

    const reportDir = path.join(process.cwd(), 'playwright-report');
    if (!fs.existsSync(reportDir)) {
      fs.mkdirSync(reportDir, { recursive: true });
    }

    fs.writeFileSync(
      path.join(reportDir, 'provider-report.json'),
      JSON.stringify(report, null, 2)
    );

    console.log(`📄 Report saved to: ${path.join(reportDir, 'provider-report.json')}`);

    // Assertions
    expect(report.summary.total).toBeGreaterThan(0);
  });

  test('list active providers', async () => {
    const activeProviders = getActiveProviders();

    console.log('\n' + '='.repeat(60));
    console.log('🚀 Active Providers (Ready for Testing)');
    console.log('='.repeat(60));

    if (activeProviders.length === 0) {
      console.log('⚠️  No providers are configured!');
      console.log('Set the following environment variables in .env:');
      for (const p of API_PROVIDERS) {
        console.log(`  - ${p.tokenEnvVar}`);
      }
    } else {
      for (const p of activeProviders) {
        console.log(`  ✅ ${p.name} (Model: ${p.testModel})`);
      }
    }

    console.log('='.repeat(60) + '\n');

    // We don't fail if no providers are configured
    // This allows the test suite to run in CI without secrets
    expect(activeProviders.length).toBeGreaterThanOrEqual(0);
  });
});
