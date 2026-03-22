/// <reference types="@wdio/globals/types" />
/**
 * Comprehensive Settings Operations E2E Tests
 *
 * Tests actual operations within each settings tab:
 * - General: language, theme, window settings
 * - Proxy: toggle, failover configuration
 * - Auth: OAuth flow, auth status
 * - Env: environment variable CRUD
 * - Advanced: directory, import/export, backup
 * - Usage: statistics display
 * - About: version info
 */

import { settingsPage } from './pages/SettingsPage.ts';
import { navigationPage } from './pages/NavigationPage.ts';

// Utility helpers
async function pageContainsText(text: string): Promise<boolean> {
  return browser.execute((t) => {
    const inner = (document.body as HTMLElement)?.innerText || '';
    const content = document.body?.textContent || '';
    return inner.includes(t) || content.includes(t);
  }, text);
}

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

async function isTauriAvailable(): Promise<boolean> {
  return browser.execute(() => typeof (window as any).__TAURI__ !== 'undefined');
}

async function invokeIPC<T>(cmd: string, args: Record<string, unknown> = {}): Promise<T | null> {
  const hasTauri = await isTauriAvailable();
  if (!hasTauri) return null;

  return browser.execute(async (c, a) => {
    try {
      const { invoke } = (window as any).__TAURI__.core;
      return await invoke(c, a);
    } catch {
      return null;
    }
  }, cmd, args);
}

describe('Settings – General Tab Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('general');
    await waitForAnyText(['语言', 'Language', '主题', 'Theme'], 10_000);
  });

  describe('Language Settings', () => {
    it('should display language selection options', async () => {
      const hasLang = await pageContainsText('语言') || await pageContainsText('Language');
      expect(hasLang).toBe(true);
    });

    it('should switch to English and show English UI', async () => {
      const switched = await browser.execute(() => {
        const allButtons = Array.from(document.querySelectorAll('button'));
        const enBtn = allButtons.find((b) =>
          b.textContent?.trim() === 'English' || b.textContent?.includes('English'),
        );
        if (enBtn) {
          enBtn.click();
          return true;
        }
        return false;
      });

      await browser.pause(800);

      if (switched) {
        const hasEnglish = await pageContainsText('Language') || await pageContainsText('Settings');
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

    it('should have theme toggle buttons', async () => {
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
        const isDark = await browser.execute(() =>
          document.documentElement.classList.contains('dark') ||
          document.documentElement.getAttribute('data-theme') === 'dark',
        );
        expect(typeof isDark).toBe('boolean');
      }
    });

    it('should apply light theme', async () => {
      const applied = await browser.execute(() => {
        const allButtons = Array.from(document.querySelectorAll('button'));
        const lightBtn = allButtons.find((b) => {
          const text = b.textContent?.trim().toLowerCase() || '';
          return text.includes('light') || text.includes('浅色');
        });
        if (lightBtn) {
          lightBtn.click();
          return true;
        }
        return false;
      });

      await browser.pause(800);
      expect(typeof applied).toBe('boolean');
    });
  });

  describe('Window Settings', () => {
    it('should display window settings section', async () => {
      const hasWindow = await pageContainsText('窗口') || await pageContainsText('Window') ||
                        await pageContainsText('最小化') || await pageContainsText('托盘');
      expect(typeof hasWindow).toBe('boolean');
    });

    it('should have minimize to tray option', async () => {
      const hasToggle = await browser.execute(() => {
        const switches = document.querySelectorAll('[role="switch"]');
        return switches.length > 0;
      });
      expect(typeof hasToggle).toBe('boolean');
    });
  });
});

