import { useCallback, useEffect, useMemo, useState } from "react";

import {
  Loader2,
  Save,
  FolderSearch,
  Database,
  Cloud,
  ScrollText,
  HardDriveDownload,
  FlaskConical,
  ArrowLeft,
  Globe,
  Settings as SettingsIcon,
  ShieldAlert,
  Info,
  BarChart,
} from "lucide-react";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { settingsApi } from "@/lib/api";
import { LanguageSettings } from "@/components/settings/LanguageSettings";
import { ThemeSettings } from "@/components/settings/ThemeSettings";
import { WindowSettings } from "@/components/settings/WindowSettings";
// import { AppVisibilitySettings } from "@/components/settings/AppVisibilitySettings";
import { SkillSyncMethodSettings } from "@/components/settings/SkillSyncMethodSettings";
import { TerminalSettings } from "@/components/settings/TerminalSettings";
import { DirectorySettings } from "@/components/settings/DirectorySettings";
import { ImportExportSection } from "@/components/settings/ImportExportSection";
import { BackupListSection } from "@/components/settings/BackupListSection";
import { WebdavSyncSection } from "@/components/settings/WebdavSyncSection";
import { AboutSection } from "@/components/settings/AboutSection";
import { ProxyTabContent } from "@/components/settings/ProxyTabContent";
import { ModelTestConfigPanel } from "@/components/usage/ModelTestConfigPanel";
import { UsageDashboard } from "@/components/usage/UsageDashboard";
import { LogConfigPanel } from "@/components/settings/LogConfigPanel";
import { useSettings } from "@/hooks/useSettings";
import { useImportExport } from "@/hooks/useImportExport";
import { useTranslation } from "react-i18next";
import type { SettingsFormState } from "@/hooks/useSettings";

interface SettingsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onImportSuccess?: () => void | Promise<void>;
  defaultTab?: string;
}

