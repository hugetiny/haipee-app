import { List } from "lucide-react";
import { useTranslation } from "react-i18next";
import { cn } from "@/lib/utils";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";

interface TocItem {
  index: number;
  preview: string;
  ts?: number;
}

interface SessionTocSidebarProps {
  items: TocItem[];
  onItemClick: (index: number) => void;
}

export function SessionTocSidebar({
  items,
  onItemClick,
}: SessionTocSidebarProps) {
  const { t } = useTranslation();
  if (items.length <= 2) return null;

  return (
    <div className="w-56 border-l shrink-0 hidden xl:block">
      <div className="px-3 py-2 border-b">
        <div className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
          <List className="size-3.5" />
          <span>{t("sessionManager.tocTitle")}</span>
        </div>
      </div>
      <ScrollArea className="h-[calc(100%-36px)]">
        <div className="p-1.5 space-y-0.5">
          {items.map((item, tocIndex) => (
            <button
              key={item.index}
              type="button"
              onClick={() => onItemClick(item.index)}
              className={cn(
                "w-full text-left px-2 py-1 rounded text-xs transition-colors",
                "hover:bg-accent hover:text-accent-foreground",
                "flex items-start gap-1.5",
              )}
            >
              <span className="shrink-0 w-4 h-4 rounded bg-muted text-muted-foreground text-[10px] flex items-center justify-center">
                {tocIndex + 1}
              </span>
              <span className="line-clamp-2">{item.preview}</span>
            </button>
          ))}
        </div>
      </ScrollArea>
    </div>
  );
}

interface SessionTocSheetProps {
  items: TocItem[];
  onItemClick: (index: number) => void;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function SessionTocSheet({
  items,
  onItemClick,
  open,
  onOpenChange,
}: SessionTocSheetProps) {
  const { t } = useTranslation();
  if (items.length <= 2) return null;

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-72 p-0">
        <SheetHeader className="sr-only">
          <SheetTitle>{t("sessionManager.tocTitle")}</SheetTitle>
        </SheetHeader>
        <div className="flex flex-col h-full">
          <div className="px-3 py-2 border-b flex items-center gap-2">
            <List className="size-4 text-muted-foreground" />
            <span className="text-sm font-medium">
              {t("sessionManager.tocTitle")}
            </span>
          </div>
          <ScrollArea className="flex-1">
            <div className="p-2 space-y-0.5">
              {items.map((item, tocIndex) => (
                <button
                  key={item.index}
                  type="button"
                  onClick={() => {
                    onItemClick(item.index);
                    onOpenChange(false);
                  }}
                  className={cn(
                    "w-full text-left px-2 py-1.5 rounded text-sm transition-colors",
                    "hover:bg-accent hover:text-accent-foreground",
                    "flex items-start gap-2",
                  )}
                >
                  <span className="shrink-0 w-5 h-5 rounded bg-muted text-muted-foreground text-xs flex items-center justify-center">
                    {tocIndex + 1}
                  </span>
                  <span className="line-clamp-2">{item.preview}</span>
                </button>
              ))}
            </div>
          </ScrollArea>
        </div>
      </SheetContent>
    </Sheet>
  );
}