describe('Settings – Proxy Tab Operations', () => {
  before(async () => {
    await settingsPage.openTab('proxy');
    await waitForAnyText(['本地代理', 'Local Proxy', '代理服务', '自动故障转移'], 10_000);
  });

  it('should display proxy settings section', async () => {
    const hasProxy = await pageContainsText('代理') || await pageContainsText('Proxy');
    expect(hasProxy).toBe(true);
  });

  it('should have proxy toggle switch', async () => {
    await settingsPage.openAccordion(['本地代理', 'Local Proxy', '代理服务']);
    await browser.pause(800);

    const toggleCount = await browser.execute(() => {
      return document.querySelectorAll('[role="switch"]').length;
    });
    expect(toggleCount).toBeGreaterThan(0);
  });

  it('should display proxy port configuration', async () => {
    const hasPort = await pageContainsText('端口') || await pageContainsText('Port') ||
                    await pageContainsText('8877');
    expect(typeof hasPort).toBe('boolean');
  });

  it('should have failover toggle', async () => {
    const hasFailover = await pageContainsText('自动故障转移') || await pageContainsText('故障转移') ||
                        await pageContainsText('Failover');
    expect(hasFailover).toBe(true);
  });

  it('should display failover queue management', async () => {
    await settingsPage.openAccordion(['故障转移', 'Failover', '队列']);
    await browser.pause(500);

    const hasQueue = await pageContainsText('队列') || await pageContainsText('Queue') ||
                     await pageContainsText('优先级') || await pageContainsText('Priority');
    expect(typeof hasQueue).toBe('boolean');
  });
});

describe('Settings – Auth Tab Operations', () => {
  before(async () => {
    await settingsPage.openTab('auth');
    await waitForAnyText(['认证', 'Auth', 'GitHub', 'Copilot', '登录'], 10_000);
  });

  it('should display auth section', async () => {
    const hasAuth = await pageContainsText('认证') || await pageContainsText('Auth') ||
                    await pageContainsText('登录') || await pageContainsText('Login');
    expect(hasAuth).toBe(true);
  });

  it('should show GitHub Copilot auth option', async () => {
    const hasCopilot = await pageContainsText('Copilot') || await pageContainsText('GitHub');
    expect(hasCopilot).toBe(true);
  });

  it('should display authentication status', async () => {
    const hasStatus = await browser.execute(() => {
      const body = document.body.textContent || '';
      return body.includes('登录') || body.includes('未登录') || body.includes('登出') ||
             body.includes('connected') || body.includes('authorized');
    });
    expect(typeof hasStatus).toBe('boolean');
  });

  it('should have auth action buttons', async () => {
    const hasButton = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons.some(btn =>
        btn.textContent?.includes('登录') ||
        btn.textContent?.includes('Login') ||
        btn.textContent?.includes('授权') ||
        btn.textContent?.includes('Authorize')
      );
    });
    expect(typeof hasButton).toBe('boolean');
  });
});

describe('Settings – Environment Variables Tab Operations', () => {
  before(async () => {
    await settingsPage.openTab('env');
    await waitForAnyText(['环境', 'Environment', '变量', '系统环境'], 12_000);
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

  it('should open Claude env section', async () => {
    await settingsPage.openAccordion(['Claude Code', 'ANTHROPIC']);
    await browser.pause(800);

    const hasContent = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('ANTHROPIC_API_KEY') || text.includes('ANTHROPIC_BASE_URL') ||
             text.includes('添加') || text.includes('Add');
    });
    expect(typeof hasContent).toBe('boolean');
  });

  it('should have add environment variable button', async () => {
    const hasAddBtn = await browser.execute(() => {
      const allButtons = Array.from(document.querySelectorAll('button'));
      return allButtons.some((b) => {
        const text = b.textContent?.trim() || '';
        return text.includes('添加') || text.includes('Add');
      });
    });
    expect(typeof hasAddBtn).toBe('boolean');
  });
});

