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
        "w-full text-left rounded-md px-2 py-1.5 transition-colors flex items-center gap-2",
        isSelected
          ? "bg-accent text-accent-foreground"
          : "hover:bg-accent hover:text-accent-foreground",
      )}
    >
      <ProviderIcon
        icon={getProviderIconName(session.providerId)}
        name={session.providerId}
        size={16}
        className="shrink-0"
      />
      <div className="flex-1 min-w-0">
        <div className="text-sm truncate">{title}</div>
        <div className="text-xs text-muted-foreground truncate">
          {lastActive ? formatRelativeTime(lastActive, t) : t("common.unknown")}
        </div>
      </div>
    </button>
  );
}
