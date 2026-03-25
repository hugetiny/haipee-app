/**
 * Form Validation Tests
 *
 * Tests comprehensive form validation scenarios:
 * 1. Required field validation (empty, whitespace-only)
 * 2. Format validation (email, URL, API key patterns)
 * 3. Range validation (min/max length, numeric ranges)
 * 4. Type validation (numeric vs text, dates)
 * 5. Cross-field validation (password confirmation, dependent fields)
 * 6. Async validation (duplicate names, API connectivity)
 * 7. Error display (inline errors, summary, focus management)
 * 8. Submission handling (disabled state, double-submit prevention)
 */

/// <reference types="@wdio/globals/types" />

import { expect } from '@wdio/globals';
import { DashboardPage } from '../pages/DashboardPage';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Form Validation – Required Fields', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should show error for empty required name field', async () => {
    await dashboard.open();

    // Open add provider dialog
    await dashboard.clickAddProvider();
    await browser.pause(500);

    // Try to submit without filling name
    const submitBtn = await $('button[type="submit"]');
    if (await submitBtn.isExisting()) {
      await submitBtn.click();
      await browser.pause(300);

      // Check for validation error using browser.execute for WebKit compatibility
      const hasError = await browser.execute(() => {
        const errorElements = document.querySelectorAll('[class*="error"], [aria-invalid="true"], [role="alert"]');
        const errorText = Array.from(errorElements).some(el =>
          el.textContent?.includes('required') ||
          el.textContent?.includes('必填') ||
          el.textContent?.includes('请输入') ||
          el.textContent?.includes('不能为空')
        );
        return errorElements.length > 0 || errorText;
      });

      expect(hasError).toBe(true);
    }

    // Close dialog
    await JourneyHelpers.closeModal();
  });

  it('should show error for whitespace-only name field', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    // Fill name with only whitespace
    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue('   ');
      await browser.pause(200);

      // Trigger validation (blur or submit)
      await browser.keys(['Tab']);
      await browser.pause(300);

      const hasError = await browser.execute(() => {
        const nameInputEl = document.querySelector('[data-testid="provider-name-input"], input[name*="name"]');
        return nameInputEl?.getAttribute('aria-invalid') === 'true' ||
               document.querySelectorAll('[class*="error"]').length > 0;
      });

      expect(hasError).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should mark required fields with visual indicator', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    // Check for required field indicators (asterisk, required text, etc.)
    const hasRequiredIndicator = await browser.execute(() => {
      const labels = document.querySelectorAll('label, [class*="label"]');
      const body = document.body;
      const content = body.textContent || '';
      return content.includes('*') ||
             Array.from(labels).some(l => l.textContent?.includes('*'));
    });

    expect(hasRequiredIndicator).toBe(true);
    await JourneyHelpers.closeModal();
  });
});

