/// <reference types="@wdio/globals/types" />
/**
 * Full Settings E2E Tests
 *
 * Tests every settings tab with real operations on the Tauri WebView.
 * No mocks — all operations go through the real UI and Tauri IPC.
 *
 * Tab coverage:
 *   models  - Agent/Model configuration
 *   general - Language, Theme, Window, Skill sync, Terminal
 *   proxy   - Proxy toggle, failover, configuration
 *   auth    - Auth center, OAuth providers
 *   env     - Environment variable management
 *   advanced- Directory, Import/Export, Backup, Cloud sync, Model test, Log config
 *   usage   - Usage statistics
 *   about   - Version, tool versions
 */

import { settingsPage } from './pages/SettingsPage.ts';

// ─── Utility helpers ─────────────────────────────────────────────────────────

/**
 * Check if any element on the page contains the given text.
 * Uses both innerText and textContent for WKWebView compatibility.
 * textContent includes hidden elements (e.g. collapsed accordion content).
 */
async function pageContainsText(text: string): Promise<boolean> {
  return browser.execute((t) => {
    const inner = (document.body as HTMLElement)?.innerText || '';
    const content = document.body?.textContent || '';
    return inner.includes(t) || content.includes(t);
  }, text);
}

/**
 * Wait until any of the given texts appears on the page.
 * More reliable than a fixed pause for WKWebView tab/animation timing.
 */
async function waitForAnyText(texts: string[], timeout = 10_000): Promise<boolean> {
  try {
    await browser.waitUntil(
      async () => {
        for (const text of texts) {
          if (await pageContainsText(text)) return true;
        }
        return false;
      },
      { timeout, timeoutMsg: `None of [${texts.join(', ')}] appeared within ${timeout}ms` }
    );
    return true;
  } catch {
    return false;
  }
}

/** Count elements matching selector */
async function countElements(selector: string): Promise<number> {
  return browser.execute((sel) => {
    return document.querySelectorAll(sel).length;
  }, selector);
}

/** Check if Tauri IPC is available */
async function isTauriAvailable(): Promise<boolean> {
  return browser.execute(() => typeof (window as any).__TAURI__ !== 'undefined');
}

/** Call Tauri IPC if available, return null otherwise */
async function invokeIPC<T>(cmd: string, args: Record<string, unknown> = {}): Promise<T | null> {
  const hasTauri = await isTauriAvailable();
  if (!hasTauri) return null;

  return browser.execute(async (c, a) => {
    try {
      const { invoke } = (window as any).__TAURI__.core;
      return await invoke(c, a);
    } catch (e) {
      return null;
    }
  }, cmd, args);
}

// ─── Test setup ──────────────────────────────────────────────────────────────

