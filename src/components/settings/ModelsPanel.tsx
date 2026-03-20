import { useState } from "react";
import { useTranslation } from "react-i18next";
import { motion } from "framer-motion";
import { Plus, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ProviderList } from "@/components/providers/ProviderList";
import { AddProviderDialog } from "@/components/providers/AddProviderDialog";
import { EditProviderDialog } from "@/components/providers/EditProviderDialog";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { useProvidersQuery } from "@/lib/query";
import { useProviderActions } from "@/hooks/useProviderActions";
import { useProxyStatus } from "@/hooks/useProxyStatus";
import { useLastValidValue } from "@/hooks/useLastValidValue";
import { providersApi, settingsApi, type AppId } from "@/lib/api";
import type { Provider } from "@/types";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { extractErrorMessage } from "@/utils/errorUtils";
import { ProviderIcon } from "@/components/ProviderIcon";

const APP_TABS: { id: AppId; label: string; icon: string }[] = [
  { id: "claude", label: "Claude", icon: "claude" },
  { id: "codex", label: "Codex", icon: "openai" },
  { id: "gemini", label: "Gemini", icon: "gemini" },
  { id: "opencode", label: "OpenCode", icon: "opencode" },
  { id: "openclaw", label: "OpenClaw", icon: "openclaw" },
];

export function ModelsPanel() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [activeApp, setActiveApp] = useState<AppId>("claude");
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [editingProvider, setEditingProvider] = useState<Provider | null>(null);
  const [confirmAction, setConfirmAction] = useState<{
    provider: Provider;
    action: "remove" | "delete";
  } | null>(null);

  const effectiveEditingProvider = useLastValidValue(editingProvider);

  const {
    isRunning: isProxyRunning,
    takeoverStatus,
    status: proxyStatus,
  } = useProxyStatus();
  const isCurrentAppTakeoverActive = takeoverStatus?.[activeApp] || false;
  const activeProviderId = proxyStatus?.active_targets?.find(
    (t) => t.app_type === activeApp
  )?.provider_id;

  const { data, isLoading } = useProvidersQuery(activeApp, {
    isProxyRunning,
  });
  const providers = data?.providers ?? {};
  const currentProviderId = data?.currentProviderId ?? "";

  const {
    addProvider,
    updateProvider,
    switchProvider,
    deleteProvider,
  } = useProviderActions(activeApp);

  const handleEditProvider = async (provider: Provider) => {
    await updateProvider(provider);
    setEditingProvider(null);
  };

  const handleConfirmAction = async () => {
    if (!confirmAction) return;
    const { provider, action } = confirmAction;

    if (action === "remove") {
      await providersApi.removeFromLiveConfig(provider.id, activeApp);
      await queryClient.invalidateQueries({ queryKey: ["providers"] });
      toast.success(
        t("notifications.removeFromConfigSuccess", {
          defaultValue: "已从配置移除",
        })
      );
    } else {
      await deleteProvider(provider.id);
    }
    setConfirmAction(null);
  };

  const handleOpenWebsite = async (url: string) => {
    try {
      await settingsApi.openExternal(url);
    } catch (error) {
      toast.error(
        extractErrorMessage(error) ||
          t("notifications.openLinkFailed", { defaultValue: "链接打开失败" })
      );
    }
  };

  const handleDuplicateProvider = async (provider: Provider) => {
    const duplicatedProvider: Omit<Provider, "id" | "createdAt"> = {
      name: `${provider.name} copy`,
      settingsConfig: JSON.parse(JSON.stringify(provider.settingsConfig)),
      websiteUrl: provider.websiteUrl,
      category: provider.category,
      sortIndex: provider.sortIndex !== undefined ? provider.sortIndex + 1 : undefined,
      meta: provider.meta ? JSON.parse(JSON.stringify(provider.meta)) : undefined,
      icon: provider.icon,
      iconColor: provider.iconColor,
    };
    await addProvider(duplicatedProvider);
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold">
            {t("settings.models.title", { defaultValue: "模型管理" })}
          </h2>
          <p className="text-sm text-muted-foreground">
            {t("settings.models.description", {
              defaultValue: "管理所有 Agent 的模型配置",
            })}
          </p>
        </div>
        <Button
          onClick={() => setIsAddOpen(true)}
          size="sm"
          className="bg-orange-500 hover:bg-orange-600 text-white"
        >
          <Plus className="w-4 h-4 mr-1" />
          {t("common.add", { defaultValue: "添加" })}
        </Button>
      </div>

      {/* App Tabs */}
      <Tabs value={activeApp} onValueChange={(v) => setActiveApp(v as AppId)}>
        <TabsList className="w-full justify-start">
          {APP_TABS.map((app) => (
            <TabsTrigger key={app.id} value={app.id} className="gap-1.5">
              <ProviderIcon icon={app.icon} name={app.label} size={14} />
              {app.label}
            </TabsTrigger>
          ))}
        </TabsList>

        {APP_TABS.map((app) => (
          <TabsContent key={app.id} value={app.id} className="mt-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.2 }}
            >
              {isLoading ? (
                <div className="flex items-center justify-center py-8">
                  <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                </div>
              ) : (
                <ProviderList
                  providers={providers}
                  currentProviderId={currentProviderId}
                  appId={activeApp}
                  isLoading={isLoading}
                  isProxyRunning={isProxyRunning}
                  isProxyTakeover={isProxyRunning && isCurrentAppTakeoverActive}
                  activeProviderId={activeProviderId}
                  onSwitch={switchProvider}
                  onEdit={setEditingProvider}
                  onDelete={(provider) =>
                    setConfirmAction({ provider, action: "delete" })
                  }
                  onRemoveFromConfig={
                    activeApp === "opencode" || activeApp === "openclaw"
                      ? (provider) =>
                          setConfirmAction({ provider, action: "remove" })
                      : undefined
                  }
                  onDuplicate={handleDuplicateProvider}
                  onOpenWebsite={handleOpenWebsite}
                  onCreate={() => setIsAddOpen(true)}
                />
              )}
            </motion.div>
          </TabsContent>
        ))}
      </Tabs>

      {/* Add Provider Dialog */}
      <AddProviderDialog
        open={isAddOpen}
        onOpenChange={setIsAddOpen}
        appId={activeApp}
        onSubmit={addProvider}
      />

      {/* Edit Provider Dialog */}
      <EditProviderDialog
        open={Boolean(editingProvider)}
        provider={effectiveEditingProvider}
        onOpenChange={(open) => {
          if (!open) setEditingProvider(null);
        }}
        onSubmit={handleEditProvider}
        appId={activeApp}
        isProxyTakeover={isProxyRunning && isCurrentAppTakeoverActive}
      />

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={Boolean(confirmAction)}
        title={
          confirmAction?.action === "remove"
            ? t("confirm.removeProvider")
            : t("confirm.deleteProvider")
        }
        message={
          confirmAction
            ? confirmAction.action === "remove"
              ? t("confirm.removeProviderMessage", {
                  name: confirmAction.provider.name,
                })
              : t("confirm.deleteProviderMessage", {
                  name: confirmAction.provider.name,
                })
            : ""
        }
        onConfirm={() => void handleConfirmAction()}
        onCancel={() => setConfirmAction(null)}
      />
    </div>
  );
}