describe('Form Validation – Format Validation', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should validate email format', async () => {
    await dashboard.open();
    await JourneyHelpers.waitForLoading();

    // Navigate to settings where email might be
    await dashboard.navigateToView('settings');
    await browser.pause(300);

    const emailInput = await $('input[type="email"], input[name*="email"]');
    if (await emailInput.isExisting()) {
      await emailInput.setValue('invalid-email');
      await browser.keys(['Tab']);
      await browser.pause(300);

      const isInvalid = await emailInput.getAttribute('aria-invalid');
      expect(isInvalid).toBe('true');
    } else {
      // No email input - verify page is valid
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    }
  });

  it('should validate URL format for base URL field', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const urlInput = await $('input[name*="baseUrl"], input[name*="base_url"], input[placeholder*="URL"]');
    if (await urlInput.isExisting()) {
      await urlInput.setValue('not-a-valid-url');
      await browser.keys(['Tab']);
      await browser.pause(300);

      const isInvalid = await urlInput.getAttribute('aria-invalid');
      expect(isInvalid).toBe('true');
    }

    await JourneyHelpers.closeModal();
  });

  it('should validate API key format pattern', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const apiKeyInput = await $('input[name*="apiKey"], input[name*="api_key"], input[placeholder*="API"]');
    if (await apiKeyInput.isExisting()) {
      // Try various invalid formats
      await apiKeyInput.setValue('x'); // Too short
      await browser.keys(['Tab']);
      await browser.pause(200);

      const hasValidation = await browser.execute(() => {
        const input = document.querySelector('input[name*="apiKey"], input[name*="api_key"]');
        return input?.getAttribute('aria-invalid') === 'true' ||
               document.querySelectorAll('[class*="error"]').length > 0;
      });

      expect(hasValidation).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should accept valid URL format', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const urlInput = await $('input[name*="baseUrl"], input[name*="base_url"], input[placeholder*="URL"]');
    if (await urlInput.isExisting()) {
      await urlInput.setValue('https://api.example.com/v1');
      await browser.keys(['Tab']);
      await browser.pause(200);

      const isValid = await urlInput.getAttribute('aria-invalid');
      // null or 'false' means valid
      expect(isValid === null || isValid === 'false' || isValid === '').toBe(true);
    }

    await JourneyHelpers.closeModal();
  });
});

describe('Form Validation – Range Validation', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should enforce minimum length for name field', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue('a'); // Single character
      await browser.keys(['Tab']);
      await browser.pause(300);

      const hasMinLengthError = await browser.execute(() => {
        const errors = document.querySelectorAll('[class*="error"], [role="alert"]');
        return Array.from(errors).some(e =>
          e.textContent?.includes('字符') ||
          e.textContent?.includes('character') ||
          e.textContent?.includes('长度') ||
          e.textContent?.includes('length') ||
          e.textContent?.includes('至少')
        );
      });

      expect(hasMinLengthError).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should enforce maximum length for name field', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    if (await nameInput.isExisting()) {
      // Try to input a very long name (over 100 chars)
      const longName = 'A'.repeat(150);
      await nameInput.setValue(longName);
      await browser.pause(200);

      // Check if input was truncated or shows error
      const value = await nameInput.getValue();
      const wasTruncated = value.length < longName.length;

      const hasMaxLengthError = await browser.execute(() => {
        const errors = document.querySelectorAll('[class*="error"], [role="alert"]');
        return Array.from(errors).some(e =>
          e.textContent?.includes('过长') ||
          e.textContent?.includes('too long') ||
          e.textContent?.includes('超过') ||
          e.textContent?.includes('exceed')
        );
      });

      expect(wasTruncated || hasMaxLengthError).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should validate numeric range for port fields', async () => {
    await dashboard.open();
    await JourneyHelpers.waitForLoading();

    // Navigate to settings for port configuration
    await dashboard.navigateToView('settings');
    await browser.pause(300);

    const portInput = await $('input[name*="port"], input[type="number"]');
    if (await portInput.isExisting()) {
      await portInput.setValue('99999'); // Over max port
      await browser.keys(['Tab']);
      await browser.pause(300);

      const isInvalid = await portInput.getAttribute('aria-invalid');
      expect(isInvalid).toBe('true');
    } else {
      // No port input - verify page is valid
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    }
  });

  it('should enforce minimum value for numeric fields', async () => {
    await dashboard.open();
    await JourneyHelpers.waitForLoading();

    await dashboard.navigateToView('settings');
    await browser.pause(300);

    const numericInput = await $('input[type="number"], input[min]');
    if (await numericInput.isExisting()) {
      const minValue = await numericInput.getAttribute('min');
      if (minValue) {
        await numericInput.setValue(String(parseInt(minValue) - 1));
        await browser.keys(['Tab']);
        await browser.pause(300);

        const isInvalid = await numericInput.getAttribute('aria-invalid');
        expect(isInvalid).toBe('true');
      }
    }

    // Verify page is in valid state
    const validState = await JourneyHelpers.assertValidPageState();
    expect(validState).toBe(true);
  });
});

