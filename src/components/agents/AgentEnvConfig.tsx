import { useTranslation } from "react-i18next";
import { Terminal } from "lucide-react";
import { SystemEnvSection } from "@/components/settings/SystemEnvSection";
import EnvPanel from "@/components/openclaw/EnvPanel";
import { getDefaultShellConfig } from "@/lib/api/env";
import { useState, useEffect, useCallback } from "react";

interface AgentEnvConfigProps {
  appId: AppId;
}

import type { AppId } from "@/lib/api";

const APP_ENV_CONFIGS: Record<AppId, { keywords: string[]; label: string }> = {
  claude: { keywords: ["ANTHROPIC"], label: "Claude Code" },
  codex: { keywords: ["OPENAI"], label: "Codex" },
  gemini: { keywords: ["GEMINI", "GOOGLE_GEMINI"], label: "Gemini CLI" },
  opencode: { keywords: ["OPENCODE"], label: "OpenCode" },
  openclaw: { keywords: [], label: "OpenClaw" },
};

export function AgentEnvConfig({ appId }: AgentEnvConfigProps) {
  const { t } = useTranslation();
  const [defaultShellConfig, setDefaultShellConfig] = useState<string>("");

  const loadDefaultConfig = useCallback(async () => {
    try {
      const config = await getDefaultShellConfig();
      setDefaultShellConfig(config);
    } catch (error) {
      console.error("Failed to get default shell config:", error);
    }
  }, []);

  useEffect(() => {
    loadDefaultConfig();
  }, [loadDefaultConfig]);

  const config = APP_ENV_CONFIGS[appId];

  // OpenClaw uses openclaw.json env field, not system env vars
  if (appId === "openclaw") {
    return (
      <div className="space-y-4">
        <div className="flex items-center gap-3">
          <Terminal className="h-5 w-5 text-primary" />
          <div>
            <h3 className="text-sm font-semibold">
              {t("openclaw.env.title", { defaultValue: "环境变量" })}
            </h3>
            <p className="text-xs text-muted-foreground">
              {t("openclaw.env.description", {
                defaultValue:
                  "OpenClaw 使用 openclaw.json 的 env 字段管理环境变量",
              })}
            </p>
          </div>
        </div>
        <EnvPanel />
      </div>
    );
  }

  // Other agents use system environment variables
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Terminal className="h-5 w-5 text-primary" />
        <div>
          <h3 className="text-sm font-semibold">
            {t("settings.envVar.title", { defaultValue: "系统环境变量" })}
          </h3>
          <p className="text-xs text-muted-foreground">
            {t("settings.envVar.description", {
              file: defaultShellConfig,
              defaultValue: `管理 ${config.label} 的环境变量 (${defaultShellConfig})`,
            })}
          </p>
        </div>
      </div>

      <SystemEnvSection
        appType={appId}
        appLabel={config.label}
        keywords={config.keywords}
        defaultShellConfig={defaultShellConfig}
      />
    </div>
  );
}
