import { forwardRef, useMemo, useState } from "react";
import { cn } from "@/lib/utils";
import { useTranslation } from "react-i18next";
import {
  History,
  Settings,
  Settings2,
  Menu,
  X,
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { ProviderIcon } from "@/components/ProviderIcon";
import { useSidebarState } from "@/hooks/useSidebarState";
import { useActiveOpenClawInstance } from "@/hooks/useOpenClaw";
import type { AppId } from "@/lib/api";

export type MainView =
  | "providers"
  | "settings"
  | "sessions"
  | "agentConfig"
  | "prompts"
  | "skills"
  | "skillsDiscovery"
  | "mcp"
  | "agents"
  | "universal"
  | "openclawEnv"
  | "openclawTools"
  | "openclawAgents"
  | string;

interface MainLayoutProps {
  children: React.ReactNode;
  currentView: MainView;
  setCurrentView: (view: MainView) => void;
  activeApp: AppId;
  setActiveApp: (app: AppId) => void;
  openSettings: (tab?: string) => void;
  isMac: boolean;
  className?: string;
  sessionProviderFilter?: string;
  onSessionProviderFilterChange?: (filter: string) => void;
}

// 主菜单项 (底部2个功能按钮 + Agent切换器)
const MAIN_MENU_ITEMS = [
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "会话管理",
  },
  {
    id: "agentConfig",
    icon: Settings2,
    labelKey: "agent.config.title",
    labelFallback: "Agent配置",
  },
] as const;

type MainMenuItem = typeof MAIN_MENU_ITEMS[number];

// App 切换相关
const ALL_APPS: AppId[] = ["claude", "codex", "gemini", "opencode", "openclaw"];
const APP_ICON_NAME: Record<AppId, string> = {
  claude: "claude",
  codex: "openai",
  gemini: "gemini",
  opencode: "opencode",
  openclaw: "openclaw",
};
const APP_DISPLAY_NAME: Record<AppId, string> = {
  claude: "Claude",
  codex: "Codex",
  gemini: "Gemini",
  opencode: "OpenCode",
  openclaw: "OpenClaw",
};

interface AppSwitcherButtonProps {
  activeApp: AppId;
  onSwitch: (app: AppId) => void;
  variant: "desktop" | "mobile";
  onNavigateToProviders?: () => void;
}

