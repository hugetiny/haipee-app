import { forwardRef, useEffect, useMemo, useState } from "react";
import { cn } from "@/lib/utils";
import { useTranslation } from "react-i18next";
import {
  History,
  Settings,
  Menu,
  X,
  Check,
  Circle,
  AlertTriangle,
  Loader2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { ProviderIcon } from "@/components/ProviderIcon";
import {
  useNavigationState,
  type AgentStatus,
  type AgentStatusStore,
} from "@/hooks/useNavigationState";
import type { AppId } from "@/lib/api";
import logoSvg from "@/assets/logo.svg";

export type MainView =
  | "providers"
  | "settings"
  | "sessions"
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
  onSessionProviderFilterChange?: (filter: string) => void;
  installedApps?: Partial<Record<AppId, boolean>>;
}

// 主菜单项 (底部功能按钮)
const MAIN_MENU_ITEMS = [
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "会话管理",
  },
  {
    id: "settings",
    icon: Settings,
    labelKey: "settings.title",
    labelFallback: "设置",
  },
] as const;

type MainMenuItem = (typeof MAIN_MENU_ITEMS)[number];

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

interface MainMenuButtonProps {
  item: MainMenuItem;
  isActive: boolean;
  onClick: () => void;
  variant: "desktop" | "mobile";
}

