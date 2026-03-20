import { useState, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { Save, Loader2, FileJson, FolderOpen } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import JsonEditor from "@/components/JsonEditor";
import { invoke } from "@tauri-apps/api/core";
import type { AppId } from "@/lib/api";

interface AgentAdvancedConfigProps {
  appId: AppId;
}

export function AgentAdvancedConfig({ appId }: AgentAdvancedConfigProps) {
  const { t } = useTranslation();
  const [editorValue, setEditorValue] = useState<string>("");
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isDarkMode, setIsDarkMode] = useState(false);

  // Get config file path for display
  const getConfigInfo = () => {
    switch (appId) {
      case "claude":
        return {
          path: "~/.claude/settings.json",
          description: t("agent.config.claudeConfig", { defaultValue: "Claude Code 设置文件，包含 MCP、权限、主题等配置" }),
        };
      case "codex":
        return {
          path: "~/.codex/config.toml",
          description: t("agent.config.codexConfig", { defaultValue: "Codex 配置文件 (TOML 格式)" }),
        };
      case "gemini":
        return {
          path: "~/.gemini/settings.json",
          description: t("agent.config.geminiConfig", { defaultValue: "Gemini CLI 设置文件" }),
        };
      case "opencode":
        return {
          path: "~/.opencode/config.json",
          description: t("agent.config.opencodeConfig", { defaultValue: "OpenCode 配置文件" }),
        };
      case "openclaw":
        return {
          path: "~/.openclaw/openclaw.json",
          description: t("agent.config.openclawConfig", { defaultValue: "OpenClaw 配置文件 (JSON5 格式)，包含 providers、env、tools、mcp 等配置" }),
        };
      default:
        return {
          path: "",
          description: "",
        };
    }
  };

  const configInfo = getConfigInfo();

  // Load config content
  const loadConfig = async () => {
    setIsLoading(true);
    try {
      let content: string;

      if (appId === "openclaw") {
        content = await invoke<string>("read_openclaw_json_raw");
      } else {
        // For other apps, show a placeholder since we don't have direct file access commands
        content = JSON.stringify({
          _note: `Edit this file directly at ${configInfo.path}`,
          _hint: "Use the button below to open the config directory",
        }, null, 2);
      }

      setEditorValue(content || "{}");
    } catch (error) {
      console.error(`Failed to load ${appId} config:`, error);
      toast.error(
        t("agent.config.loadFailed", {
          defaultValue: "加载配置文件失败",
        })
      );
      setEditorValue("{}");
    } finally {
      setIsLoading(false);
    }
  };

  // Save config content (only for OpenClaw)
  const handleSave = async () => {
    if (appId !== "openclaw") {
      toast.info(
        t("agent.config.directEditHint", {
          defaultValue: "请直接编辑配置文件，点击下方按钮打开配置目录",
        })
      );
      return;
    }

    setIsSaving(true);
    try {
      await invoke("write_openclaw_json_raw", { content: editorValue });
      toast.success(
        t("agent.config.saveSuccess", { defaultValue: "配置已保存" })
      );
    } catch (error) {
      console.error(`Failed to save ${appId} config:`, error);
      toast.error(
        t("agent.config.saveFailed", {
          error: error instanceof Error ? error.message : String(error),
          defaultValue: "保存配置失败: {{error}}",
        })
      );
    } finally {
      setIsSaving(false);
    }
  };

  // Open config directory
  const handleOpenConfigDir = async () => {
    try {
      const configDirs: Record<AppId, string> = {
        claude: "~/.claude",
        codex: "~/.codex",
        gemini: "~/.gemini",
        opencode: "~/.opencode",
        openclaw: "~/.openclaw",
      };
      const dir = configDirs[appId];
      await invoke("reveal_in_finder", { path: dir });
    } catch (error) {
      console.error("Failed to open config dir:", error);
      toast.error(
        t("agent.config.openDirFailed", { defaultValue: "打开配置目录失败" })
      );
    }
  };

  useEffect(() => {
    loadConfig();
  }, [appId]);

  useEffect(() => {
    setIsDarkMode(document.documentElement.classList.contains("dark"));

    const observer = new MutationObserver(() => {
      setIsDarkMode(document.documentElement.classList.contains("dark"));
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });

    return () => observer.disconnect();
  }, []);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <FileJson className="h-5 w-5 text-primary" />
          <div>
            <h3 className="text-sm font-semibold">
              {t("agent.config.advancedSettings", { defaultValue: "高级设置" })}
            </h3>
            <p className="text-xs text-muted-foreground">
              {configInfo.description}
            </p>
            <p className="text-xs text-muted-foreground font-mono mt-1">
              {configInfo.path}
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <Button
            onClick={handleOpenConfigDir}
            size="sm"
            variant="outline"
            className="gap-1"
          >
            <FolderOpen className="w-3.5 h-3.5" />
            {t("agent.config.openDir", { defaultValue: "打开目录" })}
          </Button>
          {appId === "openclaw" && (
            <Button
              onClick={handleSave}
              disabled={isSaving}
              size="sm"
              className="gap-1"
            >
              {isSaving ? (
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Save className="w-3.5 h-3.5" />
              )}
              {t("common.save", { defaultValue: "保存" })}
            </Button>
          )}
        </div>
      </div>

      {/* JSON Editor */}
      <div className="border rounded-lg overflow-hidden">
        <JsonEditor
          value={editorValue}
          onChange={appId === "openclaw" ? setEditorValue : () => {}}
          height="400px"
          darkMode={isDarkMode}
        />
      </div>

      {/* Warning */}
      <div className="rounded-lg bg-amber-500/10 border border-amber-500/20 p-3">
        <p className="text-xs text-amber-600 dark:text-amber-400">
          {appId === "openclaw"
            ? t("agent.config.advancedWarning", {
                defaultValue:
                  "直接编辑配置文件可能会影响应用行为，请确保您了解正在修改的内容。保存前请备份重要数据。",
              })
            : t("agent.config.viewOnlyHint", {
                defaultValue:
                  "此视图为只读模式。请使用上方按钮打开配置目录，使用您喜欢的编辑器修改配置文件。",
              })}
        </p>
      </div>
    </div>
  );
}