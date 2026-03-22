import React from "react";
import { useTranslation } from "react-i18next";
import { useQuery } from "@tanstack/react-query";
import { Folder, Link, Server, Box } from "lucide-react";
import { openclawApi } from "@/lib/api/openclaw";

export const SkillsPluginsPanel: React.FC = () => {
  const { t } = useTranslation();

  // Fetch skills
  const { data: skills, isLoading: loadingSkills } = useQuery({
    queryKey: ["openclaw", "skills"],
    queryFn: () => openclawApi.listSkills(),
  });

  // Fetch providers
  const { data: providers, isLoading: loadingProviders } = useQuery({
    queryKey: ["openclaw", "providers"],
    queryFn: () => openclawApi.listProviders(),
  });

  const isLoading = loadingSkills || loadingProviders;

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
      </div>

      {/* Skills Section */}
      <div className="space-y-4 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
        <div className="flex items-center justify-between pb-2 border-b border-zinc-200 dark:border-zinc-800">
          <h3 className="text-md font-medium flex items-center gap-2">
            <Box className="w-4 h-4" />
            Skills ({skills?.length || 0})
          </h3>
        </div>

        {skills && skills.length > 0 ? (
          <div className="grid gap-2 max-h-[400px] overflow-y-auto">
            {skills.map((skill) => (
              <div
                key={skill.name}
                className="flex items-center justify-between p-3 rounded-md bg-zinc-100 dark:bg-zinc-800/50"
              >
                <div className="flex items-center gap-2 min-w-0">
                  <Folder className="w-4 h-4 text-zinc-500 shrink-0" />
                  <span className="truncate font-mono text-sm">{skill.name}</span>
                  {skill.isSymlink && (
                    <span title="Symlink">
                      <Link className="w-3 h-3 text-blue-500 shrink-0" />
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-sm text-zinc-500 italic p-4 text-center">
            No skills found
          </div>
        )}
      </div>

      {/* Providers Section */}
      <div className="space-y-4 p-4 rounded-lg border border-zinc-200 dark:border-zinc-800">
        <div className="flex items-center justify-between pb-2 border-b border-zinc-200 dark:border-zinc-800">
          <h3 className="text-md font-medium flex items-center gap-2">
            <Server className="w-4 h-4" />
            Providers ({providers?.length || 0})
          </h3>
        </div>

        {providers && providers.length > 0 ? (
          <div className="grid gap-2 max-h-[400px] overflow-y-auto">
            {providers.map((provider) => (
              <div
                key={provider.id}
                className="flex items-center justify-between p-3 rounded-md bg-zinc-100 dark:bg-zinc-800/50"
              >
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-medium truncate">{provider.name}</span>
                    <span className="text-xs text-zinc-500 font-mono">({provider.id})</span>
                  </div>
                  {provider.baseUrl && (
                    <div className="text-xs text-zinc-500 truncate mt-1">
                      {provider.baseUrl}
                    </div>
                  )}
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  {provider.apiType && (
                    <span className="text-xs px-2 py-0.5 rounded bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300">
                      {provider.apiType}
                    </span>
                  )}
                  {provider.modelsCount > 0 && (
                    <span className="text-xs px-2 py-0.5 rounded bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300">
                      {provider.modelsCount} models
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-sm text-zinc-500 italic p-4 text-center">
            No providers configured
          </div>
        )}
      </div>

      {/* Profile Info */}
      <div className="text-xs text-zinc-500 p-4 rounded-lg bg-zinc-100 dark:bg-zinc-800/30">
        <p>
          <strong>Profile:</strong> ~/.openclaw-haipee/
        </p>
        <p className="mt-1">
          Skills and providers are managed by OpenClaw. Use{" "}
          <code className="px-1 py-0.5 bg-zinc-200 dark:bg-zinc-700 rounded">
            openclaw --profile haipee skill install &lt;skill&gt;
          </code>{" "}
          to add new skills.
        </p>
      </div>
    </div>
  );
};