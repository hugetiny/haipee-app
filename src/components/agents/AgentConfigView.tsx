import { useState } from "react";
import { useTranslation } from "react-i18next";
import { motion, AnimatePresence } from "framer-motion";
import { Settings2, Code2, Plug, FileText, Terminal } from "lucide-react";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ProviderIcon } from "@/components/ProviderIcon";
import type { AppId } from "@/lib/api";

import { AgentBasicConfig } from "./AgentBasicConfig";
import { AgentEnvConfig } from "./AgentEnvConfig";
import UnifiedSkillsPanel from "@/components/skills/UnifiedSkillsPanel";
import UnifiedMcpPanel from "@/components/mcp/UnifiedMcpPanel";
import PromptPanel from "@/components/prompts/PromptPanel";
import { OpenClawSkillsMcpPanel } from "@/components/openclaw/OpenClawSkillsMcpPanel";

const AGENT_TABS = [
  { id: "basic", labelKey: "agent.config.basic", labelFallback: "基础配置", icon: Settings2 },
  { id: "skills", labelKey: "agent.config.skills", labelFallback: "Skills", icon: Code2 },
  { id: "mcp", labelKey: "agent.config.mcp", labelFallback: "MCP", icon: Plug },
  { id: "prompts", labelKey: "agent.config.prompts", labelFallback: "提示词", icon: FileText },
  { id: "env", labelKey: "agent.config.env", labelFallback: "环境变量", icon: Terminal },
] as const;

const AGENT_OPTIONS: { id: AppId; label: string; icon: string }[] = [
  { id: "claude", label: "Claude", icon: "claude" },
  { id: "codex", label: "Codex", icon: "openai" },
  { id: "gemini", label: "Gemini", icon: "gemini" },
  { id: "opencode", label: "OpenCode", icon: "opencode" },
  { id: "openclaw", label: "OpenClaw", icon: "openclaw" },
];

export function AgentConfigView() {
  const { t } = useTranslation();
  const [activeApp, setActiveApp] = useState<AppId>("claude");
  const [activeTab, setActiveTab] = useState<string>("basic");

  return (
    <div className="flex flex-col h-full">
      {/* Agent Selector Header */}
      <div className="flex items-center gap-2 px-4 py-3 border-b bg-background/80 backdrop-blur-sm shrink-0">
        <span className="text-sm font-medium text-muted-foreground">
          {t("agent.config.selectAgent", { defaultValue: "选择 Agent" })}:
        </span>
        <div className="flex gap-1">
          {AGENT_OPTIONS.map((agent) => (
            <button
              key={agent.id}
              type="button"
              onClick={() => setActiveApp(agent.id)}
              data-testid={`agent-selector-${agent.id}`}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm transition-colors ${
                activeApp === agent.id
                  ? "bg-primary/10 text-primary"
                  : "text-muted-foreground hover:text-foreground hover:bg-muted"
              }`}
            >
              <ProviderIcon icon={agent.icon} name={agent.label} size={14} />
              <span>{agent.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div className="flex-1 min-h-0 overflow-hidden">
        <Tabs
          value={activeTab}
          onValueChange={setActiveTab}
          className="flex flex-col h-full"
        >
          <div className="px-4 pt-3 shrink-0">
            <TabsList className="w-full justify-start" data-testid="agent-tabs">
              {AGENT_TABS.map((tab) => (
                <TabsTrigger key={tab.id} value={tab.id} className="gap-1.5" data-testid={`agent-tab-${tab.id}`}>
                  <tab.icon className="w-3.5 h-3.5" />
                  {t(tab.labelKey, tab.labelFallback)}
                </TabsTrigger>
              ))}
            </TabsList>
          </div>

          <div className="flex-1 min-h-0 overflow-y-auto px-4 py-4">
            <AnimatePresence mode="wait">
              <motion.div
                key={`${activeApp}-${activeTab}`}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.15 }}
                className="h-full"
              >
                {activeTab === "basic" && (
                  <AgentBasicConfig appId={activeApp} />
                )}
                {activeTab === "skills" && (
                  activeApp === "openclaw" ? (
                    <OpenClawSkillsMcpPanel type="skills" />
                  ) : (
                    <UnifiedSkillsPanel
                      currentApp={activeApp}
                      onOpenDiscovery={() => {}}
                    />
                  )
                )}
                {activeTab === "mcp" && (
                  activeApp === "openclaw" ? (
                    <OpenClawSkillsMcpPanel type="mcp" />
                  ) : (
                    <UnifiedMcpPanel onOpenChange={() => {}} />
                  )
                )}
                {activeTab === "prompts" && (
                  <PromptPanel
                    open={true}
                    onOpenChange={() => {}}
                    appId={activeApp}
                  />
                )}
                {activeTab === "env" && (
                  <AgentEnvConfig appId={activeApp} />
                )}
              </motion.div>
            </AnimatePresence>
          </div>
        </Tabs>
      </div>
    </div>
  );
}