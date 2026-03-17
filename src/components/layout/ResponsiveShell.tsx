import { forwardRef, useMemo } from "react";
import { cn } from "@/lib/utils";
import { useTranslation } from "react-i18next";
import {
  FolderOpen,
  KeyRound,
  History,
  Settings,
  LayoutGrid,
  Database,
  Wifi,
  MessageSquare,
  Code2,
  Shield,
  Cpu,
  FileJson,
  List,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";

export type AppView =
  | "providers"
  | "settings"
  | "sessions"
  | "workspace"
  | "openclawDashboard"
  | "models"
  | "env"
  | "gateway"
  | "channels"
  | "skills"
  | "tools"
  | "agents"
  | "json"
  | string;

interface NavigationBadgeProps {
  currentView: AppView;
  setCurrentView: (view: AppView) => void;
  openSettings: () => void;
  isMac: boolean;
  className?: string;
  children: React.ReactNode;
}

// 底部4个主菜单
const MAIN_MENU_ITEMS = [
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "会话管理",
  },
  {
    id: "workspace",
    icon: FolderOpen,
    labelKey: "workspace.manage",
    labelFallback: "Workspace",
  },
  {
    id: "openclawDashboard",
    icon: KeyRound,
    labelKey: "openclaw.dashboard.title",
    labelFallback: "Dashboard",
  },
  {
    id: "settings",
    icon: Settings,
    labelKey: "common.settings",
    labelFallback: "设置",
  },
] as const;

// 二级菜单定义
const SUB_MENU_ITEMS: Record<string, { id: AppView; icon: React.ElementType; label: string }[]> = {
  sessions: [],
  workspace: [
    { id: "workspace", icon: List, label: "文件列表" },
  ],
  openclawDashboard: [
    { id: "models", icon: LayoutGrid, label: "Models" },
    { id: "env", icon: Database, label: "环境变量" },
    { id: "gateway", icon: Wifi, label: "Gateway" },
    { id: "channels", icon: MessageSquare, label: "Channels" },
    { id: "skills", icon: Code2, label: "Skills & Plugins" },
    { id: "tools", icon: Shield, label: "工具权限" },
    { id: "agents", icon: Cpu, label: "Agents 配置" },
    { id: "json", icon: FileJson, label: "JSON" },
  ],
  settings: [
    { id: "settings", icon: Settings, label: "通用设置" },
  ],
};

