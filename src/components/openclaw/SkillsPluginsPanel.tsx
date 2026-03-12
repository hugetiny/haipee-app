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

interface SkillsSettings {
  installEnabled?: boolean;
  installDir?: string;
  codeExecEnabled?: boolean;
}

interface PluginsSettings {
  enabled?: boolean;
  directories?: string[];
}

export const SkillsPluginsPanel: React.FC = () => {
  const { t } = useTranslation();

  const { data: skillsData, isLoading: isLoadingSkills } =
    useOpenClawJsonSection<SkillsSettings>("skills", {});
  const { data: pluginsData, isLoading: isLoadingPlugins } =
    useOpenClawJsonSection<PluginsSettings>("plugins", {});

  const saveSkillsMutation = useSaveOpenClawJsonSection("skills");
  const savePluginsMutation = useSaveOpenClawJsonSection("plugins");

  // Skills State
  const [skillsInstallEnabled, setSkillsInstallEnabled] = useState(false);
  const [skillsInstallDir, setSkillsInstallDir] = useState("");
  const [skillsCodeExecEnabled, setSkillsCodeExecEnabled] = useState(true);

  // Plugins State
  const [pluginsEnabled, setPluginsEnabled] = useState(false);
  const [pluginsDirectories, setPluginsDirectories] = useState("[]");

  useEffect(() => {
    if (isLoadingSkills || !skillsData) return;
    setSkillsInstallEnabled(skillsData.installEnabled ?? true);
    setSkillsInstallDir(skillsData.installDir || "");
    setSkillsCodeExecEnabled(skillsData.codeExecEnabled ?? true);
  }, [skillsData, isLoadingSkills]);

  useEffect(() => {
    if (isLoadingPlugins || !pluginsData) return;
    setPluginsEnabled(pluginsData.enabled ?? false);
    setPluginsDirectories(
      JSON.stringify(pluginsData.directories || [], null, 2),
    );
  }, [pluginsData, isLoadingPlugins]);

  const handleSave = async () => {
    try {
      // Validate Plugin Directories JSON
      let parsedDirs: string[] = [];
      try {
        parsedDirs = JSON.parse(pluginsDirectories || "[]");
        if (!Array.isArray(parsedDirs)) throw new Error("Not an array");
      } catch (e) {
        throw new Error(
          "Plugin Directories must be a valid JSON array of strings.",
        );
      }

      const updatedSkills: SkillsSettings = {
        installEnabled: skillsInstallEnabled,
        installDir: skillsInstallDir.trim() || undefined,
        codeExecEnabled: skillsCodeExecEnabled,
      };

      const updatedPlugins: PluginsSettings = {
        enabled: pluginsEnabled,
        directories: parsedDirs.length > 0 ? parsedDirs : undefined,
      };

      await Promise.all([
        saveSkillsMutation.mutateAsync(updatedSkills),
        savePluginsMutation.mutateAsync(updatedPlugins),
      ]);

      toast.success(t("common.success"));
    } catch (e) {
      toast.error(t("common.saveFailed", { error: extractErrorMessage(e) }));
    }
  };

  const isLoading = isLoadingSkills || isLoadingPlugins;
  const isSaving =
    saveSkillsMutation.isPending || savePluginsMutation.isPending;

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
            {t("openclaw.skillsPlugins.title")}
          </h2>
          <p className="text-sm text-zinc-500">
            {t("openclaw.skillsPlugins.description")}
          </p>
        </div>
        <Button onClick={handleSave} disabled={isSaving}>
          <Save className="w-4 h-4 mr-2" />
          {isSaving ? t("common.saving") : t("common.save")}
        </Button>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Skills Config */}
        <div className="space-y-4 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
          <div className="flex items-center justify-between pb-2 border-b border-zinc-200 dark:border-zinc-800">
            <h3 className="text-md font-medium">
              {t("openclaw.skillsPlugins.skills.title")}
            </h3>
          </div>

          <div className="space-y-4 pt-2">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5 max-w-[80%]">
                <Label>
                  {t("openclaw.skillsPlugins.skills.installEnabled")}
                </Label>
                <p className="text-xs text-zinc-500">
                  {t("openclaw.skillsPlugins.skills.installEnabledHint")}
                </p>
              </div>
              <Switch
                checked={skillsInstallEnabled}
                onCheckedChange={setSkillsInstallEnabled}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="skillsInstallDir">
                {t("openclaw.skillsPlugins.skills.installDir")}
              </Label>
              <Input
                id="skillsInstallDir"
                value={skillsInstallDir}
                onChange={(e) => setSkillsInstallDir(e.target.value)}
                placeholder="/path/to/downloaded/skills"
              />
              <p className="text-xs text-zinc-500">
                {t("openclaw.skillsPlugins.skills.installDirHint")}
              </p>
            </div>

            <div className="flex items-center justify-between pt-2">
              <div className="space-y-0.5 max-w-[80%]">
                <Label>
                  {t("openclaw.skillsPlugins.skills.codeExecEnabled")}
                </Label>
                <p className="text-xs text-zinc-500">
                  {t("openclaw.skillsPlugins.skills.codeExecEnabledHint")}
                </p>
              </div>
              <Switch
                checked={skillsCodeExecEnabled}
                onCheckedChange={setSkillsCodeExecEnabled}
              />
            </div>
          </div>
        </div>

        {/* Plugins Config */}
        <div className="space-y-4 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
          <div className="flex items-center justify-between pb-2 border-b border-zinc-200 dark:border-zinc-800">
            <h3 className="text-md font-medium">
              {t("openclaw.skillsPlugins.plugins.title")}
            </h3>
            <Switch
              checked={pluginsEnabled}
              onCheckedChange={setPluginsEnabled}
            />
          </div>

          <div className="space-y-4 pt-2">
            <div className="space-y-2">
              <Label htmlFor="pluginsEnabledText">
                {t("openclaw.skillsPlugins.plugins.enabled")}
              </Label>
              <p className="text-xs text-zinc-500">
                {t("openclaw.skillsPlugins.plugins.enabledHint")}
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="pluginsDirectories">
                {t("openclaw.skillsPlugins.plugins.directories")}
              </Label>
              <Textarea
                id="pluginsDirectories"
                value={pluginsDirectories}
                onChange={(e) => setPluginsDirectories(e.target.value)}
                placeholder='["/path/to/local/plugins"]'
                className="font-mono text-xs min-h-[150px]"
              />
              <p className="text-xs text-zinc-500">
                {t("openclaw.skillsPlugins.plugins.directoriesHint")}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
