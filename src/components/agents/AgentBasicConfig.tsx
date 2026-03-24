import { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { Loader2, Plus, FileJson } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ProviderList } from "@/components/providers/ProviderList";
import { AddProviderDialog } from "@/components/providers/AddProviderDialog";
import { ProviderEditView } from "@/components/agents/ProviderEditView";
import { OpenClawConfigEditor } from "@/components/agents/OpenClawConfigEditor";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { useProvidersQuery } from "@/lib/query";
import { useProviderActions } from "@/hooks/useProviderActions";
import { useProxyStatus } from "@/hooks/useProxyStatus";
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
  const [showConfigEditor, setShowConfigEditor] = useState(false);
  const [confirmAction, setConfirmAction] = useState<{
    provider: Provider;
    action: "remove" | "delete";
  } | null>(null);

  const {
    isRunning: isProxyRunning,
    status: proxyStatus,
  } = useProxyStatus();
  const activeProviderId = proxyStatus?.active_targets?.find(
    (t) => t.app_type === appId,
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

  const handleBackFromEdit = () => {
    setEditingProvider(null);
  };

  const handleBackFromConfigEditor = () => {
    setShowConfigEditor(false);
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
        }),
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
          t("notifications.openLinkFailed", { defaultValue: "链接打开失败" }),
      );
    }
  };

  const handleDuplicateProvider = async (provider: Provider) => {
    const duplicatedProvider: Omit<Provider, "id" | "createdAt"> = {
      name: `${provider.name} copy`,
      settingsConfig: JSON.parse(JSON.stringify(provider.settingsConfig)),
      websiteUrl: provider.websiteUrl,
      category: provider.category,
      sortIndex:
        provider.sortIndex !== undefined ? provider.sortIndex + 1 : undefined,
      meta: provider.meta
        ? JSON.parse(JSON.stringify(provider.meta))
        : undefined,
      icon: provider.icon,
      iconColor: provider.iconColor,
    };
    await addProvider(duplicatedProvider);
  };

  // Show OpenClaw config editor when showConfigEditor is true
  if (showConfigEditor && appId === "openclaw") {
    return <OpenClawConfigEditor onBack={handleBackFromConfigEditor} />;
  }

  // Show provider edit view when editing a provider
  if (editingProvider) {
    return (
      <ProviderEditView
        provider={editingProvider}
        appId={appId}
        isProxyTakeover={false}
        onBack={handleBackFromEdit}
        onSave={handleEditProvider}
      />
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header with Add button */}
      <div className="flex items-center justify-between px-1 shrink-0">
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
        <div className="flex items-center gap-2">
          {appId === "openclaw" && (
            <Button
              onClick={() => setShowConfigEditor(true)}
              size="sm"
              variant="outline"
              className="gap-1"
            >
              <FileJson className="w-3.5 h-3.5" />
              {t("openclaw.config.editConfig", { defaultValue: "编辑配置" })}
            </Button>
          )}
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
      </div>

      {/* Provider List */}
      <div className="flex-1 min-h-0 overflow-y-auto">
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
            isProxyTakeover={false}
            activeProviderId={activeProviderId}
            onSwitch={switchProvider}
            onEdit={setEditingProvider}
            onDelete={(provider) =>
              setConfirmAction({ provider, action: "delete" })
            }
            onRemoveFromConfig={
              appId === "opencode" || appId === "openclaw"
                ? (provider) => setConfirmAction({ provider, action: "remove" })
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
      </div>

      {/* Add Provider Dialog */}
      <AddProviderDialog
        open={isAddOpen}
        onOpenChange={setIsAddOpen}
        appId={appId}
        onSubmit={addProvider}
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
