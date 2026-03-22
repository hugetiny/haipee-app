/**
 * API Provider Configuration Summary Test
 */

import { describe, test, expect } from 'vitest';
import { API_PROVIDERS, hasValidToken, getActiveProviders } from './utils';

describe('API Provider Configuration', () => {
  test('generate provider configuration report', () => {
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        total: API_PROVIDERS.length,
        configured: 0,
        missing: 0,
      },
      providers: [] as { name: string; configured: boolean; tokenVar: string; testModel: string }[],
    };

    for (const provider of API_PROVIDERS) {
      const isConfigured = hasValidToken(provider);
      report.providers.push({
        name: provider.name,
        configured: isConfigured,
        tokenVar: provider.tokenEnvVar,
        testModel: provider.testModel,
      });

      if (isConfigured) {
        report.summary.configured++;
      } else {
        report.summary.missing++;
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 API Provider Configuration Report');
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

    expect(report.summary.total).toBeGreaterThan(0);
  });

  test('list active providers', () => {
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

    expect(activeProviders.length).toBeGreaterThanOrEqual(0);
  });
});