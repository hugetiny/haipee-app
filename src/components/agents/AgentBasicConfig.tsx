import { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { Loader2, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
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
import { useState } from "react";

interface AgentBasicConfigProps {
  appId: AppId;
}

export function AgentBasicConfig({ appId }: AgentBasicConfigProps) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
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
  const isCurrentAppTakeoverActive = takeoverStatus?.[appId] || false;
  const activeProviderId = proxyStatus?.active_targets?.find(
    (t) => t.app_type === appId
  )?.provider_id;

  const { data, isLoading } = useProvidersQuery(appId, {
    isProxyRunning,
  });
  const providers = useMemo(() => data?.providers ?? {}, [data]);
  const currentProviderId = data?.currentProviderId ?? "";

  const {
    addProvider,
    updateProvider,
    switchProvider,
    deleteProvider,
    setAsDefaultModel,
  } = useProviderActions(appId);

  const handleEditProvider = async (provider: Provider) => {
    await updateProvider(provider);
    setEditingProvider(null);
  };

  const handleConfirmAction = async () => {
    if (!confirmAction) return;
    const { provider, action } = confirmAction;

    if (action === "remove") {
      await providersApi.removeFromLiveConfig(provider.id, appId);
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
      {/* Header with Add button */}
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-sm font-semibold">
            {t("agent.config.models", { defaultValue: "模型配置" })}
          </h3>
          <p className="text-xs text-muted-foreground">
            {t("agent.config.modelsDescription", {
              defaultValue: "管理此 Agent 的模型，切换当前使用的模型",
            })}
          </p>
        </div>
        <Button
          onClick={() => setIsAddOpen(true)}
          size="sm"
          variant="outline"
          className="gap-1"
        >
          <Plus className="w-3.5 h-3.5" />
          {t("common.add", { defaultValue: "添加" })}
        </Button>
      </div>

      {/* Provider List */}
      {isLoading ? (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
        </div>
      ) : (
        <ProviderList
          providers={providers}
          currentProviderId={currentProviderId}
          appId={appId}
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
            appId === "opencode" || appId === "openclaw"
              ? (provider) =>
                  setConfirmAction({ provider, action: "remove" })
              : undefined
          }
          onDuplicate={handleDuplicateProvider}
          onOpenWebsite={handleOpenWebsite}
          onCreate={() => setIsAddOpen(true)}
          onSetAsDefault={
            appId === "openclaw" ? setAsDefaultModel : undefined
          }
        />
      )}

      {/* Add Provider Dialog */}
      <AddProviderDialog
        open={isAddOpen}
        onOpenChange={setIsAddOpen}
        appId={appId}
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
        appId={appId}
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