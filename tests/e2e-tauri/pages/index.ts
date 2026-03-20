/**
 * Re-export page objects from the existing e2e/tauri/pages
 * This allows tests in e2e-tauri to import from relative paths
 */

export { dashboardPage, DashboardPage } from '../../e2e/tauri/pages/DashboardPage';
export { TauriBasePage } from '../../e2e/tauri/pages/TauriBasePage';
export { navigationPage, NavigationPage } from '../../e2e/tauri/pages/NavigationPage';
export { settingsPage, SettingsPage } from '../../e2e/tauri/pages/SettingsPage';
export { openClawChatPage, OpenClawChatPage } from '../../e2e/tauri/pages/OpenClawChatPage';
export { agentConfigPage, AgentConfigPage } from '../../e2e/tauri/pages/AgentConfigPage';