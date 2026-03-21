import React, {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { invoke } from "@tauri-apps/api/core";

type Theme = "light" | "dark";

interface ThemeProviderProps {
  children: React.ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
}

interface ThemeContextValue {
  theme: Theme;
  setTheme: (theme: Theme, event?: React.MouseEvent) => void;
}

const ThemeProviderContext = createContext<ThemeContextValue | undefined>(
  undefined,
);

export function ThemeProvider({
  children,
  defaultTheme = "dark",
  storageKey = "haipee-theme",
}: ThemeProviderProps) {
  const getInitialTheme = (): Theme => {
    if (typeof window === "undefined") {
      return defaultTheme;
    }

    const stored = window.localStorage.getItem(storageKey) as Theme | null;
    if (stored === "light" || stored === "dark") {
      return stored;
    }

    return defaultTheme;
  };

  const [theme, setThemeState] = useState<Theme>(getInitialTheme);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(storageKey, theme);
  }, [theme, storageKey]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    const root = window.document.documentElement;
    root.classList.remove("light", "dark");
    root.classList.add(theme);
  }, [theme]);

  // Sync native window theme (Windows/macOS title bar)
  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    let isCancelled = false;

    const updateNativeTheme = async (nativeTheme: string) => {
      if (isCancelled) return;
      try {
        await invoke("set_window_theme", { theme: nativeTheme });
      } catch (e) {
        // Ignore errors (e.g., when not running in Tauri)
        console.debug("Failed to set native window theme:", e);
      }
    };

    updateNativeTheme(theme);

    return () => {
      isCancelled = true;
    };
  }, [theme]);

  const value = useMemo<ThemeContextValue>(
    () => ({
      theme,
      setTheme: (nextTheme: Theme, event?: React.MouseEvent) => {
        // Skip if same theme
        if (nextTheme === theme) return;

        // Set transition origin coordinates from click event
        const x = event?.clientX ?? window.innerWidth / 2;
        const y = event?.clientY ?? window.innerHeight / 2;
        document.documentElement.style.setProperty(
          "--theme-transition-x",
          `${x}px`,
        );
        document.documentElement.style.setProperty(
          "--theme-transition-y",
          `${y}px`,
        );

        // Use View Transitions API if available, otherwise fall back to instant change
        if (document.startViewTransition) {
          document.startViewTransition(() => {
            setThemeState(nextTheme);
          });
        } else {
          setThemeState(nextTheme);
        }
      },
    }),
    [theme],
  );

  return (
    <ThemeProviderContext.Provider value={value}>
      {children}
    </ThemeProviderContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeProviderContext);
  if (context === undefined) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
