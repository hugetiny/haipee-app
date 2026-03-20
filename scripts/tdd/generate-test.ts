#!/usr/bin/env bun
/**
 * Test Generator Script
 * Usage: bun run gen:test <ComponentName>
 *
 * Creates a test file with Vitest and React Testing Library template.
 */

import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

const componentName = process.argv[2];

if (!componentName) {
  console.error('Usage: bun run gen:test <ComponentName>');
  console.error('');
  console.error('Options:');
  console.error('  --hook     Generate hook test (tests/hooks/)');
  console.error('  --util     Generate utility test (tests/utils/)');
  console.error('');
  console.error('Examples:');
  console.error('  bun run gen:test MyComponent');
  console.error('  bun run gen:test useMyHook --hook');
  console.error('  bun run gen:test myUtils --util');
  process.exit(1);
}

// Parse flags
const isHook = process.argv.includes('--hook');
const isUtil = process.argv.includes('--util');

// Determine test directory based on type
let testDir: string;
let importPath: string;

if (isHook) {
  testDir = join(process.cwd(), 'tests', 'hooks');
  importPath = `@/hooks/${componentName}`;
} else if (isUtil) {
  testDir = join(process.cwd(), 'tests', 'utils');
  importPath = `@/utils/${componentName}`;
} else {
  testDir = join(process.cwd(), 'tests', 'components');
  importPath = `@/components/${componentName}`;
}

const testFile = join(testDir, `${componentName}.test.ts`);

if (existsSync(testFile)) {
  console.error(`Test file already exists: ${testFile}`);
  process.exit(1);
}

// Generate template based on type
let template: string;

if (isHook) {
  template = `import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { ${componentName} } from '${importPath}';

describe('${componentName}', () => {
  beforeEach(() => {
    // Setup before each test
  });

  afterEach(() => {
    // Cleanup after each test
    vi.clearAllMocks();
  });

  it('should initialize correctly', () => {
    const { result } = renderHook(() => ${componentName}());

    // Add assertions here
    expect(result.current).toBeDefined();
  });

  it('should handle state changes', () => {
    const { result } = renderHook(() => ${componentName}());

    act(() => {
      // Trigger state changes
    });

    // Add assertions here
  });
});
`;
} else if (isUtil) {
  template = `import { describe, it, expect, vi } from 'vitest';
import { ${componentName} } from '${importPath}';

describe('${componentName}', () => {
  it('should work correctly', () => {
    // Test implementation
    const result = ${componentName}();
    expect(result).toBeDefined();
  });

  it('should handle edge cases', () => {
    // Test edge cases
  });

  it('should handle errors gracefully', () => {
    // Test error handling
  });
});
`;
} else {
  // Component test template
  template = `import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ${componentName} } from '${importPath}';

describe('${componentName}', () => {
  beforeEach(() => {
    // Setup before each test
  });

  afterEach(() => {
    // Cleanup after each test
    vi.clearAllMocks();
  });

  it('should render correctly', () => {
    render(<${componentName} />);

    // Add assertions here
    // Example: expect(screen.getByText('Hello')).toBeInTheDocument();
  });

  it('should handle click events', async () => {
    const onClick = vi.fn();
    const user = userEvent.setup();

    render(<${componentName} onClick={onClick} />);

    // Find and click element
    // const button = screen.getByRole('button');
    // await user.click(button);
    // expect(onClick).toHaveBeenCalledOnce();
  });

  it('should handle props correctly', () => {
    const props = {
      // Add test props here
    };

    render(<${componentName} {...props} />);

    // Add assertions here
  });

  it('should be accessible', () => {
    render(<${componentName} />);

    // Check accessibility
    // Example: expect(screen.getByRole('button')).toHaveAttribute('aria-label');
  });
});
`;
}

mkdirSync(testDir, { recursive: true });
writeFileSync(testFile, template);

console.log(`Created test file: ${testFile}`);
console.log('');
console.log('Remember to:');
console.log('1. Import the component/hook/util from the correct path');
console.log('2. Implement meaningful test cases');
console.log('3. Run: bun run test:unit');