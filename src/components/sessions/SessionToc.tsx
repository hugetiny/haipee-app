import { List } from "lucide-react";
import { useTranslation } from "react-i18next";
import { cn } from "@/lib/utils";

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
    <div className="flex flex-col h-full w-full">
      <div className="p-3 border-b shrink-0">
        <div className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
          <List className="size-3.5" />
          <span>{t("sessionManager.tocTitle")}</span>
        </div>
      </div>
      <div className="flex-1 min-h-0 overflow-y-auto no-scrollbar">
        <div className="p-2 space-y-0.5">
          {items.map((item, tocIndex) => (
            <button
              key={item.index}
              type="button"
              onClick={() => onItemClick(item.index)}
              className={cn(
                "w-full text-left px-2 py-1.5 rounded text-xs transition-colors",
                "hover:bg-muted/80 text-muted-foreground hover:text-foreground",
                "flex items-start gap-2",
              )}
            >
              <span className="shrink-0 w-4 h-4 rounded-full bg-primary/10 text-primary text-xs flex items-center justify-center font-medium">
                {tocIndex + 1}
              </span>
              <span className="line-clamp-2 leading-snug">{item.preview}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
