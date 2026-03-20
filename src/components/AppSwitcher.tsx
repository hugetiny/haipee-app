import type { AppId } from "@/lib/api";
import { ProviderIcon } from "@/components/ProviderIcon";
import { cn } from "@/lib/utils";

interface AppSwitcherProps {
  activeApp: AppId;
  onSwitch: (app: AppId) => void;
  /** Map of appId -> installed status. If not provided, all apps are considered installed. */
  installedApps?: Partial<Record<AppId, boolean>>;
  /** @deprecated - now always uses compact mode in sidebar */
  compact?: boolean;
  /** Sidebar variant: vertical icon-only buttons with hover tooltip */
  variant?: "default" | "sidebar";
}

const ALL_APPS: AppId[] = ["claude", "codex", "gemini", "opencode", "openclaw"];
const STORAGE_KEY = "haipee-last-app";

export function AppSwitcher({
  activeApp,
  onSwitch,
  installedApps,
  variant = "default",
}: AppSwitcherProps) {
  const handleSwitch = (app: AppId) => {
    if (app === activeApp) return;
    localStorage.setItem(STORAGE_KEY, app);
    onSwitch(app);
  };
  const iconSize = 20;
  const appIconName: Record<AppId, string> = {
    claude: "claude",
    codex: "openai",
    gemini: "gemini",
    opencode: "opencode",
    openclaw: "openclaw",
  };
  const appDisplayName: Record<AppId, string> = {
    claude: "Claude",
    codex: "Codex",
    gemini: "Gemini",
    opencode: "OpenCode",
    openclaw: "OpenClaw",
  };

  // Sidebar variant: compact vertical layout with hover tooltip
  if (variant === "sidebar") {
    return (
      <div className="flex flex-row gap-0.5">
        {ALL_APPS.map((app) => {
          const isInstalled = installedApps?.[app] !== false; // Default to true if not specified
          const isActive = activeApp === app;

          return (
            <button
              key={app}
              type="button"
              title={appDisplayName[app]}
              onClick={() => isInstalled && handleSwitch(app)}
              disabled={!isInstalled}
              className={cn(
                "relative inline-flex items-center justify-center w-9 h-9 rounded-md transition-all duration-150",
                isActive
                  ? "bg-primary/10 text-primary"
                  : isInstalled
                    ? "text-muted-foreground hover:text-foreground hover:bg-muted"
                    : "text-muted-foreground/40 cursor-not-allowed",
              )}
            >
              <ProviderIcon
                icon={appIconName[app]}
                name={appDisplayName[app]}
                size={iconSize}
              />
            </button>
          );
        })}
      </div>
    );
  }

  // Default variant: horizontal layout with optional text
  return (
    <div className="inline-flex bg-muted rounded-xl p-1 gap-1">
      {ALL_APPS.map((app) => {
        const isInstalled = installedApps?.[app] !== false; // Default to true if not specified
        const isActive = activeApp === app;

        return (
          <button
            key={app}
            type="button"
            onClick={() => isInstalled && handleSwitch(app)}
            disabled={!isInstalled}
            className={cn(
              "group inline-flex items-center px-3 h-8 rounded-md text-sm font-medium transition-all duration-200",
              isActive
                ? "bg-background text-foreground shadow-sm"
                : isInstalled
                  ? "text-muted-foreground hover:text-foreground hover:bg-background/50"
                  : "text-muted-foreground/40 cursor-not-allowed",
            )}
          >
            <ProviderIcon
              icon={appIconName[app]}
              name={appDisplayName[app]}
              size={iconSize}
            />
            <span className="ml-2 whitespace-nowrap">
              {appDisplayName[app]}
            </span>
          </button>
        );
      })}
    </div>
  );
}