const MainMenuButton = ({
  item,
  isActive,
  onClick,
  variant,
}: MainMenuButtonProps) => {
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

// AgentListButton Props and Component
interface AgentListButtonProps {
  agentId: AppId;
  isActive: boolean;
  status: AgentStatus;
  onClick: () => void;
  collapsed?: boolean;
  isInstalled?: boolean;
  testId?: string;
}

const AgentListButton = ({
  agentId,
  isActive,
  status,
  onClick,
  collapsed,
  isInstalled = true,
  testId,
}: AgentListButtonProps) => {
  const renderStatusIcon = () => {
    if (!isInstalled) {
      return null;
    }
    if (status.type === "loading") {
      return <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />;
    }
    if (status.type === "error") {
      return (
        <Tooltip>
          <TooltipTrigger>
            <AlertTriangle className="h-4 w-4 text-yellow-500" />
          </TooltipTrigger>
          <TooltipContent>{status.message}</TooltipContent>
        </Tooltip>
      );
    }
    if (status.type === "success" && status.exists) {
      return <Check className="h-4 w-4 text-green-500" />;
    }
    return <Circle className="h-4 w-4 text-gray-400" />;
  };

  const buttonContent = (
    <button
      type="button"
      onClick={isInstalled ? onClick : undefined}
      disabled={!isInstalled}
      data-testid={testId}
      className={cn(
        "w-full flex items-center gap-2 px-3 py-2 rounded-md text-sm transition-colors",
        !isInstalled
          ? "cursor-not-allowed opacity-40"
          : isActive
            ? "bg-primary/10 text-primary"
            : "text-muted-foreground hover:text-foreground hover:bg-muted",
      )}
    >
      <ProviderIcon
        icon={APP_ICON_NAME[agentId]}
        name={APP_DISPLAY_NAME[agentId]}
        size={16}
      />
      {!collapsed && (
        <>
          <span className="truncate flex-1">{APP_DISPLAY_NAME[agentId]}</span>
          {renderStatusIcon()}
        </>
      )}
    </button>
  );

  // When collapsed, wrap with Tooltip to show agent name on hover
  if (collapsed) {
    return (
      <Tooltip>
        <TooltipTrigger asChild>{buttonContent}</TooltipTrigger>
        <TooltipContent side="right">
          {APP_DISPLAY_NAME[agentId]}
        </TooltipContent>
      </Tooltip>
    );
  }

  return buttonContent;
};

// Props interfaces for extracted components
interface DesktopSidebarProps {
  isMac: boolean;
  dragBarHeight: number;
  statusMap: AgentStatusStore;
  activeApp: AppId;
  onAgentClick: (agent: AppId) => void;
  activeMainMenu: string;
  onMainMenuClick: (item: MainMenuItem) => void;
  onOpenMobileSidebar: () => void;
  installedApps?: Partial<Record<AppId, boolean>>;
  currentView: MainView;
}

const DesktopSidebar = ({
  isMac,
  dragBarHeight,
  statusMap,
  activeApp,
  onAgentClick,
  activeMainMenu,
  onMainMenuClick,
  onOpenMobileSidebar,
  installedApps,
  currentView,
}: DesktopSidebarProps) => {
  const { t } = useTranslation();

  // Hide agent list when in settings view to avoid user confusion
  const showAgentList = currentView !== "settings";

  return (
    <aside
      className={cn(
        "hidden md:flex flex-col border-r bg-muted/20 shrink-0 h-full relative z-10",
        "w-16", // Always collapsed
      )}
      data-testid="sidebar"
    >
      {/* macOS traffic-light drag area */}
      {isMac && (
        <div
          style={
            {
              height: dragBarHeight,
              WebkitAppRegion: "drag",
            } as React.CSSProperties
          }
          className="w-full shrink-0"
        />
      )}

      {/* Header with hamburger and title */}
      <div className="flex items-center h-14 px-2 shrink-0 gap-1">
        <Button
          variant="ghost"
          size="icon"
          className="md:hidden"
          onClick={onOpenMobileSidebar}
        >
          <Menu className="h-5 w-5" />
        </Button>
        <div className="flex-1 flex justify-center">
          <img src={logoSvg} alt="Haipee" className="h-8 w-8 select-none" />
        </div>
      </div>

      <Separator className="opacity-40" />

      {/* Agent List - always collapsed, hidden in settings view */}
      {showAgentList && (
        <>
          <ScrollArea className="flex-1">
            <nav className="flex flex-col gap-0.5 p-2 py-3">
              <div className="px-1 pb-2 space-y-0.5">
                {ALL_APPS.map((app) => (
                  <AgentListButton
                    key={app}
                    agentId={app}
                    isActive={activeApp === app}
                    status={statusMap[app] || { type: "loading" }}
                    onClick={() => onAgentClick(app)}
                    collapsed={true}
                    isInstalled={installedApps?.[app] !== false}
                    testId={`app-btn-${app}`}
                  />
                ))}
              </div>
            </nav>
          </ScrollArea>

          <Separator className="opacity-40" />
        </>
      )}

      {/* Bottom: 2 buttons - 会话, 设置 */}
      <div className="p-2 shrink-0">
        <div className="flex flex-col gap-1">
          {MAIN_MENU_ITEMS.map((item) => (
            <Tooltip key={item.id}>
              <TooltipTrigger asChild>
                <button
                  type="button"
                  data-testid={`nav-btn-${item.id}`}
                  className={cn(
                    "flex items-center justify-center py-2 px-1 rounded-md transition-colors",
                    activeMainMenu === item.id
                      ? "bg-primary/10 text-primary"
                      : "text-muted-foreground hover:text-foreground hover:bg-muted",
                  )}
                  onClick={() => onMainMenuClick(item)}
                >
                  <item.icon className="w-5 h-5" />
                </button>
              </TooltipTrigger>
              <TooltipContent side="right">
                {t(item.labelKey, item.labelFallback)}
              </TooltipContent>
            </Tooltip>
          ))}
        </div>
      </div>
    </aside>
  );
};

interface MobileSidebarOverlayProps {
  isOpen: boolean;
  onClose: () => void;
  isMac: boolean;
  dragBarHeight: number;
  statusMap: AgentStatusStore;
  activeApp: AppId;
  onAgentClick: (agent: AppId) => void;
  activeMainMenu: string;
  onMainMenuClick: (item: MainMenuItem) => void;
  installedApps?: Partial<Record<AppId, boolean>>;
}

const MobileSidebarOverlay = ({
  isOpen,
  onClose,
  isMac,
  dragBarHeight,
  statusMap,
  activeApp,
  onAgentClick,
  activeMainMenu,
  onMainMenuClick,
  installedApps,
}: MobileSidebarOverlayProps) => {
  const { t } = useTranslation();

  return (
    <>
      {/* Backdrop */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 md:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-50 w-72 bg-background border-r transform transition-transform duration-300 md:hidden flex flex-col",
          isOpen ? "translate-x-0" : "-translate-x-full",
        )}
      >
        {/* Header */}
        {isMac && (
          <div
            style={
              {
                height: dragBarHeight,
                WebkitAppRegion: "drag",
              } as React.CSSProperties
            }
            className="w-full shrink-0"
          />
        )}

        <div className="flex items-center h-14 px-4 shrink-0 justify-between">
          <img src={logoSvg} alt="Haipee" className="h-7 w-7 select-none" />
          <Button variant="ghost" size="icon" onClick={onClose}>
            <X className="h-5 w-5" />
          </Button>
        </div>

        <Separator className="opacity-40" />

        {/* Secondary Menu */}
        <ScrollArea className="flex-1">
          <nav className="flex flex-col gap-0.5 p-2 py-3">
            {/* Agent List for mobile */}
            <div className="px-1 pb-2 space-y-0.5">
              <div className="px-3 py-1.5 text-xs font-medium text-muted-foreground/70 uppercase tracking-wider">
                {t("nav.agents", "Agents")}
              </div>
              {ALL_APPS.map((app) => (
                <AgentListButton
                  key={app}
                  agentId={app}
                  isActive={activeApp === app}
                  status={statusMap[app] || { type: "loading" }}
                  onClick={() => {
                    onAgentClick(app);
                    onClose();
                  }}
                  isInstalled={installedApps?.[app] !== false}
                  testId={`app-btn-${app}`}
                />
              ))}
            </div>
          </nav>
        </ScrollArea>

        <Separator className="opacity-40" />

        {/* Main Menu - 2 columns */}
        <div className="p-2 shrink-0">
          <div className="grid grid-cols-2 gap-1">
            {MAIN_MENU_ITEMS.map((item) => (
              <MainMenuButton
                key={item.id}
                item={item}
                isActive={activeMainMenu === item.id}
                onClick={() => onMainMenuClick(item)}
                variant="desktop"
              />
            ))}
          </div>
        </div>
      </aside>
    </>
  );
};

