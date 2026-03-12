import { Copy, Sparkles, User } from "lucide-react";
import { useTranslation } from "react-i18next";

import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";
import type { SessionMessage } from "@/types";

interface SessionMessageItemProps {
  message: SessionMessage;
  index: number;
  isActive: boolean;
  setRef: (el: HTMLDivElement | null) => void;
  onCopy: (content: string) => void;
}

export function SessionMessageItem({
  message,
  isActive,
  setRef,
  onCopy,
}: SessionMessageItemProps) {
  const { t } = useTranslation();
  const isUser = message.role.toLowerCase() === "user";

  return (
    <div
      ref={setRef}
      className={cn(
        "flex w-full mb-6 group transition-all",
        isUser ? "justify-end" : "justify-start",
        isActive &&
        "bg-primary/5 rounded-xl outline outline-2 outline-primary outline-offset-4",
      )}
    >
      <div
        className={cn(
          "flex max-w-[85%] md:max-w-[75%] gap-3 md:gap-4",
          isUser ? "flex-row-reverse" : "flex-row",
        )}
      >
        {/* Avatar/Icon Area */}
        <div
          className={cn(
            "size-8 md:size-9 shrink-0 rounded-full flex items-center justify-center transition-colors shadow-sm",
            isUser
              ? "bg-muted"
              : "bg-primary/10 text-primary border border-primary/20",
          )}
        >
          {isUser ? (
            <User className="size-4 md:size-5" />
          ) : (
            <Sparkles className="size-4 md:size-5" />
          )}
        </div>

        {/* Content Area */}
        <div
          className={cn(
            "flex flex-col min-w-0",
            isUser ? "items-end" : "items-start",
          )}
        >
          <div
            className={cn(
              "relative px-4 py-2.5 md:px-5 md:py-3 rounded-[20px] text-sm md:text-base leading-relaxed break-words",
              isUser
                ? "bg-muted text-foreground border border-border/40 rounded-tr-none shadow-sm"
                : "bg-transparent text-foreground md:px-1",
            )}
          >
            <div className="whitespace-pre-wrap">{message.content}</div>

            {/* Actions for messages */}
            <div
              className={cn(
                "absolute -bottom-10 opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-1",
                isUser ? "right-0" : "left-0",
              )}
            >
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-8 rounded-full hover:bg-muted"
                    onClick={() => onCopy(message.content)}
                  >
                    <Copy className="size-3.5 text-muted-foreground" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>
                  {t("sessionManager.copyMessage", { defaultValue: "Copy" })}
                </TooltipContent>
              </Tooltip>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
