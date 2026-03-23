/**
 * Type declarations for CrabNebula E2E tests
 */

/// <reference types="@wdio/globals/types" />

declare global {
  namespace NodeJS {
    interface Global {
      browser: WebdriverIO.Browser;
    }
  }
}

export {};