export const ResponsiveShell = forwardRef<HTMLDivElement, NavigationBadgeProps>(
  (
    { currentView, setCurrentView, openSettings, isMac, className, children },
    ref,
  ) => {
    const { t } = useTranslation();
    const DRAG_BAR_HEIGHT = isMac ? 28 : 0;

    // 确定当前选中的主菜单
    const activeMainMenu = useMemo(() => {
      if (currentView === "settings") return "settings";
      if (currentView === "sessions") return "sessions";
      if (currentView === "workspace") return "workspace";
      if (["models", "env", "gateway", "channels", "skills", "tools", "agents", "json", "providers"].includes(currentView)) {
        return "openclawDashboard";
      }
      return "sessions";
    }, [currentView]);

    // ─── Desktop Sidebar ─────────────────────────────────────────────────────
    // 显示当前主菜单的二级菜单
    const DesktopSidebar = () => {
      const subItems = SUB_MENU_ITEMS[activeMainMenu] || [];

      return (
        <aside
          className={cn(
            "hidden flex-col w-56 lg:w-64 border-r bg-muted/20 shrink-0 h-full",
            currentView === "sessions" ? "md:hidden" : "md:flex",
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

          {/* App logo / branding */}
          <div className="flex items-center h-14 px-4 shrink-0">
            <span className="font-bold text-lg tracking-tight text-primary select-none">
              Haipee
            </span>
          </div>

          <Separator className="opacity-40" />

          {/* 二级菜单导航 */}
          <ScrollArea className="flex-1">
            <nav className="flex flex-col gap-0.5 p-2 py-3">
              {subItems.length > 0 ? (
                subItems.map((item) => (
                  <Button
                    key={item.id}
                    variant="ghost"
                    className={cn(
                      "w-full justify-start h-10 px-3 rounded-md font-normal transition-colors",
                      currentView === item.id
                        ? "bg-primary/10 text-primary hover:bg-primary/15"
                        : "text-muted-foreground hover:text-foreground hover:bg-muted",
                    )}
                    onClick={() => setCurrentView(item.id)}
                  >
                    <item.icon className="w-4 h-4 mr-3 shrink-0" />
                    <span className="truncate">{item.label}</span>
                  </Button>
                ))
              ) : (
                <div className="px-3 py-4 text-sm text-muted-foreground text-center">
                  无二级菜单
                </div>
              )}
            </nav>
          </ScrollArea>

          <Separator className="opacity-40" />

          {/* 底部4个主菜单按钮 */}
          <div className="p-2 shrink-0">
            <div className="grid grid-cols-4 gap-1">
              {MAIN_MENU_ITEMS.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  className={cn(
                    "flex flex-col items-center justify-center gap-1 py-2 px-1 rounded-md text-xs transition-colors",
                    (item.id === "settings" && currentView === "settings") ||
                    (item.id !== "settings" && activeMainMenu === item.id)
                      ? "bg-primary/10 text-primary"
                      : "text-muted-foreground hover:text-foreground hover:bg-muted",
                  )}
                  onClick={() => {
                    if (item.id === "settings") {
                      openSettings();
                    } else {
                      setCurrentView(item.id);
                    }
                  }}
                >
                  <item.icon className="w-5 h-5" />
                  <span className="text-[10px] leading-none truncate max-w-full">
                    {t(item.labelKey, item.labelFallback)}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </aside>
      );
    };

    // ─── Mobile Bottom Navigation ──────────────────────────────────────────
    // 只在移动端显示（桌面端按钮在左侧边栏底部）
    const MobileBottomNav = () => (
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 border-t bg-background/95 backdrop-blur-sm safe-area-bottom shrink-0">
        <div className="flex items-stretch justify-around h-[56px]">
          {MAIN_MENU_ITEMS.map((item) => (
            <button
              key={item.id}
              type="button"
              className={cn(
                "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
                (item.id === "settings" && currentView === "settings") ||
                (item.id !== "settings" && activeMainMenu === item.id)
                  ? "text-primary"
                  : "text-muted-foreground hover:text-foreground",
              )}
              onClick={() => {
                if (item.id === "settings") {
                  openSettings();
                } else {
                  setCurrentView(item.id);
                }
              }}
            >
              <item.icon className="w-[22px] h-[22px]" />
              <span className="text-xs leading-none truncate max-w-[56px]">
                {t(item.labelKey, item.labelFallback)}
              </span>
            </button>
          ))}
        </div>
      </nav>
    );

    // ─── Mobile Top Bar ─────────────────────────────────────────────────────
    const MobileTopBar = () => {
      if (currentView === "sessions") return null;

      const mainItem = MAIN_MENU_ITEMS.find((i) => i.id === activeMainMenu);
      const label = currentView === "settings"
        ? t("settings.title", "Settings")
        : (mainItem?.labelFallback ?? t("app.title", "Haipee"));

      return (
        <header
          className="md:hidden shrink-0 border-b bg-background/95 backdrop-blur-sm flex items-end px-4 pb-3"
          style={
            {
              paddingTop: `${DRAG_BAR_HEIGHT + 12}px`,
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

    return (
      <div
        ref={ref}
        className={cn(
          "flex h-[100dvh] w-full overflow-hidden bg-background text-foreground",
          className,
        )}
      >
        <DesktopSidebar />

        {/* Main content column */}
        <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
          <MobileTopBar />

          {/* Scrollable content area; children own their paddings */}
          <main className="flex-1 min-h-0 overflow-y-auto overflow-x-hidden relative">
            {children}
          </main>

          <MobileBottomNav />
          {/* Bottom nav spacer so content isn't hidden behind fixed bar */}
          <div className="md:hidden h-[56px] shrink-0 pointer-events-none" />
        </div>
      </div>
    );
  },
);
ResponsiveShell.displayName = "ResponsiveShell";
