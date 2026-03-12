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
import { Textarea } from "@/components/ui/textarea";

interface FeishuConfig {
  appId?: string;
  appSecret?: string;
  verificationToken?: string;
  encryptKey?: string;
  autoApprovePolicy?: string;
}

interface DingTalkConfig {
  clientId?: string;
  clientSecret?: string;
  webhookSecret?: string;
  autoApprovePolicy?: string;
}

interface MoLiLiConfig {
  apiKey?: string;
  endpoint?: string;
}

interface ChannelsSettings {
  feishu?: {
    enabled: boolean;
    config: FeishuConfig;
  };
  dingtalk?: {
    enabled: boolean;
    config: DingTalkConfig;
  };
  molili?: {
    enabled: boolean;
    config: MoLiLiConfig;
  };
}

export const ChannelsPanel: React.FC = () => {
  const { t } = useTranslation();

  const { data, isLoading } = useOpenClawJsonSection<ChannelsSettings>(
    "channels",
    {},
  );
  const saveMutation = useSaveOpenClawJsonSection("channels");

  // Feishu State
  const [feishuEnabled, setFeishuEnabled] = useState(false);
  const [fsAppId, setFsAppId] = useState("");
  const [fsAppSecret, setFsAppSecret] = useState("");
  const [fsVerificationToken, setFsVerificationToken] = useState("");
  const [fsEncryptKey, setFsEncryptKey] = useState("");
  const [fsAutoApprove, setFsAutoApprove] = useState("");

  // DingTalk State
  const [dingtalkEnabled, setDingtalkEnabled] = useState(false);
  const [dtClientId, setDtClientId] = useState("");
  const [dtClientSecret, setDtClientSecret] = useState("");
  const [dtWebhookSecret, setDtWebhookSecret] = useState("");
  const [dtAutoApprove, setDtAutoApprove] = useState("");

  // MoLiLi State
  const [moliliEnabled, setMoliliEnabled] = useState(false);
  const [mlApiKey, setMlApiKey] = useState("");
  const [mlEndpoint, setMlEndpoint] = useState("");

  useEffect(() => {
    if (isLoading || !data) return;

    // Feishu
    setFeishuEnabled(data.feishu?.enabled ?? false);
    setFsAppId(data.feishu?.config?.appId || "");
    setFsAppSecret(data.feishu?.config?.appSecret || "");
    setFsVerificationToken(data.feishu?.config?.verificationToken || "");
    setFsEncryptKey(data.feishu?.config?.encryptKey || "");
    setFsAutoApprove(data.feishu?.config?.autoApprovePolicy || "[]");

    // DingTalk
    setDingtalkEnabled(data.dingtalk?.enabled ?? false);
    setDtClientId(data.dingtalk?.config?.clientId || "");
    setDtClientSecret(data.dingtalk?.config?.clientSecret || "");
    setDtWebhookSecret(data.dingtalk?.config?.webhookSecret || "");
    setDtAutoApprove(data.dingtalk?.config?.autoApprovePolicy || "[]");

    // MoLiLi
    setMoliliEnabled(data.molili?.enabled ?? false);
    setMlApiKey(data.molili?.config?.apiKey || "");
    setMlEndpoint(data.molili?.config?.endpoint || "");
  }, [data, isLoading]);

  const handleSave = async () => {
    try {
      // Basic validation for JSON policies
      try {
        JSON.parse(fsAutoApprove || "[]");
      } catch (e) {
        throw new Error(`Feishu Policy is invalid JSON`);
      }
      try {
        JSON.parse(dtAutoApprove || "[]");
      } catch (e) {
        throw new Error(`DingTalk Policy is invalid JSON`);
      }

      const updated: ChannelsSettings = {
        feishu: {
          enabled: feishuEnabled,
          config: {
            appId: fsAppId.trim(),
            appSecret: fsAppSecret.trim(),
            verificationToken: fsVerificationToken.trim(),
            encryptKey: fsEncryptKey.trim(),
            autoApprovePolicy: fsAutoApprove.trim(),
          },
        },
        dingtalk: {
          enabled: dingtalkEnabled,
          config: {
            clientId: dtClientId.trim(),
            clientSecret: dtClientSecret.trim(),
            webhookSecret: dtWebhookSecret.trim(),
            autoApprovePolicy: dtAutoApprove.trim(),
          },
        },
        molili: {
          enabled: moliliEnabled,
          config: {
            apiKey: mlApiKey.trim(),
            endpoint: mlEndpoint.trim() || undefined,
          },
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
    <div className="space-y-6 pb-[200px]">
      <div className="sticky top-0 z-10 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-zinc-50 dark:bg-zinc-950 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
        <div>
          <h2 className="text-lg font-semibold">
            {t("openclaw.channels.title")}
          </h2>
          <p className="text-sm text-zinc-500">
            {t("openclaw.channels.description")}
          </p>
        </div>
        <Button onClick={handleSave} disabled={saveMutation.isPending}>
          <Save className="w-4 h-4 mr-2" />
          {saveMutation.isPending ? t("common.saving") : t("common.save")}
        </Button>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Feishu Config */}
        <div className="space-y-4 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
          <div className="flex items-center justify-between pb-2 border-b border-zinc-200 dark:border-zinc-800">
            <h3 className="text-md font-medium">
              {t("openclaw.channels.feishu.title")}
            </h3>
            <Switch
              checked={feishuEnabled}
              onCheckedChange={setFeishuEnabled}
            />
          </div>

          <div className="space-y-4 pt-2">
            <div className="space-y-2">
              <Label htmlFor="fsAppId">
                {t("openclaw.channels.feishu.appId")}
              </Label>
              <Input
                id="fsAppId"
                value={fsAppId}
                onChange={(e) => setFsAppId(e.target.value)}
                placeholder="cli_..."
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="fsAppSecret">
                {t("openclaw.channels.feishu.appSecret")}
              </Label>
              <Input
                id="fsAppSecret"
                type="password"
                value={fsAppSecret}
                onChange={(e) => setFsAppSecret(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="fsVerificationToken">
                {t("openclaw.channels.feishu.verificationToken")}
              </Label>
              <Input
                id="fsVerificationToken"
                type="password"
                value={fsVerificationToken}
                onChange={(e) => setFsVerificationToken(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="fsEncryptKey">
                {t("openclaw.channels.feishu.encryptKey")}
              </Label>
              <Input
                id="fsEncryptKey"
                type="password"
                value={fsEncryptKey}
                onChange={(e) => setFsEncryptKey(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="fsAutoApprove">
                {t("openclaw.channels.common.autoApprovePolicy")}
              </Label>
              <Textarea
                id="fsAutoApprove"
                value={fsAutoApprove}
                onChange={(e) => setFsAutoApprove(e.target.value)}
                placeholder='[{"attribute": "type", "operator": "eq", "value": "internal"}]'
                className="font-mono text-xs min-h-[100px]"
              />
              <p className="text-xs text-zinc-500">
                {t("openclaw.channels.common.autoApprovePolicyHint")}
              </p>
            </div>
          </div>
        </div>

        {/* DingTalk Config */}
        <div className="space-y-4 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
          <div className="flex items-center justify-between pb-2 border-b border-zinc-200 dark:border-zinc-800">
            <h3 className="text-md font-medium">
              {t("openclaw.channels.dingtalk.title")}
            </h3>
            <Switch
              checked={dingtalkEnabled}
              onCheckedChange={setDingtalkEnabled}
            />
          </div>

          <div className="space-y-4 pt-2">
            <div className="space-y-2">
              <Label htmlFor="dtClientId">
                {t("openclaw.channels.dingtalk.clientId")}
              </Label>
              <Input
                id="dtClientId"
                value={dtClientId}
                onChange={(e) => setDtClientId(e.target.value)}
                placeholder="ding..."
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="dtClientSecret">
                {t("openclaw.channels.dingtalk.clientSecret")}
              </Label>
              <Input
                id="dtClientSecret"
                type="password"
                value={dtClientSecret}
                onChange={(e) => setDtClientSecret(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="dtWebhookSecret">
                {t("openclaw.channels.dingtalk.webhookSecret")}
              </Label>
              <Input
                id="dtWebhookSecret"
                type="password"
                value={dtWebhookSecret}
                onChange={(e) => setDtWebhookSecret(e.target.value)}
              />
            </div>
            <div className="space-y-2 h-[80px]" />{" "}
            {/* Spacer to align with Feishu */}
            <div className="space-y-2">
              <Label htmlFor="dtAutoApprove">
                {t("openclaw.channels.common.autoApprovePolicy")}
              </Label>
              <Textarea
                id="dtAutoApprove"
                value={dtAutoApprove}
                onChange={(e) => setDtAutoApprove(e.target.value)}
                placeholder='[{"attribute": "level", "operator": "lt", "value": 5}]'
                className="font-mono text-xs min-h-[100px]"
              />
              <p className="text-xs text-zinc-500">
                {t("openclaw.channels.common.autoApprovePolicyHint")}
              </p>
            </div>
          </div>
        </div>

        {/* MoLiLi Config */}
        <div className="space-y-4 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
          <div className="flex items-center justify-between pb-2 border-b border-zinc-200 dark:border-zinc-800">
            <h3 className="text-md font-medium">
              {t("openclaw.channels.molili.title")}
            </h3>
            <Switch
              checked={moliliEnabled}
              onCheckedChange={setMoliliEnabled}
            />
          </div>

          <div className="space-y-4 pt-2">
            <div className="space-y-2">
              <Label htmlFor="mlApiKey">
                {t("openclaw.channels.molili.apiKey")}
              </Label>
              <Input
                id="mlApiKey"
                type="password"
                value={mlApiKey}
                onChange={(e) => setMlApiKey(e.target.value)}
                placeholder="sk-..."
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="mlEndpoint">
                {t("openclaw.channels.molili.endpoint")}
              </Label>
              <Input
                id="mlEndpoint"
                value={mlEndpoint}
                onChange={(e) => setMlEndpoint(e.target.value)}
                placeholder="https://api.molili.com"
              />
              <p className="text-xs text-zinc-500">
                {t("openclaw.channels.molili.endpointHint")}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
