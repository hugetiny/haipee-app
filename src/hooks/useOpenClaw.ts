import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { openclawApi } from "@/lib/api/openclaw";
import { providersApi } from "@/lib/api/providers";
import { useSettingsQuery } from "@/lib/query";
import type {
  OpenClawEnvConfig,
  OpenClawToolsConfig,
  OpenClawAgentsDefaults,
} from "@/types";

/**
 * Centralized query keys for all OpenClaw-related queries.
 * Import this from any file that needs to invalidate OpenClaw caches.
 */
export const openclawKeys = {
  all: ["openclaw"] as const,
  liveProviderIds: (instanceId: string) =>
    ["openclaw", instanceId, "liveProviderIds"] as const,
  defaultModel: (instanceId: string) =>
    ["openclaw", instanceId, "defaultModel"] as const,
  env: (instanceId: string) => ["openclaw", instanceId, "env"] as const,
  tools: (instanceId: string) => ["openclaw", instanceId, "tools"] as const,
  agentsDefaults: (instanceId: string) =>
    ["openclaw", instanceId, "agentsDefaults"] as const,
  health: (instanceId: string) => ["openclaw", instanceId, "health"] as const,
  jsonSection: (instanceId: string, section: string) =>
    ["openclaw", instanceId, "jsonSection", section] as const,
  rawJson: (instanceId: string) => ["openclaw", instanceId, "rawJson"] as const,
};

/**
 * Helper hook to get the active OpenClaw instance from settings.
 */
export function useActiveOpenClawInstance() {
  const { data: settings } = useSettingsQuery();
  const instanceId = settings?.currentOpenClawInstanceId ?? "default";
  const instances = settings?.openclawInstances ?? [
    { id: "default", name: "Local", type: "local" },
  ];
  const activeInstance =
    instances.find((i) => i.id === instanceId) ?? instances[0];
  return { activeInstance, instanceId, allInstances: instances };
}

// ============================================================
// Query hooks
// ============================================================

/**
 * Query live provider IDs from openclaw.json config.
 * Used by ProviderList to show "In Config" badge.
 */
export function useOpenClawLiveProviderIds(enabled: boolean) {
  const { instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.liveProviderIds(instanceId),
    queryFn: () => providersApi.getOpenClawLiveProviderIds(),
    enabled,
  });
}

/**
 * Query the default model from agents.defaults.model.
 * Used by ProviderList to show which provider is the default.
 */
export function useOpenClawDefaultModel(enabled: boolean) {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.defaultModel(instanceId),
    queryFn: () => openclawApi.getDefaultModel(activeInstance),
    enabled,
  });
}

/**
 * Query env section of openclaw.json.
 */
export function useOpenClawEnv() {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.env(instanceId),
    queryFn: () => openclawApi.getEnv(activeInstance),
    staleTime: 30_000,
  });
}

/**
 * Query tools section of openclaw.json.
 */
export function useOpenClawTools() {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.tools(instanceId),
    queryFn: () => openclawApi.getTools(activeInstance),
    staleTime: 30_000,
  });
}

/**
 * Query agents.defaults section of openclaw.json.
 */
export function useOpenClawAgentsDefaults() {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.agentsDefaults(instanceId),
    queryFn: () => openclawApi.getAgentsDefaults(activeInstance),
    staleTime: 30_000,
  });
}

export function useOpenClawHealth(enabled: boolean) {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.health(instanceId),
    queryFn: () => openclawApi.scanHealth(activeInstance),
    staleTime: 30_000,
    enabled,
  });
}

/**
 * Ping the active OpenClaw instance for connection status.
 * Only useful for remote instances. Refreshes every 30s.
 */
export function useOpenClawPing() {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  const isRemote = activeInstance?.type === "remote";
  return useQuery({
    queryKey: ["openclaw", instanceId, "ping"] as const,
    queryFn: () => openclawApi.ping(activeInstance),
    refetchInterval: isRemote ? 30_000 : false,
    enabled: isRemote,
    staleTime: 10_000,
  });
}

/**
 * Query generic JSON section
 */
export function useOpenClawJsonSection<T = any>(
  section: string,
  defaultValue: T,
) {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.jsonSection(instanceId, section),
    queryFn: async () => {
      const data = await openclawApi.getJsonSection(section, activeInstance);
      return data === null ? defaultValue : data;
    },
    staleTime: 30_000,
  });
}

/**
 * Query raw JSON
 */
export function useOpenClawRawJson() {
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useQuery({
    queryKey: openclawKeys.rawJson(instanceId),
    queryFn: () => openclawApi.readJsonRaw(activeInstance),
    staleTime: 30_000,
  });
}

// ============================================================
// Mutation hooks
// ============================================================

/**
 * Save env config. Invalidates env query on success.
 * Toast notifications are handled by the component.
 */
export function useSaveOpenClawEnv() {
  const queryClient = useQueryClient();
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useMutation({
    mutationFn: (env: OpenClawEnvConfig) =>
      openclawApi.setEnv(env, activeInstance),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: openclawKeys.env(instanceId) });
      queryClient.invalidateQueries({
        queryKey: openclawKeys.health(instanceId),
      });
    },
  });
}

/**
 * Save tools config. Invalidates tools query on success.
 * Toast notifications are handled by the component.
 */
export function useSaveOpenClawTools() {
  const queryClient = useQueryClient();
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useMutation({
    mutationFn: (tools: OpenClawToolsConfig) =>
      openclawApi.setTools(tools, activeInstance),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: openclawKeys.tools(instanceId),
      });
      queryClient.invalidateQueries({
        queryKey: openclawKeys.health(instanceId),
      });
    },
  });
}

/**
 * Save agents.defaults config. Invalidates both agentsDefaults and defaultModel
 * queries on success (since changing agents.defaults may affect the default model).
 * Toast notifications are handled by the component.
 */
export function useSaveOpenClawAgentsDefaults() {
  const queryClient = useQueryClient();
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useMutation({
    mutationFn: (defaults: OpenClawAgentsDefaults) =>
      openclawApi.setAgentsDefaults(defaults, activeInstance),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: openclawKeys.agentsDefaults(instanceId),
      });
      queryClient.invalidateQueries({
        queryKey: openclawKeys.defaultModel(instanceId),
      });
      queryClient.invalidateQueries({
        queryKey: openclawKeys.health(instanceId),
      });
    },
  });
}

/**
 * Save generic JSON section. Invalidates generic JSON query.
 * Toast notifications are handled by the component.
 */
export function useSaveOpenClawJsonSection(section: string) {
  const queryClient = useQueryClient();
  const { activeInstance, instanceId } = useActiveOpenClawInstance();
  return useMutation({
    mutationFn: (value: any) =>
      openclawApi.setJsonSection(section, value, activeInstance),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: openclawKeys.jsonSection(instanceId, section),
      });
      queryClient.invalidateQueries({
        queryKey: openclawKeys.rawJson(instanceId),
      });
      queryClient.invalidateQueries({
        queryKey: openclawKeys.health(instanceId),
      });
    },
  });
}

/**
 * Save raw openclaw json. Invalidates everything openclaw related.
 */
export function useSaveOpenClawRawJson() {
  const queryClient = useQueryClient();
  const { activeInstance } = useActiveOpenClawInstance();
  return useMutation({
    mutationFn: (content: string) =>
      openclawApi.writeJsonRaw(content, activeInstance),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: openclawKeys.all });
    },
  });
}