const AppSwitcherButton = ({ activeApp, onSwitch, variant, onNavigateToProviders }: AppSwitcherButtonProps) => {
  const [open, setOpen] = useState(false);

  const handleSwitch = (app: AppId) => {
    onSwitch(app);
    setOpen(false);
    onNavigateToProviders?.();
  };

  if (variant === "desktop") {
    return (
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <button
            type="button"
            title="切换应用"
            className={cn(
              "flex items-center justify-center py-2 px-1 rounded-md transition-colors gap-0.5",
              open
                ? "bg-primary/10 text-primary"
                : "text-muted-foreground hover:text-foreground hover:bg-muted",
            )}
          >
            <ProviderIcon
              icon={APP_ICON_NAME[activeApp]}
              name={APP_DISPLAY_NAME[activeApp]}
              size={18}
            />
            <ChevronsUpDown className="w-3 h-3 opacity-50" />
          </button>
        </PopoverTrigger>
        <PopoverContent className="w-48 p-1" align="start">
          <div className="flex flex-col gap-0.5">
            {ALL_APPS.map((app) => (
              <button
                key={app}
                type="button"
                onClick={() => handleSwitch(app)}
                className={cn(
                  "flex items-center gap-2 px-3 py-2 rounded-md text-sm transition-colors",
                  activeApp === app
                    ? "bg-primary/10 text-primary"
                    : "text-muted-foreground hover:text-foreground hover:bg-muted",
                )}
              >
                <ProviderIcon
                  icon={APP_ICON_NAME[app]}
                  name={APP_DISPLAY_NAME[app]}
                  size={18}
                />
                <span>{APP_DISPLAY_NAME[app]}</span>
              </button>
            ))}
          </div>
        </PopoverContent>
      </Popover>
    );
  }

  // Mobile variant
  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <button
          type="button"
          className={cn(
            "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
            open ? "text-primary" : "text-muted-foreground hover:text-foreground",
          )}
        >
          <ProviderIcon
            icon={APP_ICON_NAME[activeApp]}
            name={APP_DISPLAY_NAME[activeApp]}
            size={22}
          />
          <span className="text-xs leading-none truncate max-w-[56px]">
            {APP_DISPLAY_NAME[activeApp]}
          </span>
        </button>
      </PopoverTrigger>
      <PopoverContent className="w-48 p-1" align="start">
        <div className="flex flex-col gap-0.5">
          {ALL_APPS.map((app) => (
            <button
              key={app}
              type="button"
              onClick={() => handleSwitch(app)}
              className={cn(
                "flex items-center gap-2 px-3 py-2 rounded-md text-sm transition-colors",
                activeApp === app
                  ? "bg-primary/10 text-primary"
                  : "text-muted-foreground hover:text-foreground hover:bg-muted",
              )}
            >
              <ProviderIcon
                icon={APP_ICON_NAME[app]}
                name={APP_DISPLAY_NAME[app]}
                size={18}
              />
              <span>{APP_DISPLAY_NAME[app]}</span>
            </button>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
};

interface MainMenuButtonProps {
  item: MainMenuItem;
  isActive: boolean;
  onClick: () => void;
  variant: "desktop" | "mobile";
}

const MainMenuButton = ({ item, isActive, onClick, variant }: MainMenuButtonProps) => {
  const { t } = useTranslation();
  const label = t(item.labelKey, item.labelFallback);

  if (variant === "desktop") {
    return (
      <button
        type="button"
        title={label}
        className={cn(
          "flex items-center justify-center py-2 px-1 rounded-md transition-colors",
          isActive
            ? "bg-primary/10 text-primary"
            : "text-muted-foreground hover:text-foreground hover:bg-muted",
        )}
        onClick={onClick}
      >
        <item.icon className="w-5 h-5" />
      </button>
    );
  }

  return (
    <button
      type="button"
      className={cn(
        "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
        isActive
          ? "text-primary"
          : "text-muted-foreground hover:text-foreground",
      )}
      onClick={onClick}
    >
      <item.icon className="w-[22px] h-[22px]" />
      <span className="text-xs leading-none truncate max-w-[56px]">
        {label}
      </span>
    </button>
  );
};

interface FilterButtonProps {
  icon: string;
  name: string;
  label: string;
  isActive: boolean;
  isSubItem?: boolean;
  onClick: () => void;
}

const FilterButton = ({ icon, name, label, isActive, isSubItem, onClick }: FilterButtonProps) => (
  <button
    type="button"
    onClick={onClick}
    className={cn(
      "w-full flex items-center gap-2 px-3 py-2 rounded-md text-sm transition-colors",
      isActive
        ? "bg-primary/10 text-primary"
        : "text-muted-foreground hover:text-foreground hover:bg-muted",
      isSubItem && "pl-8"
    )}
  >
    <ProviderIcon icon={icon} name={name} size={16} />
    <span className="truncate">{label}</span>
  </button>
);

export const MainLayout = forwardRef<HTMLDivElement, MainLayoutProps>(
  (
    {
      children,
      currentView,
      setCurrentView,
      activeApp,
      setActiveApp,
      openSettings,
      isMac,
      className,
      sessionProviderFilter,
      onSessionProviderFilterChange,
    },
    ref,
  ) => {
    const { t } = useTranslation();
    const { isCollapsed, toggle } = useSidebarState();
    const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);
    const DRAG_BAR_HEIGHT = isMac ? 28 : 0;
    const { allInstances } = useActiveOpenClawInstance();

    // 确定当前选中的主菜单
    const activeMainMenu = useMemo(() => {
      if (currentView === "sessions") return "sessions";
      if (currentView === "agentConfig") return "agentConfig";
      return "sessions";
    }, [currentView]);

    const handleMainMenuClick = (item: MainMenuItem) => {
      setCurrentView(item.id);
      setIsMobileSidebarOpen(false);
    };

    // Desktop Sidebar
    const DesktopSidebar = () => {
      const isSessionsView = activeMainMenu === "sessions";

      return (
        <aside
          className={cn(
            "hidden md:flex flex-col border-r bg-muted/20 shrink-0 h-full transition-all duration-300 relative z-10",
            isCollapsed ? "w-16" : "w-56 lg:w-64"
          )}
        >
          {/* macOS traffic-light drag area */}
          {isMac && (
            <div
              style={
                {
                  height: DRAG_BAR_HEIGHT,
                  WebkitAppRegion: "drag",
                } as React.CSSProperties
              }
              className="w-full shrink-0"
            />
          )}

          {/* Header with hamburger, title, collapse toggle, and settings */}
          <div className="flex items-center h-14 px-2 shrink-0 gap-1">
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden"
              onClick={() => setIsMobileSidebarOpen(true)}
            >
              <Menu className="h-5 w-5" />
            </Button>
            {!isCollapsed && (
              <span className="font-bold text-lg tracking-tight text-primary select-none flex-1">
                Haipee
              </span>
            )}
            {!isCollapsed && (
              <Button
                variant="ghost"
                size="icon"
                onClick={() => openSettings()}
                title={t("common.settings", "设置")}
              >
                <Settings className="h-4 w-4" />
              </Button>
            )}
            <Button
              variant="ghost"
              size="icon"
              onClick={toggle}
              className="hidden md:flex"
            >
              {isCollapsed ? (
                <ChevronRight className="h-4 w-4" />
              ) : (
                <ChevronLeft className="h-4 w-4" />
              )}
            </Button>
          </div>

          <Separator className="opacity-40" />

          {/* Secondary Menu */}
          <ScrollArea className="flex-1">
            <nav className="flex flex-col gap-0.5 p-2 py-3">
              {/* Sessions Provider Filter */}
              {isSessionsView && (
                <div className="px-1 pb-2 space-y-0.5">
                  <FilterButton
                    icon="apps"
                    name="all"
                    label="全部"
                    isActive={!sessionProviderFilter || sessionProviderFilter === "all"}
                    onClick={() => onSessionProviderFilterChange?.("all")}
                  />
                  <FilterButton
                    icon="claude"
                    name="claude"
                    label="Claude"
                    isActive={sessionProviderFilter === "claude" || activeApp === "claude"}
                    onClick={() => {
                      setActiveApp("claude");
                      onSessionProviderFilterChange?.("claude");
                    }}
                  />
                  <FilterButton
                    icon="openai"
                    name="codex"
                    label="Codex"
                    isActive={sessionProviderFilter === "codex" || activeApp === "codex"}
                    onClick={() => {
                      setActiveApp("codex");
                      onSessionProviderFilterChange?.("codex");
                    }}
                  />
                  <FilterButton
                    icon="opencode"
                    name="opencode"
                    label="OpenCode"
                    isActive={sessionProviderFilter === "opencode" || activeApp === "opencode"}
                    onClick={() => {
                      setActiveApp("opencode");
                      onSessionProviderFilterChange?.("opencode");
                    }}
                  />
                  <FilterButton
                    icon="gemini"
                    name="gemini"
                    label="Gemini"
                    isActive={sessionProviderFilter === "gemini" || activeApp === "gemini"}
                    onClick={() => {
                      setActiveApp("gemini");
                      onSessionProviderFilterChange?.("gemini");
                    }}
                  />

                  {/* OpenClaw instances */}
                  <div className="pt-1">
                    <div className="px-3 py-1.5 text-xs font-medium text-muted-foreground/70 uppercase tracking-wider">
                      OpenClaw
                    </div>
                    <div className="space-y-0.5">
                      {allInstances.map((inst) => (
                        <FilterButton
                          key={inst.id}
                          icon="openclaw"
                          name={inst.name}
                          label={inst.name}
                          isActive={sessionProviderFilter === "openclaw" || activeApp === "openclaw"}
                          isSubItem
                          onClick={() => {
                            setActiveApp("openclaw");
                            onSessionProviderFilterChange?.("openclaw");
                          }}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </nav>
          </ScrollArea>

          <Separator className="opacity-40" />

          {/* Bottom: AppSwitcher + Main Menu Icons (3 buttons) */}
          <div className="p-2 shrink-0">
            <div className="grid grid-cols-3 gap-1">
              <AppSwitcherButton
                activeApp={activeApp}
                onSwitch={setActiveApp}
                variant="desktop"
                onNavigateToProviders={() => setCurrentView("providers")}
              />
              {MAIN_MENU_ITEMS.map((item) => (
                <MainMenuButton
                  key={item.id}
                  item={item}
                  isActive={activeMainMenu === item.id}
                  onClick={() => handleMainMenuClick(item)}
                  variant="desktop"
                />
              ))}
            </div>
          </div>
        </aside>
      );
    };

    // Mobile Sidebar Overlay
    const MobileSidebarOverlay = () => (
      <>
        {/* Backdrop */}
        {isMobileSidebarOpen && (
          <div
            className="fixed inset-0 bg-black/50 z-40 md:hidden"
            onClick={() => setIsMobileSidebarOpen(false)}
          />
        )}

        {/* Sidebar */}
        <aside
          className={cn(
            "fixed inset-y-0 left-0 z-50 w-72 bg-background border-r transform transition-transform duration-300 md:hidden flex flex-col",
            isMobileSidebarOpen ? "translate-x-0" : "-translate-x-full"
          )}
        >
          {/* Header */}
          {isMac && (
            <div
              style={{
                height: DRAG_BAR_HEIGHT,
                WebkitAppRegion: "drag",
              } as React.CSSProperties}
              className="w-full shrink-0"
            />
          )}

          <div className="flex items-center h-14 px-4 shrink-0 justify-between">
            <span className="font-bold text-lg tracking-tight text-primary select-none">
              Haipee
            </span>
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setIsMobileSidebarOpen(false)}
            >
              <X className="h-5 w-5" />
            </Button>
          </div>

          <Separator className="opacity-40" />

          {/* Secondary Menu */}
          <ScrollArea className="flex-1">
            <nav className="flex flex-col gap-0.5 p-2 py-3">
              {/* Sessions Provider Filter for mobile */}
              {activeMainMenu === "sessions" && (
                <div className="px-1 pb-2 space-y-0.5">
                  <FilterButton
                    icon="apps"
                    name="all"
                    label="全部"
                    isActive={!sessionProviderFilter || sessionProviderFilter === "all"}
                    onClick={() => onSessionProviderFilterChange?.("all")}
                  />
                  <FilterButton
                    icon="claude"
                    name="claude"
                    label="Claude"
                    isActive={sessionProviderFilter === "claude" || activeApp === "claude"}
                    onClick={() => {
                      setActiveApp("claude");
                      onSessionProviderFilterChange?.("claude");
                    }}
                  />
                  <FilterButton
                    icon="openai"
                    name="codex"
                    label="Codex"
                    isActive={sessionProviderFilter === "codex" || activeApp === "codex"}
                    onClick={() => {
                      setActiveApp("codex");
                      onSessionProviderFilterChange?.("codex");
                    }}
                  />
                  <FilterButton
                    icon="opencode"
                    name="opencode"
                    label="OpenCode"
                    isActive={sessionProviderFilter === "opencode" || activeApp === "opencode"}
                    onClick={() => {
                      setActiveApp("opencode");
                      onSessionProviderFilterChange?.("opencode");
                    }}
                  />
                  <FilterButton
                    icon="gemini"
                    name="gemini"
                    label="Gemini"
                    isActive={sessionProviderFilter === "gemini" || activeApp === "gemini"}
                    onClick={() => {
                      setActiveApp("gemini");
                      onSessionProviderFilterChange?.("gemini");
                    }}
                  />
                </div>
              )}
            </nav>
          </ScrollArea>

          <Separator className="opacity-40" />

          {/* Main Menu */}
          <div className="p-2 shrink-0">
            <div className="grid grid-cols-3 gap-1">
              <AppSwitcherButton
                activeApp={activeApp}
                onSwitch={(app) => {
                  setActiveApp(app);
                  setIsMobileSidebarOpen(false);
                }}
                variant="desktop"
                onNavigateToProviders={() => {
                  setCurrentView("providers");
                  setIsMobileSidebarOpen(false);
                }}
              />
              {MAIN_MENU_ITEMS.map((item) => (
                <MainMenuButton
                  key={item.id}
                  item={item}
                  isActive={activeMainMenu === item.id}
                  onClick={() => handleMainMenuClick(item)}
                  variant="desktop"
                />
              ))}
            </div>
          </div>
        </aside>
      </>
    );

    // Mobile Bottom Navigation
    const MobileBottomNav = () => (
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-30 border-t bg-background/95 backdrop-blur-sm safe-area-bottom shrink-0">
        <div className="flex items-stretch justify-around h-[56px]">
          <AppSwitcherButton
            activeApp={activeApp}
            onSwitch={setActiveApp}
            variant="mobile"
            onNavigateToProviders={() => setCurrentView("providers")}
          />
          {MAIN_MENU_ITEMS.map((item) => (
            <MainMenuButton
              key={item.id}
              item={item}
              isActive={activeMainMenu === item.id}
              onClick={() => handleMainMenuClick(item)}
              variant="mobile"
            />
          ))}
        </div>
      </nav>
    );

    // Mobile Top Bar
    const MobileTopBar = () => {
      const mainItem = MAIN_MENU_ITEMS.find((i) => i.id === activeMainMenu);
      const label = currentView === "settings"
        ? t("settings.title", "Settings")
        : (mainItem?.labelFallback ?? t("app.title", "Haipee"));

      return (
        <header
          className="md:hidden shrink-0 border-b bg-background/95 backdrop-blur-sm flex items-center justify-between px-4"
          style={
            {
              paddingTop: `${DRAG_BAR_HEIGHT + 8}px`,
              paddingBottom: "8px",
              WebkitAppRegion: "drag",
            } as React.CSSProperties
          }
        >
          <h1
            className="font-semibold text-lg leading-none tracking-tight select-none"
            style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
          >
            {label}
          </h1>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => openSettings()}
            style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}
          >
            <Settings className="h-5 w-5" />
          </Button>
        </header>
      );
    };

    return (
      <div
        ref={ref}
        className={cn(
          "flex h-[100dvh] w-full overflow-hidden bg-background text-foreground",
          className,
        )}
      >
        <MobileSidebarOverlay />
        <DesktopSidebar />

        {/* Main content column */}
        <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
          <MobileTopBar />

          {/* Scrollable content area */}
          <main className="flex-1 min-h-0 overflow-y-auto overflow-x-hidden relative">
            {children}
          </main>

          <MobileBottomNav />
          {/* Bottom nav spacer */}
          <div className="md:hidden h-[56px] shrink-0 pointer-events-none" />
        </div>
      </div>
    );
  },
);

MainLayout.displayName = "MainLayout";