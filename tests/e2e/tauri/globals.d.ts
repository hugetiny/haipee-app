/**
 * Global type declarations for WebdriverIO/Mocha E2E tests
 */

declare function before(fn: Mocha.AsyncFunc): void;
declare function before(name: string, fn: Mocha.AsyncFunc): void;
declare function after(fn: Mocha.AsyncFunc): void;
declare function after(name: string, fn: Mocha.AsyncFunc): void;
declare function beforeEach(fn: Mocha.AsyncFunc): void;
declare function beforeEach(name: string, fn: Mocha.AsyncFunc): void;
declare function afterEach(fn: Mocha.AsyncFunc): void;
declare function afterEach(name: string, fn: Mocha.AsyncFunc): void;

declare namespace Mocha {
  type AsyncFunc = (this: Context) => Promise<void>;
  interface Context {
    currentTest?: {
      title: string;
      fullTitle(): string;
      state: 'passed' | 'failed' | 'pending';
    };
  }
}