interface MobileBottomNavProps {
  activeMainMenu: string;
  onMainMenuClick: (item: MainMenuItem) => void;
}

const MobileBottomNav = ({
  activeMainMenu,
  onMainMenuClick,
}: MobileBottomNavProps) => {
  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-30 border-t bg-background/95 backdrop-blur-sm safe-area-bottom shrink-0">
      <div className="flex items-stretch justify-around h-[56px]">
        {MAIN_MENU_ITEMS.map((item) => (
          <MainMenuButton
            key={item.id}
            item={item}
            isActive={activeMainMenu === item.id}
            onClick={() => onMainMenuClick(item)}
            variant="mobile"
          />
        ))}
      </div>
    </nav>
  );
};

interface MobileTopBarProps {
  activeMainMenu: string;
  currentView: MainView;
  dragBarHeight: number;
}

const MobileTopBar = ({
  activeMainMenu,
  currentView,
  dragBarHeight,
}: MobileTopBarProps) => {
  const { t } = useTranslation();
  const mainItem = MAIN_MENU_ITEMS.find((i) => i.id === activeMainMenu);
  const label =
    currentView === "settings"
      ? t("settings.title", "Settings")
      : (mainItem?.labelFallback ?? t("app.title", "Haipee"));

  return (
    <header
      className="md:hidden shrink-0 border-b bg-background/95 backdrop-blur-sm flex items-center justify-center px-4"
      style={
        {
          paddingTop: `${dragBarHeight + 8}px`,
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
    </header>
  );
};

export const MainLayout = forwardRef<HTMLDivElement, MainLayoutProps>(
  (
    {
      children,
      currentView,
      setCurrentView,
      activeApp,
      setActiveApp,
      openSettings: _openSettings, // Reserved for future use
      isMac,
      className,
      onSessionProviderFilterChange,
      installedApps,
    },
    ref,
  ) => {
    const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);
    const DRAG_BAR_HEIGHT = isMac ? 28 : 0;

    // Navigation state hook - use for statusMap and agent selection
    const { selectedAgent, statusMap, selectAgent } = useNavigationState();

    // Sync selectedAgent from navigation state to activeApp prop on mount
    useEffect(() => {
      if (selectedAgent && selectedAgent !== activeApp) {
        setActiveApp(selectedAgent);
      }
    }, [selectedAgent]);

    // 确定当前选中的主菜单
    const activeMainMenu = useMemo(() => {
      if (currentView === "sessions") return "sessions";
      if (currentView === "settings") return "settings";
      return "sessions";
    }, [currentView]);

    const handleMainMenuClick = (item: MainMenuItem) => {
      setCurrentView(item.id);
      setIsMobileSidebarOpen(false);
    };

    const handleAgentClick = (agent: AppId) => {
      selectAgent(agent);
      setActiveApp(agent);
      onSessionProviderFilterChange?.(agent);
    };

    return (
      <div
        ref={ref}
        className={cn(
          "flex h-[100dvh] w-full overflow-hidden bg-background text-foreground",
          className,
        )}
      >
        <MobileSidebarOverlay
          isOpen={isMobileSidebarOpen}
          onClose={() => setIsMobileSidebarOpen(false)}
          isMac={isMac}
          dragBarHeight={DRAG_BAR_HEIGHT}
          statusMap={statusMap}
          activeApp={activeApp}
          onAgentClick={handleAgentClick}
          activeMainMenu={activeMainMenu}
          onMainMenuClick={handleMainMenuClick}
          installedApps={installedApps}
        />
        <DesktopSidebar
          isMac={isMac}
          dragBarHeight={DRAG_BAR_HEIGHT}
          statusMap={statusMap}
          activeApp={activeApp}
          onAgentClick={handleAgentClick}
          activeMainMenu={activeMainMenu}
          onMainMenuClick={handleMainMenuClick}
          onOpenMobileSidebar={() => setIsMobileSidebarOpen(true)}
          installedApps={installedApps}
          currentView={currentView}
        />

        {/* Main content column */}
        <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
          <MobileTopBar
            activeMainMenu={activeMainMenu}
            currentView={currentView}
            dragBarHeight={DRAG_BAR_HEIGHT}
          />

          {/* Desktop drag bar for macOS traffic lights */}
          {isMac && (
            <div
              className="hidden md:block shrink-0 bg-transparent"
              style={
                {
                  height: DRAG_BAR_HEIGHT,
                  WebkitAppRegion: "drag",
                } as React.CSSProperties
              }
            />
          )}

          {/* Content area - overflow-hidden lets children manage their own scrolling */}
          <main className="flex-1 min-h-0 flex flex-col overflow-hidden relative">
            {children}
          </main>

          <MobileBottomNav
            activeMainMenu={activeMainMenu}
            onMainMenuClick={handleMainMenuClick}
          />
          {/* Bottom nav spacer */}
          <div className="md:hidden h-[56px] shrink-0 pointer-events-none" />
        </div>
      </div>
    );
  },
);

MainLayout.displayName = "MainLayout";
