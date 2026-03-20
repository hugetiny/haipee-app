import type { AppId } from "@/lib/api";
import type { VisibleApps } from "@/types";
import { ProviderIcon } from "@/components/ProviderIcon";
import { cn } from "@/lib/utils";

interface AppSwitcherProps {
  activeApp: AppId;
  onSwitch: (app: AppId) => void;
  visibleApps?: VisibleApps;
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
  visibleApps,
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

  // Filter apps based on visibility settings (default all visible)
  const appsToShow = ALL_APPS.filter((app) => {
    if (!visibleApps) return true;
    return visibleApps[app];
  });

  // Sidebar variant: compact vertical layout with hover tooltip
  if (variant === "sidebar") {
    return (
      <div className="flex flex-row gap-0.5">
        {appsToShow.map((app) => (
          <button
            key={app}
            type="button"
            title={appDisplayName[app]}
            onClick={() => handleSwitch(app)}
            className={cn(
              "relative inline-flex items-center justify-center w-9 h-9 rounded-md transition-all duration-150",
              activeApp === app
                ? "bg-primary/10 text-primary"
                : "text-muted-foreground hover:text-foreground hover:bg-muted",
            )}
          >
            <ProviderIcon
              icon={appIconName[app]}
              name={appDisplayName[app]}
              size={iconSize}
            />
          </button>
        ))}
      </div>
    );
  }

  // Default variant: horizontal layout with optional text
  return (
    <div className="inline-flex bg-muted rounded-xl p-1 gap-1">
      {appsToShow.map((app) => (
        <button
          key={app}
          type="button"
          onClick={() => handleSwitch(app)}
          className={cn(
            "group inline-flex items-center px-3 h-8 rounded-md text-sm font-medium transition-all duration-200",
            activeApp === app
              ? "bg-background text-foreground shadow-sm"
              : "text-muted-foreground hover:text-foreground hover:bg-background/50",
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
      ))}
    </div>
  );
}
