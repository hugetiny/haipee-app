import React, { useState, useCallback } from "react";
import { useTranslation } from "react-i18next";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  KeyRound,
  Shield,
  Cpu,
  Code2,
  LayoutGrid,
  Wifi,
  WifiOff,
  Loader2,
  Zap,
} from "lucide-react";
import { EnvPanel } from "./EnvPanel";
import { ToolsPanel } from "./ToolsPanel";
import { AgentsDefaultsPanel } from "./AgentsDefaultsPanel";
import { ProviderList } from "@/components/providers/ProviderList";
import { OpenClawHealthBanner } from "./OpenClawHealthBanner";
import { GatewayPanel } from "./GatewayPanel";
import { ChannelsPanel } from "./ChannelsPanel";
import { SkillsPluginsPanel } from "./SkillsPluginsPanel";
import JsonEditor from "@/components/JsonEditor";
import { toast } from "sonner";
import {
  useOpenClawHealth,
  useActiveOpenClawInstance,
  useOpenClawRawJson,
  useSaveOpenClawRawJson,
  useOpenClawPing,
} from "@/hooks/useOpenClaw";
import { openclawApi } from "@/lib/api/openclaw";
import { useSettings } from "@/hooks/useSettings";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Plus, Trash2, Globe, Laptop, Settings2, X } from "lucide-react";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";

const VALID_TABS = ["models", "env", "gateway", "channels", "skills", "tools", "agents", "raw"];

