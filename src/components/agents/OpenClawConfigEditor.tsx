import { useState, useEffect, useCallback } from "react";
import { useTranslation } from "react-i18next";
import { invoke } from "@tauri-apps/api/core";
import { ArrowLeft, FolderOpen, Save, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import JsonEditor from "@/components/JsonEditor";
import { toast } from "sonner";
import { extractErrorMessage } from "@/utils/errorUtils";
import { settingsApi } from "@/lib/api";

interface OpenClawConfigEditorProps {
  onBack: () => void;
}

export function OpenClawConfigEditor({ onBack }: OpenClawConfigEditorProps) {
  const { t } = useTranslation();
  const [editorValue, setEditorValue] = useState<string>("{}");
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [configPath, setConfigPath] = useState<string>("");

  // Load config on mount
  useEffect(() => {
    const loadConfig = async () => {
      try {
        setIsLoading(true);
        const [content, path] = await Promise.all([
          invoke<string>("read_openclaw_json_raw"),
          settingsApi.getConfigDir("openclaw"),
        ]);
        setEditorValue(content || "{}");
        setConfigPath(path);
      } catch (error) {
        toast.error(
          t("openclaw.config.loadError", {
            defaultValue: "Failed to load config",
          }),
          { description: extractErrorMessage(error) },
        );
      } finally {
        setIsLoading(false);
      }
    };
    loadConfig();
  }, [t]);

  // Dark mode detection via MutationObserver
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

  const handleSave = useCallback(async () => {
    try {
      setIsSaving(true);
      await invoke("write_openclaw_json_raw", { content: editorValue });
      toast.success(
        t("openclaw.config.saveSuccess", {
          defaultValue: "Config saved successfully",
        }),
      );
    } catch (error) {
      toast.error(
        t("openclaw.config.saveError", {
          defaultValue: "Failed to save config",
        }),
        { description: extractErrorMessage(error) },
      );
    } finally {
      setIsSaving(false);
    }
  }, [editorValue, t]);

  const handleOpenDirectory = useCallback(async () => {
    try {
      await settingsApi.openConfigFolder("openclaw");
    } catch (error) {
      toast.error(
        t("openclaw.config.openDirError", {
          defaultValue: "Failed to open directory",
        }),
        { description: extractErrorMessage(error) },
      );
    }
  }, [t]);

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b bg-background/80 backdrop-blur-sm shrink-0">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="sm"
            onClick={onBack}
            className="gap-1.5"
          >
            <ArrowLeft className="w-4 h-4" />
            {t("common.back", { defaultValue: "Back" })}
          </Button>
          <div className="h-4 w-px bg-border" />
          <div>
            <h3 className="text-sm font-semibold">
              {t("openclaw.config.title", {
                defaultValue: "Edit OpenClaw Config",
              })}
            </h3>
            {configPath && (
              <p className="text-xs text-muted-foreground">{configPath}</p>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={handleOpenDirectory}
            className="gap-1.5"
          >
            <FolderOpen className="w-4 h-4" />
            {t("openclaw.config.openDir", { defaultValue: "Open Directory" })}
          </Button>
          <Button
            size="sm"
            onClick={handleSave}
            disabled={isSaving || isLoading}
            className="gap-1.5"
          >
            {isSaving ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Save className="w-4 h-4" />
            )}
            {isSaving
              ? t("common.saving", { defaultValue: "Saving..." })
              : t("common.save", { defaultValue: "Save" })}
          </Button>
        </div>
      </div>

      {/* Editor */}
      <div className="flex-1 min-h-0 p-4">
        {isLoading ? (
          <div className="flex items-center justify-center h-full">
            <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <div className="h-full rounded-lg border overflow-hidden">
            <JsonEditor
              value={editorValue}
              onChange={setEditorValue}
              darkMode={isDarkMode}
              height="100%"
              showValidation={true}
              language="json"
            />
          </div>
        )}
      </div>

      {/* Warning footer */}
      <div className="px-4 py-2 border-t bg-muted/50 shrink-0">
        <p className="text-xs text-muted-foreground">
          {t("openclaw.config.warning", {
            defaultValue:
              "Warning: Editing the config file directly may cause unexpected behavior. Make sure to backup your config before making changes.",
          })}
        </p>
      </div>
    </div>
  );
}

export default OpenClawConfigEditor;
