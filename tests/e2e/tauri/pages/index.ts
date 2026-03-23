/**
 * Page Object Models for Tauri E2E Tests
 */

export { TauriBasePage } from './TauriBasePage.ts';
export { DashboardPage, dashboardPage } from './DashboardPage.ts';
export { SettingsPage, settingsPage } from './SettingsPage.ts';
export { NavigationPage, navigationPage } from './NavigationPage.ts';
export { OpenClawChatPage, openClawChatPage } from './OpenClawChatPage.ts';
export {
  OpenClawGatewayPage,
  OpenClawChannelsPage,
  OpenClawSkillsMcpPage,
  openClawGatewayPage,
  openClawChannelsPage,
  openClawSkillsMcpPage,
} from './OpenClawPages.ts';
export { UniversalProviderPage, universalProviderPage } from './UniversalProviderPage.ts';
export { AgentConfigPage, agentConfigPage } from './AgentConfigPage.ts';
export { SessionManagerPage } from './SessionManagerPage.ts';
export { McpPage, mcpPage } from './McpPage.ts';
export { PromptsPage, promptsPage } from './PromptsPage.ts';
export { SkillsPage, skillsPage } from './SkillsPage.ts';
export { WebDavPage, webDavPage } from './WebDavPage.ts';

// Type exports
export type { ProviderFormData } from './DashboardPage.ts';
export type { AppSection } from './NavigationPage.ts';
export type { AgentId, ConfigTab } from './AgentConfigPage.ts';
export type { McpServerFormData, AppId } from './McpPage.ts';
export type { PromptFormData } from './PromptsPage.ts';
export type { SkillFormData } from './SkillsPage.ts';
export type { UniversalProviderData } from './UniversalProviderPage.ts';