export function OpenClawDashboard({
  providers,
  currentProviderId,
  isLoadingProviders,
  isProxyRunning,
  isProxyTakeover,
  activeProviderId,
  currentView,
  onSwitchProvider,
  onEditProvider,
  onDeleteProvider,
  onDuplicateProvider,
  onSetAsDefaultModel,
  onOpenWebsite,
  onChangeView,
}: {
  providers: any;
  currentProviderId: string;
  isLoadingProviders: boolean;
  isProxyRunning: boolean;
  isProxyTakeover: boolean;
  activeProviderId?: string;
  currentView?: string;
  onSwitchProvider: (p: any) => void;
  onEditProvider: (p: any) => void;
  onDeleteProvider: (p: any) => void;
  onDuplicateProvider: (p: any) => void;
  onSetAsDefaultModel: (p: any) => void;
  onOpenWebsite: (url: string) => void;
  onChangeView?: (view: string) => void;
}) {
  const { t } = useTranslation();
  const [activeTab, setActiveTabState] = useState("models");

  // Sync activeTab with external currentView
  React.useEffect(() => {
    if (currentView && VALID_TABS.includes(currentView)) {
      setActiveTabState(currentView);
    }
  }, [currentView]);

  const setActiveTab = useCallback((tab: string) => {
    setActiveTabState(tab);
    if (onChangeView && VALID_TABS.includes(tab)) {
      onChangeView(tab);
    }
  }, [onChangeView]);
  const { updateSettings, saveSettings } = useSettings();
  const { activeInstance, instanceId, allInstances } =
    useActiveOpenClawInstance();
  const isRemote = activeInstance?.type === "remote";
  const [isManageDialogOpen, setIsManageDialogOpen] = useState(false);
  const [newInstance, setNewInstance] = useState({
    name: "",
    type: "remote" as const,
    baseUrl: "",
    apiKey: "",
  });
  const [isTesting, setIsTesting] = useState(false);

  // Fetch health warnings
  const { data: healthWarnings = [] } = useOpenClawHealth(true);

  // Connection ping (only for remote instances)
  const { data: pingData } = useOpenClawPing();

  // Fetch raw openclaw.json — now uses remote-aware hook!
  const { data: rawConfig, isLoading: isRawLoading } = useOpenClawRawJson();
  const saveRawMutation = useSaveOpenClawRawJson();

  const [localRaw, setLocalRaw] = useState<string | null>(null);

  // Sync local raw state when data loaded
  React.useEffect(() => {
    if (rawConfig !== undefined) {
      setLocalRaw(rawConfig);
    }
  }, [rawConfig]);

  // Test connection handler for the instance dialog
  const handleTestConnection = useCallback(async () => {
    if (!newInstance.baseUrl) return;
    setIsTesting(true);
    try {
      const result = await openclawApi.ping({
        id: "_test",
        name: "Test",
        type: "remote",
        baseUrl: newInstance.baseUrl,
        apiKey: newInstance.apiKey,
      });
      if (result.ok) {
        toast.success(
          t(
            "openclaw.instance.connectionSuccess",
            `Connected (${result.latencyMs}ms)`,
          ),
        );
      } else {
        toast.error(
          t("openclaw.instance.connectionFailed", "Connection failed"),
        );
      }
    } catch (e: any) {
      toast.error(
        t("openclaw.instance.connectionFailed", "Connection failed") +
        ": " +
        (e?.message || "Unknown error"),
      );
    } finally {
      setIsTesting(false);
    }
  }, [newInstance.baseUrl, newInstance.apiKey, t]);

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="px-6 pt-6 pb-2 border-b bg-background/50 backdrop-blur-md sticky top-0 z-10">
        <div className="flex flex-col gap-4 mb-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <h1 className="text-2xl font-bold tracking-tight">
                OpenClaw Dashboard
              </h1>
              {/* Connection Status Badge */}
              {isRemote && pingData && (
                <div
                  className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${pingData.ok
                      ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400"
                      : "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"
                    }`}
                >
                  {pingData.ok ? (
                    <Wifi className="w-3 h-3" />
                  ) : (
                    <WifiOff className="w-3 h-3" />
                  )}
                  {pingData.ok
                    ? `${pingData.latencyMs}ms`
                    : t("openclaw.instance.offline", "Offline")}
                </div>
              )}
              <div className="flex items-center gap-2 bg-muted/30 p-1 rounded-lg border border-border/50">
                <Select
                  value={instanceId}
                  onValueChange={(val) => {
                    updateSettings({ currentOpenClawInstanceId: val });
                    void saveSettings(
                      { currentOpenClawInstanceId: val },
                      { silent: true },
                    );
                  }}
                >
                  <SelectTrigger className="w-[180px] h-8 border-none bg-transparent focus:ring-0">
                    <SelectValue placeholder="Select instance" />
                  </SelectTrigger>
                  <SelectContent>
                    {allInstances.map((inst) => (
                      <SelectItem key={inst.id} value={inst.id}>
                        <div className="flex items-center gap-2">
                          {inst.type === "local" ? (
                            <Laptop className="w-3.5 h-3.5" />
                          ) : (
                            <Globe className="w-3.5 h-3.5" />
                          )}
                          <span>{inst.name}</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>

                <Dialog
                  open={isManageDialogOpen}
                  onOpenChange={setIsManageDialogOpen}
                >
                  <DialogTrigger asChild>
                    <Button variant="ghost" size="icon" className="h-8 w-8">
                      <Settings2 className="w-4 h-4" />
                    </Button>
                  </DialogTrigger>
                  <DialogContent className="sm:max-w-[425px]">
                    <DialogHeader className="flex flex-row items-center justify-between space-y-0">
                      <DialogTitle>Manage OpenClaw Instances</DialogTitle>
                      <DialogClose asChild>
                        <Button variant="ghost" size="icon" className="h-8 w-8 -mr-2">
                          <X className="h-4 w-4" />
                          <span className="sr-only">Close</span>
                        </Button>
                      </DialogClose>
                    </DialogHeader>
                    <div className="py-4 space-y-4">
                      <div className="space-y-4 max-h-[300px] overflow-y-auto pr-2">
                        {allInstances.map((inst) => (
                          <div
                            key={inst.id}
                            className="flex items-center justify-between p-3 rounded-lg border bg-muted/30"
                          >
                            <div className="flex flex-col">
                              <span className="font-medium">{inst.name}</span>
                              <span className="text-xs text-muted-foreground">
                                {inst.type === "local"
                                  ? "Local File"
                                  : inst.baseUrl || "No URL"}
                              </span>
                            </div>
                            {inst.id !== "default" && (
                              <Button
                                variant="ghost"
                                size="icon"
                                className="h-8 w-8 text-destructive"
                                onClick={() => {
                                  const filtered = allInstances.filter(
                                    (i) => i.id !== inst.id,
                                  );
                                  updateSettings({
                                    openclawInstances: filtered,
                                    currentOpenClawInstanceId: "default",
                                  });
                                  void saveSettings(
                                    {
                                      openclawInstances: filtered,
                                      currentOpenClawInstanceId: "default",
                                    },
                                    { silent: true },
                                  );
                                }}
                              >
                                <Trash2 className="w-4 h-4" />
                              </Button>
                            )}
                          </div>
                        ))}
                      </div>

                      <div className="pt-4 border-t space-y-3">
                        <Label>Add New Remote Instance</Label>
                        <Input
                          placeholder="Instance Name (e.g. Production)"
                          value={newInstance.name}
                          onChange={(e) =>
                            setNewInstance({
                              ...newInstance,
                              name: e.target.value,
                            })
                          }
                        />
                        <Input
                          placeholder="Base URL (e.g. http://1.2.3.4:1214)"
                          value={newInstance.baseUrl}
                          onChange={(e) =>
                            setNewInstance({
                              ...newInstance,
                              baseUrl: e.target.value,
                            })
                          }
                        />
                        <Input
                          placeholder="API Key (optional)"
                          type="password"
                          value={newInstance.apiKey}
                          onChange={(e) =>
                            setNewInstance({
                              ...newInstance,
                              apiKey: e.target.value,
                            })
                          }
                        />
                        <div className="flex gap-2">
                          <Button
                            variant="outline"
                            className="flex-1"
                            disabled={!newInstance.baseUrl || isTesting}
                            onClick={handleTestConnection}
                          >
                            {isTesting ? (
                              <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                            ) : (
                              <Zap className="w-4 h-4 mr-2" />
                            )}
                            {isTesting
                              ? t("openclaw.instance.testing", "Testing...")
                              : t(
                                "openclaw.instance.testConnection",
                                "Test Connection",
                              )}
                          </Button>
                          <Button
                            className="flex-1"
                            disabled={!newInstance.name || !newInstance.baseUrl}
                            onClick={() => {
                              if (!newInstance.name || !newInstance.baseUrl)
                                return;
                              const nid = `inst_${Date.now()}`;
                              const updated = [
                                ...allInstances,
                                { ...newInstance, id: nid },
                              ];
                              updateSettings({ openclawInstances: updated });
                              void saveSettings(
                                { openclawInstances: updated },
                                { silent: true },
                              );
                              setNewInstance({
                                name: "",
                                type: "remote",
                                baseUrl: "",
                                apiKey: "",
                              });
                            }}
                          >
                            <Plus className="w-4 h-4 mr-2" />
                            {t("openclaw.instance.add", "Add")}
                          </Button>
                        </div>
                      </div>
                    </div>
                  </DialogContent>
                </Dialog>
              </div>
            </div>
            {activeTab === "raw" && (
              <div className="flex items-center gap-2">
                <Button
                  size="sm"
                  onClick={() => {
                    if (localRaw) {
                      saveRawMutation.mutate(localRaw, {
                        onSuccess: () =>
                          toast.success(t("common.saveSuccess", "Saved")),
                        onError: (err: any) =>
                          toast.error(
                            t("common.saveFailed") +
                            ": " +
                            (err?.message || ""),
                          ),
                      });
                    }
                  }}
                  disabled={saveRawMutation.isPending || isRawLoading}
                >
                  {saveRawMutation.isPending
                    ? t("common.saving", "Saving...")
                    : t("common.save", "Save")}
                </Button>
              </div>
            )}
          </div>
          <OpenClawHealthBanner warnings={healthWarnings} />
        </div>

        {/* Mobile Only: Tab navigation - Desktop uses sidebar submenu */}
        <div className="md:hidden">
          <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <TabsList className="bg-muted/50 p-1 mb-2">
              <TabsTrigger
                value="models"
                className="flex items-center gap-2 px-4 py-2"
              >
                <LayoutGrid className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("models.title", "Models")}
                </span>
              </TabsTrigger>
              <TabsTrigger
                value="env"
                className="flex items-center gap-2 px-4 py-2"
              >
                <KeyRound className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("openclaw.env.title", "Keys")}
                </span>
              </TabsTrigger>
              <TabsTrigger
                value="gateway"
                className="flex items-center gap-2 px-4 py-2"
              >
                <Globe className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("openclaw.gateway.title", "Gateway")}
                </span>
              </TabsTrigger>
              <TabsTrigger
                value="channels"
                className="flex items-center gap-2 px-4 py-2"
              >
                <LayoutGrid className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("openclaw.channels.title", "Channels")}
                </span>
              </TabsTrigger>
              <TabsTrigger
                value="skills"
                className="flex items-center gap-2 px-4 py-2"
              >
                <Code2 className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("openclaw.skillsPlugins.title", "Skills & Plugins")}
                </span>
              </TabsTrigger>
              <TabsTrigger
                value="tools"
                className="flex items-center gap-2 px-4 py-2 text-zinc-500"
              >
                <Shield className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("openclaw.tools.title", "Tools")}
                </span>
              </TabsTrigger>
              <TabsTrigger
                value="agents"
                className="flex items-center gap-2 px-4 py-2 text-zinc-500"
              >
                <Cpu className="w-4 h-4" />
                <span className="hidden sm:inline">
                  {t("openclaw.agents.title", "Agents")}
                </span>
              </TabsTrigger>
              <TabsTrigger
                value="raw"
                className="flex items-center gap-2 px-4 py-2 text-zinc-500"
              >
                <Settings2 className="w-4 h-4" />
                <span className="hidden sm:inline">JSON</span>
              </TabsTrigger>
            </TabsList>
          </Tabs>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto overflow-x-hidden relative no-scrollbar">
        <div className="max-w-7xl mx-auto p-6">
          {/* Remote instance info banner */}
          {isRemote && activeInstance?.baseUrl && activeTab !== "models" && (
            <div className="mb-4 flex items-center gap-2 px-4 py-2.5 bg-green-50 dark:bg-green-950/30 border border-green-200 dark:border-green-800/50 rounded-lg text-sm text-green-700 dark:text-green-400">
              <Globe className="w-4 h-4 shrink-0" />
              <span>
                {t(
                  "openclaw.instance.editingRemote",
                  "Editing remote instance:",
                )}
              </span>
              <code className="font-mono text-xs bg-green-100 dark:bg-green-900/50 px-1.5 py-0.5 rounded">
                {activeInstance.baseUrl}
              </code>
            </div>
          )}
          <Tabs value={activeTab}>
            <TabsContent value="models" className="mt-0">
              <ProviderList
                providers={providers}
                currentProviderId={currentProviderId}
                appId="openclaw"
                isLoading={isLoadingProviders}
                isProxyRunning={isProxyRunning}
                isProxyTakeover={isProxyTakeover}
                activeProviderId={activeProviderId}
                onSwitch={onSwitchProvider}
                onEdit={onEditProvider}
                onDelete={onDeleteProvider}
                onDuplicate={onDuplicateProvider}
                onSetAsDefault={onSetAsDefaultModel}
                onOpenWebsite={onOpenWebsite}
              />
            </TabsContent>
            <TabsContent value="env" className="mt-0">
              <EnvPanel />
            </TabsContent>
            <TabsContent value="gateway" className="mt-0">
              <GatewayPanel />
            </TabsContent>
            <TabsContent value="channels" className="mt-0">
              <ChannelsPanel />
            </TabsContent>
            <TabsContent value="skills" className="mt-0">
              <SkillsPluginsPanel />
            </TabsContent>
            <TabsContent value="tools" className="mt-0">
              <ToolsPanel />
            </TabsContent>
            <TabsContent value="agents" className="mt-0">
              <AgentsDefaultsPanel />
            </TabsContent>
            <TabsContent value="raw" className="mt-0 h-[calc(100vh-250px)]">
              <div className="h-full rounded-xl border border-border bg-card overflow-hidden">
                <JsonEditor
                  value={localRaw ?? ""}
                  onChange={setLocalRaw}
                  height="100%"
                  darkMode={true}
                />
              </div>
              <p className="mt-2 text-xs text-muted-foreground flex items-center gap-2">
                <Shield className="w-3 h-3" />
                Editing openclaw.json directly is for advanced users. Invalid
                JSON may cause the Gateway to fail.
              </p>
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  );
}
