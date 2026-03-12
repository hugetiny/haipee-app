// import { exec } from 'child_process';
// import { promisify } from 'util';

// const execAsync = promisify(exec);

/**
 * Global setup for E2E tests
 * - Validates environment variables
 * - Checks API tokens are available
 */
async function globalSetup() {
  console.log('🔧 E2E Test Global Setup');

  // Validate required environment variables
  const requiredTokens = [
    'NVIDIA_TOKEN',
    'OPENAI_TOKEN',
    'GEMINI_TOKEN',
    'OPENCODE_TOKEN',
    'KILO_TOKEN',
  ];

  const missingTokens = requiredTokens.filter(token => !process.env[token]);

  if (missingTokens.length > 0) {
    console.warn('⚠️  Missing API tokens (tests will be skipped):', missingTokens.join(', '));
  } else {
    console.log('✅ All required API tokens found');
  }

  // Set test run metadata
  process.env.TEST_RUN_ID = `run-${Date.now()}`;
  process.env.TEST_START_TIME = new Date().toISOString();

  console.log(`📝 Test Run ID: ${process.env.TEST_RUN_ID}`);
  console.log('✅ Global setup complete\n');
}

export default globalSetup;
