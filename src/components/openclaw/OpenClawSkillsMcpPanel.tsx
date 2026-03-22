import React from "react";
import { useTranslation } from "react-i18next";
import { useQuery } from "@tanstack/react-query";
import { Folder, Link, Server, Box, AlertCircle } from "lucide-react";
import { openclawApi } from "@/lib/api/openclaw";

interface OpenClawSkillsMcpPanelProps {
  type: "skills" | "mcp";
}

export const OpenClawSkillsMcpPanel: React.FC<OpenClawSkillsMcpPanelProps> = ({
  type,
}) => {
  const { t } = useTranslation();

  // Fetch skills
  const { data: skills, isLoading: loadingSkills } = useQuery({
    queryKey: ["openclaw", "skills"],
    queryFn: () => openclawApi.listSkills(),
  });

  // Fetch MCP servers
  const { data: mcpServers, isLoading: loadingMcp } = useQuery({
    queryKey: ["openclaw", "mcp-servers"],
    queryFn: () => openclawApi.listMcpServers(),
  });

  // Check if MCP is enabled
  const { data: mcpEnabled } = useQuery({
    queryKey: ["openclaw", "mcp-enabled"],
    queryFn: () => openclawApi.isMcpEnabled(),
  });

  if (type === "mcp") {
    const isLoading = loadingMcp;

    return (
      <div className="px-6 flex flex-col flex-1 min-h-0 overflow-hidden">
        <div className="flex items-center justify-between pb-4 border-b border-border-default">
          <div className="flex items-center gap-3">
            <Server className="w-5 h-5 text-primary" />
            <div>
              <h3 className="font-semibold">
                {t("openclaw.mcp.title", { defaultValue: "MCP Servers" })}
              </h3>
              <p className="text-sm text-muted-foreground">
                {t("openclaw.mcp.description", {
                  defaultValue:
                    "OpenClaw MCP servers (mcp.servers)",
                })}
              </p>
            </div>
          </div>
          {mcpServers && mcpServers.length > 0 && (
            <span className="text-sm text-muted-foreground">
              {mcpServers.length} servers
            </span>
          )}
        </div>

        <div className="flex-1 overflow-y-auto py-4">
          {isLoading ? (
            <div className="text-center py-12 text-muted-foreground">
              {t("common.loading")}
            </div>
          ) : !mcpEnabled ? (
            <div className="text-center py-12">
              <div className="w-16 h-16 mx-auto mb-4 bg-muted rounded-full flex items-center justify-center">
                <AlertCircle size={24} className="text-muted-foreground" />
              </div>
              <h3 className="text-lg font-medium text-foreground mb-2">
                {t("openclaw.mcp.disabled", { defaultValue: "MCP 功能未启用" })}
              </h3>
              <p className="text-muted-foreground text-sm mb-4">
                {t("openclaw.mcp.disabledHint", {
                  defaultValue: "在 openclaw.json 中设置 commands.mcp: true 以启用 MCP",
                })}
              </p>
              <div className="bg-muted/30 rounded-md p-3 font-mono text-xs text-left max-w-md mx-auto">
                <div className="text-muted-foreground"># 启用 MCP</div>
                <div>{`"commands": {`}</div>
                <div className="pl-4">{`"mcp": true`}</div>
                <div>{`}`}</div>
              </div>
            </div>
          ) : !mcpServers || mcpServers.length === 0 ? (
            <div className="text-center py-12">
              <div className="w-16 h-16 mx-auto mb-4 bg-muted rounded-full flex items-center justify-center">
                <Server size={24} className="text-muted-foreground" />
              </div>
              <h3 className="text-lg font-medium text-foreground mb-2">
                {t("openclaw.mcp.noServers", { defaultValue: "没有配置 MCP Servers" })}
              </h3>
              <p className="text-muted-foreground text-sm mb-4">
                {t("openclaw.mcp.emptyHint", {
                  defaultValue: "使用 /mcp 命令添加 MCP servers",
                })}
              </p>
              <div className="bg-muted/30 rounded-md p-3 font-mono text-xs text-left max-w-md mx-auto">
                <div className="text-muted-foreground"># 添加 MCP server</div>
                <div>{`/mcp set context7={"command":"uvx","args":["context7-mcp"]}`}</div>
              </div>
            </div>
          ) : (
            <div className="rounded-xl border border-border-default overflow-hidden">
              {mcpServers.map((server, index) => (
                <div
                  key={server.id}
                  className={`p-4 hover:bg-muted/30 transition-colors ${
                    index !== mcpServers.length - 1
                      ? "border-b border-border-default"
                      : ""
                  }`}
                >
                  <div className="flex items-center gap-2 mb-2">
                    <Server className="w-4 h-4 text-muted-foreground" />
                    <span className="font-mono font-medium">{server.id}</span>
                  </div>
                  {server.command && (
                    <div className="text-sm text-muted-foreground ml-6">
                      <span className="text-xs font-medium">command:</span>{" "}
                      <span className="font-mono">{server.command}</span>
                      {server.args && server.args.length > 0 && (
                        <span className="font-mono ml-1">
                          {server.args.join(" ")}
                        </span>
                      )}
                    </div>
                  )}
                  {server.url && (
                    <div className="text-sm text-muted-foreground ml-6">
                      <span className="text-xs font-medium">url:</span>{" "}
                      <span className="font-mono">{server.url}</span>
                    </div>
                  )}
                  {server.env && Object.keys(server.env).length > 0 && (
                    <div className="text-sm text-muted-foreground ml-6">
                      <span className="text-xs font-medium">env:</span>{" "}
                      <span className="font-mono text-xs">
                        {Object.keys(server.env).join(", ")}
                      </span>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Info footer */}
        <div className="text-xs text-muted-foreground p-3 rounded-lg bg-muted/30 border border-border-default mt-2">
          <p>
            {t("openclaw.mcp.manageHint", {
              defaultValue: "使用 /mcp 命令管理 MCP servers（OpenClaw 配置，非项目级）",
            })}
          </p>
        </div>
      </div>
    );
  }

  // Skills panel
  return (
    <div className="px-6 flex flex-col flex-1 min-h-0 overflow-hidden">
      <div className="flex items-center justify-between pb-4 border-b border-border-default">
        <div className="flex items-center gap-3">
          <Box className="w-5 h-5 text-primary" />
          <div>
            <h3 className="font-semibold">
              {t("openclaw.skills.title", { defaultValue: "OpenClaw Skills" })}
            </h3>
            <p className="text-sm text-muted-foreground">
              {t("openclaw.skills.description", {
                defaultValue:
                  "已安装的 Skills 来自 ~/.openclaw-haipee/skills/",
              })}
            </p>
          </div>
        </div>
        <span className="text-sm text-muted-foreground">
          {skills?.length || 0} {t("skills.installed", { count: skills?.length || 0 })}
        </span>
      </div>

      <div className="flex-1 overflow-y-auto py-4">
        {loadingSkills ? (
          <div className="text-center py-12 text-muted-foreground">
            {t("common.loading")}
          </div>
        ) : !skills || skills.length === 0 ? (
          <div className="text-center py-12">
            <div className="w-16 h-16 mx-auto mb-4 bg-muted rounded-full flex items-center justify-center">
              <Box size={24} className="text-muted-foreground" />
            </div>
            <h3 className="text-lg font-medium text-foreground mb-2">
              {t("skills.noInstalled")}
            </h3>
            <p className="text-muted-foreground text-sm">
              {t("openclaw.skills.emptyHint", {
                defaultValue:
                  "使用 'openclaw --profile haipee skill install <skill>' 安装新的 skills",
              })}
            </p>
          </div>
        ) : (
          <div className="rounded-xl border border-border-default overflow-hidden">
            {skills.map((skill, index) => (
              <div
                key={skill.name}
                className={`flex items-center justify-between p-4 hover:bg-muted/30 transition-colors group ${
                  index !== skills.length - 1
                    ? "border-b border-border-default"
                    : ""
                }`}
              >
                <div className="flex items-center gap-3 min-w-0">
                  <Folder className="w-4 h-4 text-muted-foreground shrink-0" />
                  <span className="truncate font-mono text-sm">
                    {skill.name}
                  </span>
                  {skill.isSymlink && (
                    <span
                      title="Symlink"
                      className="text-blue-500 shrink-0"
                    >
                      <Link className="w-3 h-3" />
                    </span>
                  )}
                </div>
                <div className="text-xs text-muted-foreground truncate max-w-[200px]">
                  {skill.isDirectory ? t("skills.directory", { defaultValue: "目录" }) : t("skills.file", { defaultValue: "文件" })}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Info footer */}
      <div className="text-xs text-muted-foreground p-3 rounded-lg bg-muted/30 border border-border-default mt-2">
        <p>
          <strong>Profile:</strong> ~/.openclaw-haipee/
        </p>
        <p className="mt-1">
          {t("openclaw.skills.manageHint", {
            defaultValue:
              "使用 openclaw --profile haipee skill install <skill> 安装新的 skills",
          })}
        </p>
      </div>
    </div>
  );
};