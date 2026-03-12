import { useTranslation } from "react-i18next";
import { cn } from "@/lib/utils";
import { ProviderIcon } from "@/components/ProviderIcon";
import type { SessionMeta } from "@/types";
import {
  formatRelativeTime,
  formatSessionTitle,
  getProviderIconName,
  getSessionKey,
} from "./utils";

interface SessionItemProps {
  session: SessionMeta;
  isSelected: boolean;
  onSelect: (key: string) => void;
}

export function SessionItem({
  session,
  isSelected,
  onSelect,
}: SessionItemProps) {
  const { t } = useTranslation();
  const title = formatSessionTitle(session);
  const lastActive = session.lastActiveAt || session.createdAt || undefined;
  const sessionKey = getSessionKey(session);

  return (
    <button
      type="button"
      onClick={() => onSelect(sessionKey)}
      className={cn(
        "w-full text-left rounded-xl px-4 py-2.5 transition-all group flex items-start gap-3",
        isSelected
          ? "bg-primary/10 text-primary shadow-sm"
          : "hover:bg-muted text-muted-foreground hover:text-foreground",
      )}
    >
      <div
        className={cn(
          "size-8 md:size-10 rounded-full flex items-center justify-center shrink-0 transition-colors",
          isSelected ? "bg-primary/20" : "bg-muted group-hover:bg-background",
        )}
      >
        <ProviderIcon
          icon={getProviderIconName(session.providerId)}
          name={session.providerId}
          size={18}
        />
      </div>

      <div className="flex-1 min-w-0 flex flex-col justify-center py-0.5">
        <div className="flex items-center justify-between gap-2 overflow-hidden">
          <span
            className={cn(
              "text-sm font-medium truncate",
              isSelected ? "text-primary" : "text-foreground",
            )}
          >
            {title}
          </span>
        </div>

        <div className="flex flex-col gap-0.5 mt-0.5">
          {session.summary ? (
            <span
              className="text-xs text-muted-foreground line-clamp-2 leading-snug"
              title={session.summary}
            >
              {session.summary}
            </span>
          ) : session.projectDir ? (
            <span
              className="text-xs text-muted-foreground truncate opacity-80 font-mono"
              aria-label="Project Directory"
              title={session.projectDir}
            >
              {session.projectDir
                .replace(/^\/Users\/[^/]+/, "~")
                .replace(/^\/home\/[^/]+/, "~")}
            </span>
          ) : (
            <span className="text-xs text-muted-foreground opacity-60 font-mono">
              #{session.sessionId.slice(0, 8)}
            </span>
          )}
          <div className="flex items-center gap-1.5 text-xs opacity-70 mt-1">
            <span className="truncate">
              {lastActive
                ? formatRelativeTime(lastActive, t)
                : t("common.unknown")}
            </span>
          </div>
        </div>
      </div>
    </button>
  );
}
