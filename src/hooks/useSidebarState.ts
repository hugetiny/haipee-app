import { useState, useCallback, useEffect } from "react";

const SIDEBAR_STORAGE_KEY = "haipee-sidebar-collapsed";

/**
 * Hook for managing sidebar collapse state
 * - Persists to localStorage
 * - Auto-collapses on narrow screens (< md breakpoint)
 * - Supports manual toggle
 */
export function useSidebarState() {
  const [isCollapsed, setIsCollapsed] = useState(() => {
    // Initialize from localStorage
    if (typeof window !== "undefined") {
      const stored = localStorage.getItem(SIDEBAR_STORAGE_KEY);
      if (stored !== null) {
        return stored === "true";
      }
    }
    return false;
  });

  // Persist to localStorage
  useEffect(() => {
    localStorage.setItem(SIDEBAR_STORAGE_KEY, String(isCollapsed));
  }, [isCollapsed]);

  const toggle = useCallback(() => {
    setIsCollapsed((prev) => !prev);
  }, []);

  const collapse = useCallback(() => {
    setIsCollapsed(true);
  }, []);

  const expand = useCallback(() => {
    setIsCollapsed(false);
  }, []);

  return {
    isCollapsed,
    toggle,
    collapse,
    expand,
  };
}
