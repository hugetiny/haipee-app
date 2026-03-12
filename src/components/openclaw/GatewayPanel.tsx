import React, { useState, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { Save } from "lucide-react";
import { toast } from "sonner";
import {
  useOpenClawJsonSection,
  useSaveOpenClawJsonSection,
} from "@/hooks/useOpenClaw";
import { extractErrorMessage } from "@/utils/errorUtils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";

interface GatewaySettings {
  port?: number;
  bindMode?: "local" | "remote";
  customIp?: string;
  enableHttpChat?: boolean;
  authMode?: "none" | "token";
  token?: string;
  tailscale?: {
    mode?: "disabled" | "ephemeral" | "stateful";
    resetOnExit?: boolean;
    authKey?: string;
  };
}

export const GatewayPanel: React.FC = () => {
  const { t } = useTranslation();

  // Read current gateway section from openclaw.json
  const { data, isLoading } = useOpenClawJsonSection<GatewaySettings>(
    "gateway",
    {},
  );
  const saveMutation = useSaveOpenClawJsonSection("gateway");

  // Local state
  const [port, setPort] = useState<string>("8000");
  const [bindMode, setBindMode] = useState<"local" | "remote">("local");
  const [customIp, setCustomIp] = useState("");
  const [enableHttpChat, setEnableHttpChat] = useState(true);
  const [authMode, setAuthMode] = useState<"none" | "token">("none");
  const [token, setToken] = useState("");

  // Tailscale State
  const [tsMode, setTsMode] = useState<"disabled" | "ephemeral" | "stateful">(
    "disabled",
  );
  const [tsResetOnExit, setTsResetOnExit] = useState(false);
  const [tsAuthKey, setTsAuthKey] = useState("");

  useEffect(() => {
    if (isLoading || !data) return;

    setPort(data.port ? String(data.port) : "8000");
    setBindMode(data.bindMode || "local");
    setCustomIp(data.customIp || "");
    setEnableHttpChat(data.enableHttpChat ?? true);
    setAuthMode(data.authMode || "none");
    setToken(data.token || "");

    if (data.tailscale) {
      setTsMode(data.tailscale.mode || "disabled");
      setTsResetOnExit(data.tailscale.resetOnExit ?? false);
      setTsAuthKey(data.tailscale.authKey || "");
    }
  }, [data, isLoading]);

  const handleSave = async () => {
    try {
      const updated: GatewaySettings = {
        port: parseInt(port, 10) || 8000,
        bindMode,
        customIp: customIp.trim() || undefined,
        enableHttpChat,
        authMode,
        token: token.trim() || undefined,
        tailscale: {
          mode: tsMode,
          resetOnExit: tsResetOnExit,
          authKey: tsAuthKey.trim() || undefined,
        },
      };

      await saveMutation.mutateAsync(updated);
      toast.success(t("common.success"));
    } catch (e) {
      toast.error(t("common.saveFailed", { error: extractErrorMessage(e) }));
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center p-8 bg-zinc-50 dark:bg-zinc-900/50 rounded-lg">
        <span className="text-zinc-500">{t("common.loading")}</span>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-zinc-50 dark:bg-zinc-950 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
        <div>
          <h2 className="text-lg font-semibold">
            {t("openclaw.gateway.title")}
          </h2>
          <p className="text-sm text-zinc-500">
            {t("openclaw.gateway.description")}
          </p>
        </div>
        <Button onClick={handleSave} disabled={saveMutation.isPending}>
          <Save className="w-4 h-4 mr-2" />
          {saveMutation.isPending ? t("common.saving") : t("common.save")}
        </Button>
      </div>

      <div className="space-y-6 max-w-2xl">
        {/* Basic Network Settings */}
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="port">{t("openclaw.gateway.port")}</Label>
            <Input
              id="port"
              type="number"
              value={port}
              onChange={(e) => setPort(e.target.value)}
              placeholder="8000"
            />
            <p className="text-xs text-zinc-500">
              {t("openclaw.gateway.portHint")}
            </p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="bindMode">{t("openclaw.gateway.bindMode")}</Label>
            <Select
              value={bindMode}
              onValueChange={(v: "local" | "remote") => setBindMode(v)}
            >
              <SelectTrigger id="bindMode">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="local">
                  {t("openclaw.gateway.bindModeOptions.local")}
                </SelectItem>
                <SelectItem value="remote">
                  {t("openclaw.gateway.bindModeOptions.remote")}
                </SelectItem>
              </SelectContent>
            </Select>
            <p className="text-xs text-zinc-500">
              {t("openclaw.gateway.bindModeHint")}
            </p>
          </div>

          <div className="space-y-2 sm:col-span-2">
            <Label htmlFor="customIp">{t("openclaw.gateway.customIp")}</Label>
            <Input
              id="customIp"
              value={customIp}
              onChange={(e) => setCustomIp(e.target.value)}
              placeholder="0.0.0.0"
            />
            <p className="text-xs text-zinc-500">
              {t("openclaw.gateway.customIpHint")}
            </p>
          </div>
        </div>

        {/* Auth & Features */}
        <div className="grid gap-4 sm:grid-cols-2 pt-4 border-t border-zinc-200 dark:border-zinc-800">
          <div className="col-span-2 flex items-center justify-between">
            <div className="space-y-0.5">
              <Label>{t("openclaw.gateway.enableHttpChat")}</Label>
              <p className="text-xs text-zinc-500">
                {t("openclaw.gateway.enableHttpChatHint")}
              </p>
            </div>
            <Switch
              checked={enableHttpChat}
              onCheckedChange={setEnableHttpChat}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="authMode">{t("openclaw.gateway.authMode")}</Label>
            <Select
              value={authMode}
              onValueChange={(v: "none" | "token") => setAuthMode(v)}
            >
              <SelectTrigger id="authMode">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">
                  {t("openclaw.gateway.authModeOptions.none")}
                </SelectItem>
                <SelectItem value="token">
                  {t("openclaw.gateway.authModeOptions.token")}
                </SelectItem>
              </SelectContent>
            </Select>
            <p className="text-xs text-zinc-500">
              {t("openclaw.gateway.authModeHint")}
            </p>
          </div>

          {authMode === "token" && (
            <div className="space-y-2">
              <Label htmlFor="token">{t("openclaw.gateway.token")}</Label>
              <Input
                id="token"
                type="password"
                value={token}
                onChange={(e) => setToken(e.target.value)}
                placeholder="sk-..."
              />
              <p className="text-xs text-zinc-500">
                {t("openclaw.gateway.tokenHint")}
              </p>
            </div>
          )}
        </div>

        {/* Tailscale Integration */}
        <div className="space-y-4 pt-4 border-t border-zinc-200 dark:border-zinc-800">
          <div>
            <h3 className="text-md font-medium">
              {t("openclaw.gateway.tailscale")}
            </h3>
            <p className="text-xs text-zinc-500 mb-2">
              {t("openclaw.gateway.tailscaleHint")}
            </p>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="tsMode">{t("openclaw.gateway.tsMode")}</Label>
              <Select
                value={tsMode}
                onValueChange={(v: "disabled" | "ephemeral" | "stateful") =>
                  setTsMode(v)
                }
              >
                <SelectTrigger id="tsMode">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="disabled">
                    {t("openclaw.gateway.tsModeOptions.disabled")}
                  </SelectItem>
                  <SelectItem value="ephemeral">
                    {t("openclaw.gateway.tsModeOptions.ephemeral")}
                  </SelectItem>
                  <SelectItem value="stateful">
                    {t("openclaw.gateway.tsModeOptions.stateful")}
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>

            {(tsMode === "ephemeral" || tsMode === "stateful") && (
              <div className="space-y-2">
                <Label htmlFor="tsAuthKey">
                  {t("openclaw.gateway.tsAuthKey")}
                </Label>
                <Input
                  id="tsAuthKey"
                  type="password"
                  value={tsAuthKey}
                  onChange={(e) => setTsAuthKey(e.target.value)}
                  placeholder="tskey-auth-..."
                />
                <p className="text-xs text-zinc-500">
                  {t("openclaw.gateway.tsAuthKeyHint")}
                </p>
              </div>
            )}
          </div>

          {tsMode === "stateful" && (
            <div className="flex items-center space-x-2 mt-2">
              <Checkbox
                id="tsResetOnExit"
                checked={tsResetOnExit}
                onCheckedChange={(c) => setTsResetOnExit(c as boolean)}
              />
              <div className="grid gap-1.5 leading-none">
                <label
                  htmlFor="tsResetOnExit"
                  className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                >
                  {t("openclaw.gateway.tsResetOnExit")}
                </label>
                <p className="text-xs text-zinc-500">
                  {t("openclaw.gateway.tsResetOnExitHint")}
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