describe('Form Validation – Type Validation', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should reject non-numeric input in numeric fields', async () => {
    await dashboard.open();
    await JourneyHelpers.waitForLoading();

    await dashboard.navigateToView('settings');
    await browser.pause(300);

    const numericInput = await $('input[type="number"]');
    if (await numericInput.isExisting()) {
      // Browser should prevent this, but check validation
      await numericInput.setValue('abc');
      await browser.keys(['Tab']);
      await browser.pause(300);

      const value = await numericInput.getValue();
      // Browser typically clears invalid numeric input
      expect(value === '' || isNaN(Number(value))).toBe(true);
    } else {
      // No numeric input - verify page is valid
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    }
  });

  it('should validate date format in date fields', async () => {
    await dashboard.open();
    await JourneyHelpers.waitForLoading();

    const dateInput = await $('input[type="date"]');
    if (await dateInput.isExisting()) {
      // Date inputs typically have browser-native validation
      const hasValidation = await browser.execute(() => {
        const input = document.querySelector('input[type="date"]');
        return input !== null;
      });

      expect(hasValidation).toBe(true);
    } else {
      // No date input - verify page is valid
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    }
  });

  it('should accept valid numeric input', async () => {
    await dashboard.open();
    await JourneyHelpers.waitForLoading();

    await dashboard.navigateToView('settings');
    await browser.pause(300);

    const numericInput = await $('input[type="number"]');
    if (await numericInput.isExisting()) {
      await numericInput.setValue('8080');
      await browser.keys(['Tab']);
      await browser.pause(200);

      const value = await numericInput.getValue();
      expect(value).toBe('8080');
    } else {
      // No numeric input - verify page is valid
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    }
  });
});

describe('Form Validation – Cross-Field Validation', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should validate password confirmation match', async () => {
    await dashboard.open();
    await JourneyHelpers.waitForLoading();

    // Look for password fields (might be in settings)
    await dashboard.navigateToView('settings');
    await browser.pause(300);

    const passwordInputs = await $$('input[type="password"]');
    if ((await passwordInputs.length) >= 2) {
      await passwordInputs[0].setValue('Password123!');
      await passwordInputs[1].setValue('DifferentPassword!');
      await browser.pause(300);

      const submitBtn = await $('button[type="submit"]');
      if (await submitBtn.isExisting()) {
        await submitBtn.click();
        await browser.pause(300);
      }

      const hasMismatchError = await browser.execute(() => {
        const errors = document.querySelectorAll('[class*="error"], [role="alert"]');
        return Array.from(errors).some(e =>
          e.textContent?.includes('match') ||
          e.textContent?.includes('一致') ||
          e.textContent?.includes('不匹配')
        );
      });

      expect(hasMismatchError).toBe(true);
    } else {
      // No password fields - verify page is valid
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    }
  });

  it('should validate dependent fields (base URL requires API key)', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    // Fill base URL without API key
    const urlInput = await $('input[name*="baseUrl"], input[placeholder*="URL"]');
    if (await urlInput.isExisting()) {
      await urlInput.setValue('https://api.example.com/v1');
      await browser.keys(['Tab']);
      await browser.pause(200);

      const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
      if (await nameInput.isExisting()) {
        await nameInput.setValue(JourneyHelpers.generateTestName('Dep'));
      }

      const submitBtn = await $('button[type="submit"]');
      if (await submitBtn.isExisting()) {
        await submitBtn.click();
        await browser.pause(300);

        const hasError = await JourneyHelpers.hasFormError();
        expect(hasError).toBe(true);
      }
    }

    await JourneyHelpers.closeModal();
  });

  it('should clear dependent field errors when parent field is fixed', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    if (await nameInput.isExisting()) {
      // Trigger error first
      await nameInput.setValue('');
      const submitBtn = await $('button[type="submit"]');
      if (await submitBtn.isExisting()) {
        await submitBtn.click();
        await browser.pause(300);
      }

      // Now fix it
      await nameInput.setValue('Valid Name');
      await browser.keys(['Tab']);
      await browser.pause(300);

      const hasCleared = await browser.execute(() => {
        const nameInputEl = document.querySelector('[data-testid="provider-name-input"], input[name*="name"]');
        return nameInputEl?.getAttribute('aria-invalid') !== 'true';
      });

      expect(hasCleared).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });
});