export function SettingsPage({
  open,
  onOpenChange,
  onImportSuccess,
  defaultTab = "general",
}: SettingsDialogProps) {
  const { t } = useTranslation();
  const {
    settings,
    isLoading,
    isSaving,
    isPortable,
    appConfigDir,
    resolvedDirs,
    updateSettings,
    updateDirectory,
    updateAppConfigDir,
    browseDirectory,
    browseAppConfigDir,
    resetDirectory,
    resetAppConfigDir,
    saveSettings,
    autoSaveSettings,
    requiresRestart,
    acknowledgeRestart,
  } = useSettings();

  const {
    selectedFile,
    status: importStatus,
    errorMessage,
    backupId,
    isImporting,
    selectImportFile,
    importConfig,
    exportConfig,
    clearSelection,
    resetStatus,
  } = useImportExport({ onImportSuccess });

  const [activeTab, setActiveTab] = useState<string>("general");
  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [showRestartPrompt, setShowRestartPrompt] = useState(false);

  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    if (window.innerWidth < 768) {
      setIsDetailOpen(true);
    }
  };

  useEffect(() => {
    if (open) {
      setActiveTab(defaultTab);
      resetStatus();
    }
  }, [open, resetStatus, defaultTab]);

  useEffect(() => {
    if (requiresRestart) {
      setShowRestartPrompt(true);
    }
  }, [requiresRestart]);

  const closeAfterSave = useCallback(() => {
    // 保存成功后关闭：不再重置语言，避免需要“保存两次”才生效
    acknowledgeRestart();
    clearSelection();
    resetStatus();
    onOpenChange(false);
  }, [acknowledgeRestart, clearSelection, onOpenChange, resetStatus]);

  const handleSave = useCallback(async () => {
    try {
      const result = await saveSettings(undefined, { silent: false });
      if (!result) return;
      if (result.requiresRestart) {
        setShowRestartPrompt(true);
        return;
      }
      closeAfterSave();
    } catch (error) {
      console.error("[SettingsPage] Failed to save settings", error);
    }
  }, [closeAfterSave, saveSettings]);

  const handleRestartLater = useCallback(() => {
    setShowRestartPrompt(false);
    closeAfterSave();
  }, [closeAfterSave]);

  const handleRestartNow = useCallback(async () => {
    setShowRestartPrompt(false);
    if (import.meta.env.DEV) {
      toast.success(t("settings.devModeRestartHint"), { closeButton: true });
      closeAfterSave();
      return;
    }

    try {
      await settingsApi.restart();
    } catch (error) {
      console.error("[SettingsPage] Failed to restart app", error);
      toast.error(t("settings.restartFailed"));
    } finally {
      closeAfterSave();
    }
  }, [closeAfterSave, t]);

  // 通用设置即时保存（无需手动点击）
  // 使用 autoSaveSettings 避免误触发系统 API（开机自启、Claude 插件等）
  const handleAutoSave = useCallback(
    async (updates: Partial<SettingsFormState>) => {
      if (!settings) return;
      updateSettings(updates);
      try {
        await autoSaveSettings(updates);
      } catch (error) {
        console.error("[SettingsPage] Failed to autosave settings", error);
        toast.error(
          t("settings.saveFailedGeneric", {
            defaultValue: "保存失败，请重试",
          }),
        );
      }
    },
    [autoSaveSettings, settings, t, updateSettings],
  );

  const isBusy = useMemo(() => isLoading && !settings, [isLoading, settings]);

  return (
    <div className="w-full bg-background">
      {isBusy ? (
        <div className="flex w-full h-full items-center justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      ) : (
        <div className="flex-1 space-y-6 p-6 md:p-10 pb-16 mx-auto w-full max-w-6xl">
          {/* Desktop Header */}
          <div className="hidden md:block space-y-0.5 mb-6">
            <h2 className="text-2xl font-bold tracking-tight">
              {t("settings.title", "Settings")}
            </h2>
            <p className="text-muted-foreground">
              {t(
                "settings.description",
                "Manage your application settings and preferences.",
              )}
            </p>
          </div>
          <div className="hidden md:block h-px bg-border my-6" />

          {/* Mobile Navigation List Only - Desktop uses sidebar submenu */}
          <div
            className={cn("w-full md:hidden", isDetailOpen ? "hidden" : "flex")}
          >
            <nav className="flex flex-col space-y-1 w-full">
              {[
                {
                  id: "general",
                  icon: SettingsIcon,
                  label: t("settings.tabGeneral"),
                },
                { id: "proxy", icon: Globe, label: t("settings.tabProxy") },
                {
                  id: "advanced",
                  icon: ShieldAlert,
                  label: t("settings.tabAdvanced"),
                },
                {
                  id: "usage",
                  icon: BarChart,
                  label: t("usage.title", "Usage"),
                },
                { id: "about", icon: Info, label: t("common.about", "About") },
              ].map((item) => (
                <Button
                  key={item.id}
                  variant={activeTab === item.id ? "secondary" : "ghost"}
                  onClick={() => handleTabChange(item.id)}
                  className={cn(
                    "justify-start rounded-xl transition-all h-12 shrink-0",
                    activeTab === item.id
                      ? "bg-secondary text-primary"
                      : "",
                  )}
                >
                  <item.icon className="w-5 h-5 mr-3" />
                  <span className="font-medium">{item.label}</span>
                </Button>
              ))}
            </nav>
          </div>

          {/* Detail/Content View */}
          <div
            className={cn(
              "w-full",
              !isDetailOpen ? "hidden md:block" : "block",
            )}
          >
            {/* Mobile Header for Detail */}
            <div className="md:hidden flex items-center mb-6">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setIsDetailOpen(false)}
                className="-ml-2 mr-2"
              >
                <ArrowLeft className="w-5 h-5" />
              </Button>
              <h2 className="text-lg font-semibold tracking-tight capitalize">
                {activeTab === "general" && t("settings.tabGeneral")}
                {activeTab === "proxy" && t("settings.tabProxy")}
                {activeTab === "advanced" && t("settings.tabAdvanced")}
                {activeTab === "usage" && t("usage.title", "Usage")}
                {activeTab === "about" && t("common.about", "About")}
              </h2>
            </div>

            <div className="pb-24">
              {activeTab === "general" && (
                <div className="space-y-6">
                  <LanguageSettings
                    value={settings?.language || "en"}
                    onChange={(lang) => handleAutoSave({ language: lang })}
                  />
                  <ThemeSettings />
                  <WindowSettings
                    settings={settings!}
                    onChange={handleAutoSave}
                  />
                  <SkillSyncMethodSettings
                    value={settings?.skillSyncMethod ?? "auto"}
                    onChange={(method) =>
                      handleAutoSave({ skillSyncMethod: method })
                    }
                  />
                  <TerminalSettings
                    value={settings?.preferredTerminal || "auto"}
                    onChange={(terminal) =>
                      handleAutoSave({ preferredTerminal: terminal })
                    }
                  />
                </div>
              )}

              {activeTab === "proxy" && settings && (
                <div className="space-y-6">
                  <ProxyTabContent
                    settings={settings}
                    onAutoSave={handleAutoSave}
                  />
                </div>
              )}

              {activeTab === "advanced" && settings && (
                <div className="space-y-4">
                  <Accordion
                    type="multiple"
                    defaultValue={[]}
                    className="w-full space-y-4"
                  >
                    <AccordionItem
                      value="directory"
                      className="rounded-xl glass-card overflow-hidden border border-border/50"
                    >
                      <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-muted/50 data-[state=open]:bg-muted/50">
                        <div className="flex items-center gap-3">
                          <FolderSearch className="h-5 w-5 text-primary" />
                          <div className="text-left">
                            <h3 className="text-base font-semibold">
                              {t("settings.advanced.configDir.title")}
                            </h3>
                            <p className="text-sm text-muted-foreground font-normal">
                              {t("settings.advanced.configDir.description")}
                            </p>
                          </div>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="px-6 pb-6 pt-4 border-t border-border/50">
                        <DirectorySettings
                          appConfigDir={appConfigDir}
                          resolvedDirs={resolvedDirs}
                          onAppConfigChange={updateAppConfigDir}
                          onBrowseAppConfig={browseAppConfigDir}
                          onResetAppConfig={resetAppConfigDir}
                          claudeDir={settings.claudeConfigDir}
                          codexDir={settings.codexConfigDir}
                          geminiDir={settings.geminiConfigDir}
                          opencodeDir={settings.opencodeConfigDir}
                          onDirectoryChange={updateDirectory}
                          onBrowseDirectory={browseDirectory}
                          onResetDirectory={resetDirectory}
                        />
                      </AccordionContent>
                    </AccordionItem>

                    <AccordionItem
                      value="data"
                      className="rounded-xl glass-card overflow-hidden border border-border/50"
                    >
                      <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-muted/50 data-[state=open]:bg-muted/50">
                        <div className="flex items-center gap-3">
                          <Database className="h-5 w-5 text-blue-500" />
                          <div className="text-left">
                            <h3 className="text-base font-semibold">
                              {t("settings.advanced.data.title")}
                            </h3>
                            <p className="text-sm text-muted-foreground font-normal">
                              {t("settings.advanced.data.description")}
                            </p>
                          </div>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="px-6 pb-6 pt-4 border-t border-border/50">
                        <ImportExportSection
                          status={importStatus}
                          selectedFile={selectedFile}
                          errorMessage={errorMessage}
                          backupId={backupId}
                          isImporting={isImporting}
                          onSelectFile={selectImportFile}
                          onImport={importConfig}
                          onExport={exportConfig}
                          onClear={clearSelection}
                        />
                      </AccordionContent>
                    </AccordionItem>

                    <AccordionItem
                      value="backup"
                      className="rounded-xl glass-card overflow-hidden border border-border/50"
                    >
                      <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-muted/50 data-[state=open]:bg-muted/50">
                        <div className="flex items-center gap-3">
                          <HardDriveDownload className="h-5 w-5 text-amber-500" />
                          <div className="text-left">
                            <h3 className="text-base font-semibold">
                              {t("settings.advanced.backup.title", {
                                defaultValue: "Backup & Restore",
                              })}
                            </h3>
                            <p className="text-sm text-muted-foreground font-normal">
                              {t("settings.advanced.backup.description", {
                                defaultValue:
                                  "Manage automatic backups, view and restore database snapshots",
                              })}
                            </p>
                          </div>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="px-6 pb-6 pt-4 border-t border-border/50">
                        <BackupListSection
                          backupIntervalHours={settings.backupIntervalHours}
                          backupRetainCount={settings.backupRetainCount}
                          onSettingsChange={(updates) =>
                            handleAutoSave(updates)
                          }
                        />
                      </AccordionContent>
                    </AccordionItem>

                    <AccordionItem
                      value="cloudSync"
                      className="rounded-xl glass-card overflow-hidden border border-border/50"
                    >
                      <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-muted/50 data-[state=open]:bg-muted/50">
                        <div className="flex items-center gap-3">
                          <Cloud className="h-5 w-5 text-blue-500" />
                          <div className="text-left">
                            <h3 className="text-base font-semibold">
                              {t("settings.advanced.cloudSync.title")}
                            </h3>
                            <p className="text-sm text-muted-foreground font-normal">
                              {t("settings.advanced.cloudSync.description")}
                            </p>
                          </div>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="px-6 pb-6 pt-4 border-t border-border/50">
                        <WebdavSyncSection
                          config={settings?.webdavSync}
                          settings={settings}
                          onAutoSave={handleAutoSave}
                        />
                      </AccordionContent>
                    </AccordionItem>

                    <AccordionItem
                      value="test"
                      className="rounded-xl glass-card overflow-hidden border border-border/50"
                    >
                      <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-muted/50 data-[state=open]:bg-muted/50">
                        <div className="flex items-center gap-3">
                          <FlaskConical className="h-5 w-5 text-emerald-500" />
                          <div className="text-left">
                            <h3 className="text-base font-semibold">
                              {t("settings.advanced.modelTest.title")}
                            </h3>
                            <p className="text-sm text-muted-foreground font-normal">
                              {t("settings.advanced.modelTest.description")}
                            </p>
                          </div>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="px-6 pb-6 pt-4 border-t border-border/50">
                        <ModelTestConfigPanel />
                      </AccordionContent>
                    </AccordionItem>

                    <AccordionItem
                      value="logConfig"
                      className="rounded-xl glass-card overflow-hidden border border-border/50"
                    >
                      <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-muted/50 data-[state=open]:bg-muted/50">
                        <div className="flex items-center gap-3">
                          <ScrollText className="h-5 w-5 text-cyan-500" />
                          <div className="text-left">
                            <h3 className="text-base font-semibold">
                              {t("settings.advanced.logConfig.title")}
                            </h3>
                            <p className="text-sm text-muted-foreground font-normal">
                              {t("settings.advanced.logConfig.description")}
                            </p>
                          </div>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="px-6 pb-6 pt-4 border-t border-border/50">
                        <LogConfigPanel />
                      </AccordionContent>
                    </AccordionItem>
                  </Accordion>

                  <div className="flex items-center justify-end pt-4">
                    <Button
                      onClick={handleSave}
                      disabled={isSaving}
                      className="px-8 shadow-sm"
                    >
                      {isSaving ? (
                        <span className="inline-flex items-center gap-2">
                          <Loader2 className="h-4 w-4 animate-spin" />
                          {t("settings.saving")}
                        </span>
                      ) : (
                        <>
                          <Save className="mr-2 h-4 w-4" />
                          {t("common.save")}
                        </>
                      )}
                    </Button>
                  </div>
                </div>
              )}

              {activeTab === "about" && (
                <div className="space-y-6">
                  <AboutSection isPortable={isPortable} />
                </div>
              )}

              {activeTab === "usage" && (
                <div className="max-w-4xl space-y-6">
                  <UsageDashboard />
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      <Dialog
        open={showRestartPrompt}
        onOpenChange={(open) => !open && handleRestartLater()}
      >
        <DialogContent zIndex="alert" className="max-w-md glass border-border">
          <DialogHeader>
            <DialogTitle>{t("settings.restartRequired")}</DialogTitle>
          </DialogHeader>
          <div className="px-6">
            <p className="text-sm text-muted-foreground">
              {t("settings.restartRequiredMessage")}
            </p>
          </div>
          <DialogFooter>
            <Button
              variant="ghost"
              onClick={handleRestartLater}
              className="hover:bg-muted/50"
            >
              {t("settings.restartLater")}
            </Button>
            <Button
              onClick={handleRestartNow}
              className="bg-primary hover:bg-primary/90"
            >
              {t("settings.restartNow")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