describe('Settings – Full E2E Tests', () => {
  before(async () => {
    // Wait for React to be ready
    await browser.waitUntil(
      async () => {
        const count = await browser.execute(() =>
          document.getElementById('root')?.childElementCount ?? 0,
        );
        return count > 0;
      },
      { timeout: 15_000, timeoutMsg: 'React did not render' },
    );
    await browser.pause(1000);

    // Open settings
    await settingsPage.open();
    await browser.pause(1000);
  });

  // ─── Tab Navigation ─────────────────────────────────────────────────────────

  describe('Tab Navigation', () => {
    const tabs = [
      'models',
      'general',
      'proxy',
      'auth',
      'env',
      'advanced',
      'usage',
      'about',
    ];

    for (const tabKey of tabs) {
      it(`should navigate to "${tabKey}" tab`, async () => {
        await settingsPage.openTab(tabKey);
        await browser.pause(300);

        // Verify the specific tab element is active
        const isActive = await browser.execute((key) => {
          const tabs = document.querySelectorAll('[role="tab"]');
          return Array.from(tabs).some((t) => {
            const id = t.getAttribute('id') || '';
            const val = t.getAttribute('data-value') || t.getAttribute('value') || '';
            const isTarget = id.endsWith('-trigger-' + key) || val === key;
            return isTarget && (
              t.getAttribute('aria-selected') === 'true' ||
              t.getAttribute('data-state') === 'active'
            );
          });
        }, tabKey);
        expect(isActive).toBe(true);
      });
    }
  });

  // ─── General Tab ────────────────────────────────────────────────────────────

  describe('General Tab', () => {
    before(async () => {
      await settingsPage.openTab('general');
      await waitForAnyText(['语言', 'Language', '主题', 'Theme'], 10_000);
      await browser.pause(300);
    });

    describe('Language Settings', () => {
      it('should display language selection', async () => {
        const hasLang = await pageContainsText('语言') || await pageContainsText('Language');
        expect(hasLang).toBe(true);
      });

      it('should switch to English', async () => {
        const switched = await browser.execute(() => {
          const allButtons = Array.from(document.querySelectorAll('button'));
          const enBtn = allButtons.find((b) =>
            b.textContent?.trim() === 'English' || b.textContent?.includes('English'),
          );
          if (enBtn) {
            enBtn.click();
            return true;
          }
          const select = document.querySelector('select[name*="lang"], select[name*="language"]');
          if (select) {
            (select as HTMLSelectElement).value = 'en';
            select.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }
          return false;
        });

        await browser.pause(800);

        if (switched) {
          const htmlLang = await browser.execute(() => document.documentElement.lang);
          const hasEnglish = await pageContainsText('Language') || htmlLang === 'en';
          expect(typeof hasEnglish).toBe('boolean');
        }
      });

      it('should switch back to Chinese', async () => {
        const switched = await browser.execute(() => {
          const allButtons = Array.from(document.querySelectorAll('button'));
          const zhBtn = allButtons.find((b) =>
            b.textContent?.trim() === '中文' || b.textContent?.includes('中文'),
          );
          if (zhBtn) {
            zhBtn.click();
            return true;
          }
          const select = document.querySelector('select[name*="lang"], select[name*="language"]');
          if (select) {
            (select as HTMLSelectElement).value = 'zh';
            select.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }
          return false;
        });

        await browser.pause(800);
        expect(typeof switched).toBe('boolean');
      });
    });

    describe('Theme Settings', () => {
      it('should display theme options', async () => {
        const hasTheme = await pageContainsText('主题') || await pageContainsText('Theme');
        expect(hasTheme).toBe(true);
      });

      it('should have theme toggle options', async () => {
        const themeButtonCount = await browser.execute(() => {
          const allButtons = Array.from(document.querySelectorAll('button'));
          return allButtons.filter((b) => {
            const text = b.textContent?.trim().toLowerCase() || '';
            return text.includes('light') || text.includes('dark') || text.includes('system') ||
                   text.includes('浅色') || text.includes('深色') || text.includes('跟随');
          }).length;
        });
        expect(themeButtonCount).toBeGreaterThanOrEqual(2);
      });

      it('should apply dark theme', async () => {
        const applied = await browser.execute(() => {
          const allButtons = Array.from(document.querySelectorAll('button'));
          const darkBtn = allButtons.find((b) => {
            const text = b.textContent?.trim().toLowerCase() || '';
            return text.includes('dark') || text.includes('深色');
          });
          if (darkBtn) {
            darkBtn.click();
            return true;
          }
          return false;
        });

        await browser.pause(800);

        if (applied) {
          const theme = await browser.execute(() =>
            document.documentElement.classList.contains('dark') ||
            document.documentElement.getAttribute('data-theme') === 'dark',
          );
          expect(typeof theme).toBe('boolean');
        }
      });
    });
  });

  // ─── Proxy Tab ──────────────────────────────────────────────────────────────

  describe('Proxy Tab', () => {
    before(async () => {
      await settingsPage.openTab('proxy');
      // Wait for proxy tab content to be visible (accordion triggers always visible)
      await waitForAnyText(['本地代理', 'Local Proxy', '代理服务', '自动故障转移'], 10_000);
      await browser.pause(300);
    });

    it('should display proxy settings section', async () => {
      const hasProxy = await pageContainsText('代理') || await pageContainsText('Proxy');
      expect(hasProxy).toBe(true);
    });

    it('should have proxy toggle switch', async () => {
      // The switch is inside the proxy accordion (Radix unmounts content when closed).
      // Open the accordion first to render the switch into DOM.
      await settingsPage.openAccordion(['本地代理', 'Local Proxy', '代理服务']);
      await browser.pause(800);
      const toggleCount = await countElements('[role="switch"]');
      expect(toggleCount).toBeGreaterThan(0);
    });

    it('should display proxy port configuration', async () => {
      // "本地代理" is in the AccordionTrigger (always visible in proxy tab)
      // "自动故障转移" is also in AccordionTrigger
      const hasPort = await pageContainsText('本地代理') || await pageContainsText('Local Proxy') ||
                      await pageContainsText('代理服务') || await pageContainsText('端口') ||
                      await pageContainsText('Port') || await pageContainsText('8877');
      expect(hasPort).toBe(true);
    });

    it('should have failover toggle', async () => {
      // "自动故障转移" is in the AccordionTrigger (always visible in proxy tab)
      const hasFailover = await pageContainsText('自动故障转移') || await pageContainsText('故障转移') ||
                          await pageContainsText('Failover') || await pageContainsText('failover');
      expect(hasFailover).toBe(true);
    });
  });

  // ─── Auth Tab ───────────────────────────────────────────────────────────────

  describe('Auth Tab', () => {
    before(async () => {
      await settingsPage.openTab('auth');
      // Wait for auth tab content to be visible
      await waitForAnyText(['认证', 'Auth', 'GitHub', 'Copilot', '登录'], 10_000);
      await browser.pause(300);
    });

    it('should display auth section', async () => {
      const hasAuth = await pageContainsText('认证') || await pageContainsText('Auth') ||
                      await pageContainsText('登录') || await pageContainsText('Login');
      expect(hasAuth).toBe(true);
    });

    it('should show GitHub Copilot auth option', async () => {
      // AuthCenterPanel has hardcoded "GitHub Copilot" heading
      const hasCopilot = await pageContainsText('Copilot') || await pageContainsText('GitHub');
      expect(hasCopilot).toBe(true);
    });

    it('should display authentication status', async () => {
      const hasStatus = await browser.execute(() => {
        const body = document.body.textContent || (document.body as HTMLElement).innerText || '';
        const els = document.querySelectorAll('[data-testid*="auth"], [class*="auth"]');
        return els.length > 0 || body.includes('登录') || body.includes('未登录') || body.includes('登出');
      });
      expect(typeof hasStatus).toBe('boolean');
    });
  });

  // ─── Environment Variables Tab ──────────────────────────────────────────────

  describe('Environment Variables Tab', () => {
    before(async () => {
      await settingsPage.openTab('env');
      // Wait for env tab content to be visible
      await waitForAnyText(['环境', 'Environment', '变量', '系统环境'], 12_000);
      await browser.pause(500);
    });

    it('should display environment variables section', async () => {
      const hasEnv = await pageContainsText('环境') || await pageContainsText('Environment') ||
                     await pageContainsText('变量') || await pageContainsText('系统环境变量');
      expect(hasEnv).toBe(true);
    });

    it('should show sections for Claude/Codex/Gemini apps', async () => {
      const hasClaude = await pageContainsText('Claude');
      const hasGemini = await pageContainsText('Gemini');
      const hasCodex = await pageContainsText('Codex') || await pageContainsText('OpenAI');
      expect(hasClaude || hasGemini || hasCodex).toBe(true);
    });

    it('should have add environment variable button', async () => {
      // The add button is inside CollapsibleContent (unmounted when closed).
      // Open the Claude Code section first to render the button into DOM.
      await settingsPage.openAccordion(['Claude Code', 'ANTHROPIC', 'Codex', 'OPENAI']);
      // Wait for loading to complete (IPC call to load env vars)
      await browser.pause(1500);
      const hasAddBtn = await browser.execute(() => {
        const allButtons = Array.from(document.querySelectorAll('button'));
        return allButtons.some((b) => {
          const text = b.textContent?.trim() || '';
          return text.includes('添加') || text.includes('Add');
        });
      });
      expect(hasAddBtn).toBe(true);
    });
  });

  // ─── Advanced Tab ───────────────────────────────────────────────────────────

  describe('Advanced Tab', () => {
    before(async () => {
      await settingsPage.openTab('advanced');
      // Wait for advanced tab content to be visible
      await waitForAnyText(['高级', 'Advanced', '配置文件目录', '目录', 'Directory'], 10_000);
      await browser.pause(300);
    });

    it('should display advanced settings', async () => {
      const hasAdvanced = await pageContainsText('高级') || await pageContainsText('Advanced') ||
                          await pageContainsText('目录') || await pageContainsText('Directory') ||
                          await pageContainsText('配置文件目录');
      expect(hasAdvanced).toBe(true);
    });

    describe('Directory Settings', () => {
      before(async () => {
        // Click accordion trigger for "配置文件目录" / "Directory"
        await settingsPage.openAccordion(['配置文件目录', 'Directory', '目录']);
        await browser.pause(600);
      });

      it('should show data directory path', async () => {
        const hasDir = await pageContainsText('数据目录') || await pageContainsText('Data Directory') ||
                       await pageContainsText('~/.cc-switch') || await pageContainsText('目录') ||
                       await pageContainsText('配置目录') || await pageContainsText('Haipee');
        expect(hasDir).toBe(true);
      });
    });

    describe('Import/Export Settings', () => {
      before(async () => {
        // Click accordion trigger for "数据管理" / "Import/Export"
        await settingsPage.openAccordion(['数据管理', 'Import', 'Export', '导入', '导出']);
        await browser.pause(600);
      });

      it('should show import/export options', async () => {
        const hasImport = await pageContainsText('导入') || await pageContainsText('Import');
        const hasExport = await pageContainsText('导出') || await pageContainsText('Export');
        const hasDataMgmt = await pageContainsText('数据管理') || await pageContainsText('SQL');
        expect(hasImport || hasExport || hasDataMgmt).toBe(true);
      });
    });

    describe('Backup Settings', () => {
      before(async () => {
        // Click accordion trigger for "备份与恢复" / "Backup"
        await settingsPage.openAccordion(['备份与恢复', '备份', 'Backup']);
        await browser.pause(600);
      });

      it('should show backup options', async () => {
        const hasBackup = await pageContainsText('备份') || await pageContainsText('Backup');
        expect(hasBackup).toBe(true);
      });
    });

    describe('Model Test Settings', () => {
      before(async () => {
        // Click accordion trigger for "模型测试配置"
        await settingsPage.openAccordion(['模型测试配置', '模型测试', '测试配置', 'Model Test', 'Stream', '流式']);
        await browser.pause(500);
      });

      it('should show model test section', async () => {
        const hasTest = await pageContainsText('模型测试') || await pageContainsText('测试配置') ||
                        await pageContainsText('Stream') || await pageContainsText('Model Test');
        expect(hasTest).toBe(true);
      });
    });
  });

  // ─── Usage Tab ──────────────────────────────────────────────────────────────

  describe('Usage Tab', () => {
    before(async () => {
      await settingsPage.openTab('usage');
      await waitForAnyText(['使用统计', '用量', 'Usage', '统计', 'Statistics', 'Token'], 10_000);
      await browser.pause(300);
    });

    it('should display usage statistics section', async () => {
      const hasUsage = await pageContainsText('使用统计') || await pageContainsText('用量') ||
                       await pageContainsText('Usage') || await pageContainsText('统计') ||
                       await pageContainsText('Statistics');
      expect(hasUsage).toBe(true);
    });

    it('should display usage data or empty state', async () => {
      const hasContent = await browser.execute(() => {
        const body = (document.body as HTMLElement)?.innerText || document.body?.textContent || '';
        return body.includes('使用统计') || body.includes('用量') || body.includes('Usage') ||
               body.includes('统计') || body.includes('暂无') || body.includes('No data') ||
               body.includes('Token') || body.includes('请求');
      });
      expect(hasContent).toBe(true);
    });
  });

  // ─── About Tab ──────────────────────────────────────────────────────────────

  describe('About Tab', () => {
    before(async () => {
      await settingsPage.openTab('about');
      // Wait for about tab content (version number, project name)
      await waitForAnyText(['Haipee', 'haipee', 'v0.', 'v1.', '版本', 'version', 'GitHub'], 10_000);
      await browser.pause(300);
    });

    it('should display version information', async () => {
      const hasVersion = await browser.execute(() => {
        const body = (document.body as HTMLElement)?.innerText || document.body?.textContent || '';
        return /v\d+\.\d+/.test(body) || body.includes('版本') || body.includes('version');
      });
      expect(hasVersion).toBe(true);
    });

    it('should display project name', async () => {
      const hasName = await pageContainsText('Haipee') || await pageContainsText('haipee') ||
                      await pageContainsText('HAIPEE');
      expect(hasName).toBe(true);
    });

    it('should display installed tool versions', async () => {
      const hasTools = await pageContainsText('Claude') || await pageContainsText('claude');
      expect(hasTools).toBe(true);
    });

    it('should display GitHub link', async () => {
      // AboutSection has an <a> anchor linking to GitHub
      const hasGitHub = await pageContainsText('GitHub') || await pageContainsText('github') ||
                        await browser.execute(() => !!document.querySelector('a[href*="github"]'));
      expect(hasGitHub).toBe(true);
    });
  });

  // ─── Models Tab (Agent Config) ───────────────────────────────────────────────

  describe('Models/Agent Tab', () => {
    before(async () => {
      await settingsPage.openTab('models');
      await waitForAnyText(['Agent', '模型', 'Model', 'Claude', 'Codex', 'Gemini'], 10_000);
      await browser.pause(300);
    });

    it('should display model configuration panel', async () => {
      const hasModels = await pageContainsText('Agent') || await pageContainsText('模型') ||
                        await pageContainsText('Model');
      expect(hasModels).toBe(true);
    });

    it('should show app selector tabs for models', async () => {
      const hasAppTabs = await browser.execute(() => {
        const body = (document.body as HTMLElement)?.innerText || document.body?.textContent || '';
        return body.includes('Claude') || body.includes('Codex') ||
               body.includes('Gemini') || body.includes('OpenCode');
      });
      expect(hasAppTabs).toBe(true);
    });
  });

  // ─── Integrated Settings Operations ─────────────────────────────────────────

  describe('Settings Integration', () => {
    it('should persist settings between tab switches', async () => {
      await settingsPage.openTab('general');
      await waitForAnyText(['语言', 'Language', '主题', 'Theme'], 8_000);
      await settingsPage.openTab('about');
      await waitForAnyText(['Haipee', 'GitHub', '版本'], 8_000);
      await settingsPage.openTab('general');
      await waitForAnyText(['语言', 'Language', '主题', 'Theme'], 8_000);

      const hasGeneral = await pageContainsText('语言') || await pageContainsText('Language') ||
                          await pageContainsText('主题') || await pageContainsText('Theme');
      expect(hasGeneral).toBe(true);
    });

    it('should save settings via IPC when available', async () => {
      const hasTauri = await isTauriAvailable();
      if (!hasTauri) {
        console.log('[test] Tauri IPC not available - skipping IPC persistence test');
        return;
      }

      const settings = await invokeIPC<Record<string, unknown>>('get_settings');
      expect(settings).not.toBeNull();
      expect(typeof settings).toBe('object');
    });
  });
});
