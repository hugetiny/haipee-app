import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { ArrowLeft, Save, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ProviderIcon } from "@/components/ProviderIcon";
import type { Provider } from "@/types";
import {
  ProviderForm,
  type ProviderFormValues,
} from "@/components/providers/forms/ProviderForm";
import { openclawApi, providersApi, vscodeApi, type AppId } from "@/lib/api";

interface ProviderEditViewProps {
  provider: Provider;
  appId: AppId;
  isProxyTakeover: boolean;
  onBack: () => void;
  onSave: (provider: Provider) => Promise<void>;
}

export function ProviderEditView({
  provider,
  appId,
  isProxyTakeover,
  onBack,
  onSave,
}: ProviderEditViewProps) {
  const { t } = useTranslation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [liveSettings, setLiveSettings] = useState<Record<
    string,
    unknown
  > | null>(null);
  const [hasLoadedLive, setHasLoadedLive] = useState(false);

  // Load live settings on mount
  useEffect(() => {
    let cancelled = false;

    const loadLiveSettings = async () => {
      // Skip if already loaded
      if (hasLoadedLive) return;

      // Proxy takeover mode: Live config has been rewritten by proxy,
      // reading live would show proxy address/placeholder content
      if (isProxyTakeover) {
        if (!cancelled) {
          setLiveSettings(null);
          setHasLoadedLive(true);
        }
        return;
      }

      // OpenCode uses additive mode - each provider's config is stored independently in DB
      // Reading live config would return the full opencode.json instead of just the provider fragment
      if (appId === "opencode") {
        if (!cancelled) {
          setLiveSettings(null);
          setHasLoadedLive(true);
        }
        return;
      }

      // OpenClaw: use dedicated API to get provider from live config
      if (appId === "openclaw") {
        try {
          const live = await openclawApi.getLiveProvider(provider.id);
          if (!cancelled && live && typeof live === "object") {
            setLiveSettings(live);
          } else if (!cancelled) {
            setLiveSettings(null);
          }
        } catch {
          if (!cancelled) {
            setLiveSettings(null);
          }
        } finally {
          if (!cancelled) {
            setHasLoadedLive(true);
          }
        }
        return;
      }

      // Other apps: check if this is the current provider, then load live settings
      try {
        const currentId = await providersApi.getCurrent(appId);
        if (currentId && provider.id === currentId) {
          try {
            const live = (await vscodeApi.getLiveProviderSettings(
              appId,
            )) as Record<string, unknown>;
            if (!cancelled && live && typeof live === "object") {
              setLiveSettings(live);
            }
          } catch {
            // Fall back to SSOT on error
            if (!cancelled) {
              setLiveSettings(null);
            }
          }
        }
      } catch {
        // Fall back to SSOT on error
        if (!cancelled) {
          setLiveSettings(null);
        }
      } finally {
        if (!cancelled) {
          setHasLoadedLive(true);
        }
      }
    };

    void loadLiveSettings();
    return () => {
      cancelled = true;
    };
  }, [provider.id, appId, hasLoadedLive, isProxyTakeover]);

  const initialSettingsConfig = useMemo(() => {
    return (liveSettings ?? provider.settingsConfig ?? {}) as Record<
      string,
      unknown
    >;
  }, [liveSettings, provider.settingsConfig]);

  const initialData = useMemo(() => {
    return {
      name: provider.name,
      notes: provider.notes,
      websiteUrl: provider.websiteUrl,
      settingsConfig: initialSettingsConfig,
      category: provider.category,
      meta: provider.meta,
      icon: provider.icon,
      iconColor: provider.iconColor,
    };
  }, [provider, initialSettingsConfig]);

  const handleSubmit = useCallback(
    async (values: ProviderFormValues) => {
      const parsedConfig = JSON.parse(values.settingsConfig) as Record<
        string,
        unknown
      >;

      const updatedProvider: Provider = {
        ...provider,
        name: values.name.trim(),
        notes: values.notes?.trim() || undefined,
        websiteUrl: values.websiteUrl?.trim() || undefined,
        settingsConfig: parsedConfig,
        icon: values.icon?.trim() || undefined,
        iconColor: values.iconColor?.trim() || undefined,
        ...(values.presetCategory ? { category: values.presetCategory } : {}),
        ...(values.meta ? { meta: values.meta } : {}),
      };

      setIsSubmitting(true);
      try {
        await onSave(updatedProvider);
        onBack();
      } finally {
        setIsSubmitting(false);
      }
    },
    [provider, onSave, onBack],
  );

  const handleCancel = useCallback(() => {
    onBack();
  }, [onBack]);

  return (
    <div className="flex flex-col h-full">
      {/* Header with Back button */}
      <div className="flex items-center gap-3 px-4 py-3 border-b bg-background/80 backdrop-blur-sm shrink-0">
        <Button
          variant="ghost"
          size="sm"
          onClick={onBack}
          className="gap-1.5"
        >
          <ArrowLeft className="h-4 w-4" />
          {t("common.back", { defaultValue: "返回" })}
        </Button>
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <ProviderIcon
            icon={provider.icon}
            name={provider.name}
            size={18}
          />
          <span className="font-medium truncate">{provider.name}</span>
        </div>
        <Button
          type="submit"
          form="provider-form"
          disabled={isSubmitting}
          size="sm"
          className="gap-1.5"
        >
          {isSubmitting ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          {t("common.save", { defaultValue: "保存" })}
        </Button>
      </div>

      {/* Form content - full height scrollable */}
      <div className="flex-1 overflow-y-auto p-4">
        {!hasLoadedLive ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <ProviderForm
            appId={appId}
            providerId={provider.id}
            submitLabel={t("common.save", { defaultValue: "保存" })}
            onSubmit={handleSubmit}
            onCancel={handleCancel}
            onSubmittingChange={setIsSubmitting}
            initialData={initialData}
            showButtons={false}
          />
        )}
      </div>
    </div>
  );
}