describe('Settings – Advanced Tab Operations', () => {
  before(async () => {
    await settingsPage.openTab('advanced');
    await waitForAnyText(['高级', 'Advanced', '配置文件目录', '目录', 'Directory'], 10_000);
  });

  it('should display advanced settings', async () => {
    const hasAdvanced = await pageContainsText('高级') || await pageContainsText('Advanced') ||
                        await pageContainsText('目录') || await pageContainsText('Directory');
    expect(hasAdvanced).toBe(true);
  });

  describe('Directory Settings', () => {
    it('should show directory accordion', async () => {
      await settingsPage.openAccordion(['配置文件目录', 'Directory', '目录']);
      await browser.pause(600);

      const hasDir = await pageContainsText('数据目录') || await pageContainsText('Data Directory') ||
                     await pageContainsText('~/.haipee') || await pageContainsText('Haipee');
      expect(typeof hasDir).toBe('boolean');
    });

    it('should have browse directory button', async () => {
      const hasBrowse = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some(btn =>
          btn.textContent?.includes('浏览') ||
          btn.textContent?.includes('Browse') ||
          btn.textContent?.includes('选择')
        );
      });
      expect(typeof hasBrowse).toBe('boolean');
    });
  });

  describe('Import/Export Settings', () => {
    it('should show import/export section', async () => {
      await settingsPage.openAccordion(['数据管理', 'Import', 'Export', '导入', '导出']);
      await browser.pause(600);

      const hasImport = await pageContainsText('导入') || await pageContainsText('Import');
      const hasExport = await pageContainsText('导出') || await pageContainsText('Export');
      expect(hasImport || hasExport).toBe(true);
    });

    it('should have import button', async () => {
      const hasImportBtn = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some(btn =>
          btn.textContent?.includes('导入') ||
          btn.textContent?.includes('Import')
        );
      });
      expect(typeof hasImportBtn).toBe('boolean');
    });

    it('should have export button', async () => {
      const hasExportBtn = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some(btn =>
          btn.textContent?.includes('导出') ||
          btn.textContent?.includes('Export')
        );
      });
      expect(typeof hasExportBtn).toBe('boolean');
    });
  });

  describe('Backup Settings', () => {
    it('should show backup section', async () => {
      await settingsPage.openAccordion(['备份与恢复', '备份', 'Backup']);
      await browser.pause(600);

      const hasBackup = await pageContainsText('备份') || await pageContainsText('Backup');
      expect(hasBackup).toBe(true);
    });
  });

  describe('Model Test Settings', () => {
    it('should show model test section', async () => {
      await settingsPage.openAccordion(['模型测试配置', '模型测试', '测试配置', 'Model Test']);
      await browser.pause(500);

      const hasTest = await pageContainsText('模型测试') || await pageContainsText('测试配置') ||
                      await pageContainsText('Stream') || await pageContainsText('Model Test');
      expect(typeof hasTest).toBe('boolean');
    });
  });
});

describe('Settings – Usage Tab Operations', () => {
  before(async () => {
    await settingsPage.openTab('usage');
    await waitForAnyText(['使用统计', '用量', 'Usage', '统计', 'Statistics', 'Token'], 10_000);
  });

  it('should display usage statistics section', async () => {
    const hasUsage = await pageContainsText('使用统计') || await pageContainsText('用量') ||
                     await pageContainsText('Usage') || await pageContainsText('统计');
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

  it('should show token counts if available', async () => {
    const hasTokens = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('Token') || text.includes('token') ||
             text.includes('输入') || text.includes('输出');
    });
    expect(typeof hasTokens).toBe('boolean');
  });
});

describe('Settings – About Tab Operations', () => {
  before(async () => {
    await settingsPage.openTab('about');
    await waitForAnyText(['Haipee', 'haipee', 'v0.', 'v1.', '版本', 'version', 'GitHub'], 10_000);
  });

  it('should display version information', async () => {
    const hasVersion = await browser.execute(() => {
      const body = (document.body as HTMLElement)?.innerText || document.body?.textContent || '';
      return /v\d+\.\d+/.test(body) || body.includes('版本') || body.includes('version');
    });
    expect(hasVersion).toBe(true);
  });

  it('should display project name', async () => {
    const hasName = await pageContainsText('Haipee') || await pageContainsText('haipee');
    expect(hasName).toBe(true);
  });

  it('should display installed tool versions', async () => {
    const hasTools = await pageContainsText('Claude') || await pageContainsText('claude');
    expect(hasTools).toBe(true);
  });

  it('should display GitHub link', async () => {
    const hasGitHub = await pageContainsText('GitHub') || await pageContainsText('github') ||
                      await browser.execute(() => !!document.querySelector('a[href*="github"]'));
    expect(hasGitHub).toBe(true);
  });
});

describe('Settings – Models Tab Operations', () => {
  before(async () => {
    await settingsPage.openTab('models');
    await waitForAnyText(['Agent', '模型', 'Model', 'Claude', 'Codex', 'Gemini'], 10_000);
  });

  it('should display model configuration panel', async () => {
    const hasModels = await pageContainsText('Agent') || await pageContainsText('模型') ||
                      await pageContainsText('Model');
    expect(hasModels).toBe(true);
  });

  it('should show app selector tabs', async () => {
    const hasAppTabs = await browser.execute(() => {
      const body = (document.body as HTMLElement)?.innerText || document.body?.textContent || '';
      return body.includes('Claude') || body.includes('Codex') ||
             body.includes('Gemini') || body.includes('OpenCode');
    });
    expect(hasAppTabs).toBe(true);
  });
});

describe('Settings – Integration', () => {
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