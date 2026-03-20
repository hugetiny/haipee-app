import { useState, useEffect, useCallback } from "react";
import { useTranslation } from "react-i18next";
import { Terminal, Loader2 } from "lucide-react";
import { SystemEnvSection } from "./SystemEnvSection";
import { getDefaultShellConfig } from "@/lib/api/env";

const APP_CONFIGS = [
  { appType: "claude", keywords: ["ANTHROPIC"] },
  { appType: "codex", keywords: ["OPENAI"] },
  { appType: "gemini", keywords: ["GEMINI", "GOOGLE_GEMINI"] },
  { appType: "opencode", keywords: ["OPENCODE"] },
] as const;

export function SystemEnvPanel() {
  const { t } = useTranslation();
  const [defaultShellConfig, setDefaultShellConfig] = useState<string>("");
  const [isLoading, setIsLoading] = useState(true);

  const loadDefaultConfig = useCallback(async () => {
    try {
      const config = await getDefaultShellConfig();
      setDefaultShellConfig(config);
    } catch (error) {
      console.error("Failed to get default shell config:", error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadDefaultConfig();
  }, [loadDefaultConfig]);

  const getAppLabel = (appType: string): string => {
    switch (appType) {
      case "claude":
        return "Claude Code";
      case "codex":
        return "Codex";
      case "gemini":
        return "Gemini CLI";
      case "opencode":
        return "OpenCode";
      default:
        return appType;
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Terminal className="h-5 w-5 text-primary" />
        <div>
          <h2 className="text-base font-semibold">
            {t("settings.envVar.title", { defaultValue: "系统环境变量管理" })}
          </h2>
          <p className="text-sm text-muted-foreground">
            {t("settings.envVar.description", {
              file: defaultShellConfig,
              defaultValue: `管理 shell 配置文件中的环境变量 (${defaultShellConfig})`,
            })}
          </p>
        </div>
      </div>

      {/* Note about OpenClaw */}
      <div className="rounded-lg bg-muted/30 border border-border/50 p-4">
        <p className="text-sm text-muted-foreground">
          {t("settings.envVar.openclawNote", {
            defaultValue:
              "OpenClaw 使用配置文件管理设置，不支持系统环境变量，因此不在列表中显示。",
          })}
        </p>
      </div>

      {/* App Sections */}
      <div className="space-y-3">
        {APP_CONFIGS.map((config) => (
          <SystemEnvSection
            key={config.appType}
            appType={config.appType}
            appLabel={getAppLabel(config.appType)}
            keywords={config.keywords as unknown as string[]}
            defaultShellConfig={defaultShellConfig}
          />
        ))}
      </div>

      {/* Warning */}
      <div className="rounded-lg bg-amber-500/10 border border-amber-500/20 p-4">
        <p className="text-sm text-amber-600 dark:text-amber-400">
          {t("settings.envVar.warning", {
            defaultValue:
              "注意：修改环境变量后，需要重新启动终端或应用程序才能生效。部分应用可能需要在新的终端会话中才能读取到更新后的环境变量。",
          })}
        </p>
      </div>
    </div>
  );
}