import { useState, useEffect, useMemo, useCallback } from 'react';
import { getAllConfigStatuses, type AllConfigStatuses } from '@/lib/api/config';
import type { AppId } from '@/lib/api/types';

const ALL_APPS: AppId[] = ['claude', 'codex', 'gemini', 'opencode', 'openclaw'];

const STORAGE_KEY = 'haipee-selected-agent';

type AgentStatus =
  | { type: 'loading' }
  | { type: 'success'; exists: boolean }
  | { type: 'error'; message: string };

interface AgentStatusStore {
  [agentId: string]: AgentStatus;
}

interface UseNavigationStateReturn {
  // State
  selectedAgent: AppId;
  selectedMode: 'sessions' | 'config' | 'settings';
  statusMap: AgentStatusStore;
  isLoading: boolean;

  // Actions
  selectAgent: (agent: AppId) => void;
  setMode: (mode: 'sessions' | 'config' | 'settings') => void;
  refreshStatuses: () => Promise<void>;
}

export function useNavigationState(): UseNavigationStateReturn {
  // Initialize selectedAgent from localStorage
  const [selectedAgent, setSelectedAgentState] = useState<AppId>(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored && ALL_APPS.includes(stored as AppId)) {
        return stored as AppId;
      }
    }
    return 'claude';
  });

  const [selectedMode, setModeState] = useState<'sessions' | 'config' | 'settings'>('sessions');
  const [statusMap, setStatusMap] = useState<AgentStatusStore>({});
  const [isLoading, setIsLoading] = useState(true);

  // Fetch config statuses on mount
  useEffect(() => {
    refreshStatuses();
  }, []);

  // Persist selectedAgent to localStorage
  const selectAgent = useCallback((agent: AppId) => {
    setSelectedAgentState(agent);
    localStorage.setItem(STORAGE_KEY, agent);
  }, []);

  const setMode = useCallback((mode: 'sessions' | 'config' | 'settings') => {
    setModeState(mode);
  }, []);

  const refreshStatuses = useCallback(async () => {
    setIsLoading(true);
    try {
      const statuses: AllConfigStatuses = await getAllConfigStatuses();
      const newStatusMap: AgentStatusStore = {};

      for (const app of ALL_APPS) {
        const status = statuses[app];
        if (status) {
          if (status.exists) {
            newStatusMap[app] = { type: 'success', exists: true };
          } else {
            // exists: false could mean no config OR error
            // Check if path contains error message (not a valid path)
            const isLikelyError = status.path && !status.path.startsWith('/');
            if (isLikelyError) {
              newStatusMap[app] = { type: 'error', message: status.path };
            } else {
              newStatusMap[app] = { type: 'success', exists: false };
            }
          }
        } else {
          newStatusMap[app] = { type: 'loading' };
        }
      }

      setStatusMap(newStatusMap);
    } catch (error) {
      console.error('Failed to fetch config statuses:', error);
      // Set all to error on failure
      const errorStatusMap: AgentStatusStore = {};
      for (const app of ALL_APPS) {
        errorStatusMap[app] = { type: 'error', message: 'Failed to load' };
      }
      setStatusMap(errorStatusMap);
    } finally {
      setIsLoading(false);
    }
  }, []);

  return useMemo(() => ({
    selectedAgent,
    selectedMode,
    statusMap,
    isLoading,
    selectAgent,
    setMode,
    refreshStatuses,
  }), [selectedAgent, selectedMode, statusMap, isLoading, selectAgent, setMode, refreshStatuses]);
}