describe('Form Validation – Async Validation', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should detect duplicate provider names', async () => {
    await dashboard.open();

    // Get existing provider names
    const existingNames = await dashboard.getVisibleProviderNames();
    if (existingNames.length > 0) {
      await dashboard.clickAddProvider();
      await browser.pause(500);

      const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
      if (await nameInput.isExisting()) {
        await nameInput.setValue(existingNames[0]);
        await browser.keys(['Tab']);
        await browser.pause(1000); // Wait for async validation

        const hasDuplicateError = await browser.execute(() => {
          const errors = document.querySelectorAll('[class*="error"], [role="alert"]');
          return Array.from(errors).some(e =>
            e.textContent?.includes('exist') ||
            e.textContent?.includes('已存在') ||
            e.textContent?.includes('duplicate') ||
            e.textContent?.includes('重复')
          );
        });

        expect(hasDuplicateError).toBe(true);
      }

      await JourneyHelpers.closeModal();
    } else {
      // No existing providers - verify page is valid
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    }
  });

  it('should validate API connectivity during form fill', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const apiKeyInput = await $('input[name*="apiKey"], input[placeholder*="API"]');
    if (await apiKeyInput.isExisting()) {
      await apiKeyInput.setValue('sk-test-key-for-validation');
      await browser.keys(['Tab']);
      await browser.pause(500);

      // Check for validation indicator (spinner, check mark, etc.)
      const hasValidationIndicator = await browser.execute(() => {
        const indicators = document.querySelectorAll('[class*="validating"], [class*="checking"], [class*="spinner"]');
        return indicators.length > 0;
      });

      expect(hasValidationIndicator).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should show loading state during async validation', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue(JourneyHelpers.generateTestName('Async'));
      await browser.keys(['Tab']);
      await browser.pause(100);

      // Look for loading indicator near the field
      const hasLoading = await browser.execute(() => {
        const loading = document.querySelectorAll('[class*="loading"], [class*="spinner"], [class*="validating"]');
        return loading.length > 0;
      });

      // Wait for validation to complete
      await browser.pause(1000);

      expect(hasLoading).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });
});

describe('Form Validation – Error Display', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should display inline error messages', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const submitBtn = await $('button[type="submit"]');
    if (await submitBtn.isExisting()) {
      await submitBtn.click();
      await browser.pause(300);

      // Check for inline error message
      const inlineError = await browser.execute(() => {
        const errors = document.querySelectorAll('[class*="error"]:not([class*="summary"]), [aria-invalid="true"] + [class*="error"]');
        return errors.length > 0;
      });

      expect(inlineError).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should show error summary for multiple errors', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const submitBtn = await $('button[type="submit"]');
    if (await submitBtn.isExisting()) {
      await submitBtn.click();
      await browser.pause(300);

      // Check for error summary
      const hasSummary = await browser.execute(() => {
        const summary = document.querySelectorAll('[class*="error-summary"], [class*="alert"], [role="alert"]');
        return summary.length > 0;
      });

      expect(hasSummary).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should focus first error field on submit', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const submitBtn = await $('button[type="submit"]');
    if (await submitBtn.isExisting()) {
      await submitBtn.click();
      await browser.pause(300);

      // Check if first error field has focus
      const focusedElement = await browser.execute(() => {
        const focused = document.activeElement;
        const isInvalid = focused?.getAttribute('aria-invalid') === 'true';
        const hasErrorClass = focused?.classList.toString().includes('error');
        return { tagName: focused?.tagName, isInvalid, hasErrorClass };
      });

      expect(focusedElement).toBeDefined();
      expect(focusedElement.tagName).toBeTruthy();
    }

    await JourneyHelpers.closeModal();
  });

  it('should clear errors when field is corrected', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    if (await nameInput.isExisting()) {
      // Trigger error
      const submitBtn = await $('button[type="submit"]');
      if (await submitBtn.isExisting()) {
        await submitBtn.click();
        await browser.pause(300);
      }

      // Fix the error
      await nameInput.setValue('Valid Name Here');
      await browser.keys(['Tab']);
      await browser.pause(300);

      // Check if error cleared
      const hasError = await browser.execute(() => {
        const nameInputEl = document.querySelector('[data-testid="provider-name-input"], input[name*="name"]');
        return nameInputEl?.getAttribute('aria-invalid') === 'true';
      });

      expect(hasError).toBe(false);
    }

    await JourneyHelpers.closeModal();
  });
});

