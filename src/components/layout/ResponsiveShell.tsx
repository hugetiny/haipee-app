import { forwardRef } from "react";
import { cn } from "@/lib/utils";
import { useTranslation } from "react-i18next";
import {
  FolderOpen,
  KeyRound,
  History,
  Settings,
  MoreHorizontal,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetTrigger,
  SheetTitle,
  SheetHeader,
} from "@/components/ui/sheet";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";

export type AppView =
  | "providers"
  | "settings"
  | "sessions"
  | "workspace"
  | "openclawDashboard"
  | string;

interface NavigationBadgeProps {
  currentView: AppView;
  setCurrentView: (view: AppView) => void;
  openSettings: () => void;
  isMac: boolean;
  className?: string;
  children: React.ReactNode;
}

const NAV_ITEMS = [
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "Sessions",
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
] as const;

// First 4 items shown in bottom nav, rest in "More" sheet trigger
const MOBILE_VISIBLE_COUNT = 4;

export const ResponsiveShell = forwardRef<HTMLDivElement, NavigationBadgeProps>(
  (
    { currentView, setCurrentView, openSettings, isMac, className, children },
    ref,
  ) => {
    const { t } = useTranslation();
    const DRAG_BAR_HEIGHT = isMac ? 28 : 0;

    const isSettingsView = currentView === "settings";

    // ─── Desktop Sidebar ─────────────────────────────────────────────────────
    const DesktopSidebar = () => (
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
            OpenClaw Base
          </span>
        </div>

        <Separator className="opacity-40" />

        {/* Primary navigation */}
        <ScrollArea className="flex-1">
          <nav className="flex flex-col gap-0.5 p-2 py-3">
            {NAV_ITEMS.map((item) => (
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
                <span className="truncate">
                  {t(item.labelKey, item.labelFallback)}
                </span>
              </Button>
            ))}
          </nav>
        </ScrollArea>

        <Separator className="opacity-40" />

        {/* Settings at bottom */}
        <div className="p-2 py-3 shrink-0">
          <Button
            variant="ghost"
            className={cn(
              "w-full justify-start h-10 px-3 rounded-md font-normal transition-colors",
              isSettingsView
                ? "bg-primary/10 text-primary hover:bg-primary/15"
                : "text-muted-foreground hover:text-foreground hover:bg-muted",
            )}
            onClick={openSettings}
          >
            <Settings className="w-4 h-4 mr-3 shrink-0" />
            <span className="truncate">{t("common.settings", "Settings")}</span>
          </Button>
        </div>
      </aside>
    );

    // ─── Mobile Bottom Navigation ──────────────────────────────────────────
    const MobileBottomNav = () => {
      const visibleItems = NAV_ITEMS.slice(0, MOBILE_VISIBLE_COUNT);
      const overflowItems = NAV_ITEMS.slice(MOBILE_VISIBLE_COUNT);
      const isOverflowActive =
        overflowItems.some((i) => i.id === currentView) || isSettingsView;

      return (
        <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 border-t bg-background/95 backdrop-blur-sm safe-area-bottom shrink-0">
          <div className="flex items-stretch justify-around h-[56px]">
            {visibleItems.map((item) => (
              <button
                key={item.id}
                type="button"
                className={cn(
                  "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
                  currentView === item.id
                    ? "text-primary"
                    : "text-muted-foreground hover:text-foreground",
                )}
                onClick={() => setCurrentView(item.id)}
              >
                <item.icon className="w-[22px] h-[22px]" />
                <span className="text-xs leading-none truncate max-w-[56px]">
                  {t(item.labelKey, item.labelFallback)}
                </span>
              </button>
            ))}

            {/* "More" sheet for overflow items */}
            <Sheet>
              <SheetTrigger asChild>
                <button
                  type="button"
                  className={cn(
                    "flex-1 flex flex-col items-center justify-center gap-0.5 px-1 text-xs transition-colors",
                    isOverflowActive
                      ? "text-primary"
                      : "text-muted-foreground hover:text-foreground",
                  )}
                >
                  <MoreHorizontal className="w-[22px] h-[22px]" />
                  <span className="text-xs leading-none">
                    {t("common.more", "More")}
                  </span>
                </button>
              </SheetTrigger>
              <SheetContent
                side="bottom"
                className="rounded-t-2xl max-h-[70vh]"
              >
                <SheetHeader className="pb-4">
                  <SheetTitle className="text-left">
                    {t("common.menu", "Menu")}
                  </SheetTitle>
                </SheetHeader>
                <div className="grid grid-cols-4 gap-3 pb-6">
                  {overflowItems.map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      className={cn(
                        "flex flex-col items-center justify-center gap-2 rounded-xl py-4 text-xs transition-colors",
                        currentView === item.id
                          ? "bg-primary/10 text-primary"
                          : "bg-muted/50 text-muted-foreground hover:bg-muted hover:text-foreground",
                      )}
                      onClick={() => setCurrentView(item.id)}
                    >
                      <item.icon className="w-5 h-5" />
                      <span className="text-xs truncate max-w-[60px]">
                        {t(item.labelKey, item.labelFallback)}
                      </span>
                    </button>
                  ))}
                  <button
                    type="button"
                    className={cn(
                      "flex flex-col items-center justify-center gap-2 rounded-xl py-4 text-xs transition-colors",
                      isSettingsView
                        ? "bg-primary/10 text-primary"
                        : "bg-muted/50 text-muted-foreground hover:bg-muted hover:text-foreground",
                    )}
                    onClick={openSettings}
                  >
                    <Settings className="w-5 h-5" />
                    <span className="text-xs truncate max-w-[60px]">
                      {t("common.settings", "Settings")}
                    </span>
                  </button>
                </div>
              </SheetContent>
            </Sheet>
          </div>
        </nav>
      );
    };

    // ─── Mobile Top Bar ─────────────────────────────────────────────────────
    const MobileTopBar = () => {
      if (currentView === "sessions") return null;

      const label = isSettingsView
        ? t("settings.title", "Settings")
        : (NAV_ITEMS.find((i) => i.id === currentView)?.labelFallback ??
          t("app.title", "OpenClaw Base"));

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
