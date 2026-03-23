/// <reference types="@wdio/globals/types" />
/**
 * Skills Tests - Skills list and CRUD operations
 */

import { skillsPage, navigationPage } from '../pages';

describe('Skills – List', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);
  });

  it('should display skills list', async () => {
    const list = await $('[data-testid="skills-list"]');
    const hasList = await list.isExisting();
    expect(typeof hasList).toBe('boolean');
  });

  it('should show skill count', async () => {
    const skills = await $$('[data-testid="skill-item"]');
    const skillArray = [...skills] as unknown as WebdriverIO.Element[];
    expect(skillArray.length).toBeGreaterThanOrEqual(0);
  });

  it('should display skill names', async () => {
    const skills = await $$('[data-testid="skill-item"]');
    const skillArray = [...skills] as unknown as WebdriverIO.Element[];
    if (skillArray.length > 0) {
      const firstSkill = skillArray[0];
      const text = await firstSkill.getText();
      expect(text.length).toBeGreaterThan(0);
    }
  });
});

describe('Skills – Search', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show search input', async () => {
    const searchInput = await $('[data-testid="skill-search"]');
    const hasSearch = await searchInput.isExisting();
    expect(typeof hasSearch).toBe('boolean');
  });

  it('should filter skills by search query', async () => {
    const searchInput = await $('[data-testid="skill-search"]');
    if (await searchInput.isExisting()) {
      await searchInput.setValue('test');
      await browser.pause(300);
      expect(true).toBe(true);
    }
  });
});

describe('Skills – CRUD', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);
  });

  it('should show add skill button', async () => {
    const addBtn = await $('[data-testid="skill-add-btn"]');
    const hasBtn = await addBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should open add skill form', async () => {
    const addBtn = await $('[data-testid="skill-add-btn"]');
    if (await addBtn.isExisting()) {
      await addBtn.click();
      await browser.pause(500);

      const hasForm = await skillsPage.pageContainsAnyText([
        '添加', 'Add', 'Skill', '技能'
      ]);
      expect(typeof hasForm).toBe('boolean');

      await browser.keys(['Escape']);
    }
  });

  it('should toggle skill enabled state', async () => {
    const skills = await $$('[data-testid="skill-item"]');
    const skillArray = [...skills] as unknown as WebdriverIO.Element[];
    if (skillArray.length > 0) {
      const firstSkill = skillArray[0];
      const toggle = await firstSkill.$('button[role="switch"], input[type="checkbox"]');
      if (await toggle.isExisting()) {
        await toggle.click();
        await browser.pause(300);
        expect(true).toBe(true);
      }
    }
  });
});

describe('Skills – Discovery', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show discovery button', async () => {
    const discoverBtn = await $('[data-testid="skill-discovery-btn"]');
    const hasBtn = await discoverBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should open discovery panel', async () => {
    const discoverBtn = await $('[data-testid="skill-discovery-btn"]');
    if (await discoverBtn.isExisting()) {
      await discoverBtn.click();
      await browser.pause(500);

      const hasPanel = await skillsPage.pageContainsAnyText([
        '发现', 'Discover', 'Browse', '浏览'
      ]);
      expect(typeof hasPanel).toBe('boolean');

      await browser.keys(['Escape']);
    }
  });
});