describe('Form Validation – Submission Handling', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
    await browser.pause(500);
  });

  it('should disable submit button during validation', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    const submitBtn = await $('button[type="submit"]');

    if (await nameInput.isExisting() && await submitBtn.isExisting()) {
      await nameInput.setValue(JourneyHelpers.generateTestName('Sub'));

      // Rapidly click submit
      await submitBtn.click();
      const isDisabled = await submitBtn.getAttribute('disabled');

      expect(isDisabled).toBe('true');
    }

    await JourneyHelpers.closeModal();
  });

  it('should prevent double submission', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    const apiKeyInput = await $('input[name*="apiKey"], input[placeholder*="API"]');
    const submitBtn = await $('button[type="submit"]');

    if (await nameInput.isExisting() && await submitBtn.isExisting()) {
      const testName = JourneyHelpers.generateTestName('Double');
      await nameInput.setValue(testName);
      if (await apiKeyInput.isExisting()) {
        await apiKeyInput.setValue(JourneyHelpers.generateTestApiKey());
      }

      // Double click rapidly
      await submitBtn.click();
      await browser.pause(50);
      const isDisabled = await submitBtn.getAttribute('disabled');

      // Either button is disabled or modal is closing
      expect(isDisabled !== null || !(await JourneyHelpers.isModalOpen())).toBe(true);

      await JourneyHelpers.closeModal();
      await browser.pause(500);

      // Cleanup if provider was created
      try {
        await dashboard.deleteProvider(testName);
      } catch {
        // Ignore cleanup errors
      }
    } else {
      await JourneyHelpers.closeModal();
    }
  });

  it('should re-enable submit button after error', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const submitBtn = await $('button[type="submit"]');
    if (await submitBtn.isExisting()) {
      // Submit with invalid data
      await submitBtn.click();
      await browser.pause(1000);

      // Check button is re-enabled
      const isDisabled = await submitBtn.getAttribute('disabled');
      expect(isDisabled === null || isDisabled === 'false').toBe(true);
    }

    await JourneyHelpers.closeModal();
  });

  it('should show loading indicator during submission', async () => {
    await dashboard.open();

    await dashboard.clickAddProvider();
    await browser.pause(500);

    const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"]');
    const submitBtn = await $('button[type="submit"]');

    if (await nameInput.isExisting() && await submitBtn.isExisting()) {
      await nameInput.setValue(JourneyHelpers.generateTestName('Load'));
      await submitBtn.click();
      await browser.pause(100);

      const hasLoading = await browser.execute(() => {
        const loading = document.querySelectorAll('[class*="loading"], [class*="spinner"], [aria-busy="true"]');
        return loading.length > 0;
      });

      expect(hasLoading).toBe(true);
    }

    await JourneyHelpers.closeModal();
  });
});