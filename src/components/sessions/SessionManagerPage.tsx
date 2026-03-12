import { useEffect, useMemo, useRef, useState } from "react";
import { useSessionSearch } from "@/hooks/useSessionSearch";
import { useTranslation } from "react-i18next";
import { toast } from "sonner";
import {
  RefreshCw,
  Search,
  Play,
  Trash2,
  MessageSquare,
  X,
  Menu,
  Plus,
  MessageSquarePlus,
  Send,
  FolderOpen,
  KeyRound,
  History,
  Settings,
} from "lucide-react";
import {
  useDeleteSessionMutation,
  useSendMessageMutation,
  useSessionMessagesQuery,
  useSessionsQuery,
} from "@/lib/query";
import { useActiveOpenClawInstance } from "@/hooks/useOpenClaw";
import { sessionsApi } from "@/lib/api";
import type { SessionMeta } from "@/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
} from "@/components/ui/select";
import { ScrollArea } from "@/components/ui/scroll-area";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { extractErrorMessage } from "@/utils/errorUtils";
import { isMac } from "@/lib/platform";
import { ProviderIcon } from "@/components/ProviderIcon";
import { SessionItem } from "./SessionItem";
import { SessionMessageItem } from "./SessionMessageItem";
import { SessionTocSidebar } from "./SessionToc";
import {
  formatSessionTitle,
  formatTimestamp,
  getProviderIconName,
  getSessionKey,
} from "./utils";

type ProviderFilter =
  | "all"
  | "codex"
  | "claude"
  | "opencode"
  | "openclaw"
  | "gemini";

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

export function SessionManagerPage({
  appId,
  setCurrentView,
  openSettings,
}: {
  appId: string;
  setCurrentView?: (view: string) => void;
  openSettings?: () => void;
}) {
  const { t } = useTranslation();
  const { data, isLoading } = useSessionsQuery();
  const sessions = Array.isArray(data) ? data : [];
  const detailRef = useRef<HTMLDivElement | null>(null);
  const messagesEndRef = useRef<HTMLDivElement | null>(null);
  const messageRefs = useRef<Map<number, HTMLDivElement>>(new Map());
  const [activeMessageIndex, setActiveMessageIndex] = useState<number | null>(
    null,
  );
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<SessionMeta | null>(null);
  const searchInputRef = useRef<HTMLInputElement | null>(null);

  const [search, setSearch] = useState("");
  const [providerFilter, setProviderFilter] = useState<ProviderFilter>(
    appId as ProviderFilter,
  );
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [messageInput, setMessageInput] = useState("");

  const { activeInstance } = useActiveOpenClawInstance();
  const sendMessageMutation = useSendMessageMutation();
  const { search: searchSessions } = useSessionSearch({
    sessions,
    providerFilter,
  });

  const filteredSessions = useMemo(() => {
    return searchSessions(search);
  }, [searchSessions, search]);

  useEffect(() => {
    if (filteredSessions.length === 0) {
      setSelectedKey(null);
      return;
    }
    const exists = selectedKey
      ? filteredSessions.some(
        (session) => getSessionKey(session) === selectedKey,
      )
      : false;
    if (!exists) {
      setSelectedKey(getSessionKey(filteredSessions[0]));
    }
  }, [filteredSessions, selectedKey]);

  const selectedSession = useMemo(() => {
    return (
      filteredSessions.find(
        (session) => getSessionKey(session) === selectedKey,
      ) || null
    );
  }, [filteredSessions, selectedKey]);

  const { data: messages = [], isLoading: isLoadingMessages } =
    useSessionMessagesQuery(
      selectedSession?.providerId,
      selectedSession?.sourcePath,
    );
  const deleteSessionMutation = useDeleteSessionMutation();

  const userMessagesToc = useMemo(() => {
    return messages
      .map((msg, index) => ({ msg, index }))
      .filter(({ msg }) => msg.role.toLowerCase() === "user")
      .map(({ msg, index }) => ({
        index,
        preview:
          msg.content.slice(0, 50) + (msg.content.length > 50 ? "..." : ""),
        ts: msg.ts,
      }));
  }, [messages]);

  const scrollToMessage = (index: number) => {
    const el = messageRefs.current.get(index);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "center" });
      setActiveMessageIndex(index);
      setTimeout(() => setActiveMessageIndex(null), 2000);
    }
  };

  const handleCopy = async (text: string, successMessage: string) => {
    try {
      await navigator.clipboard.writeText(text);
      toast.success(successMessage);
    } catch (error) {
      toast.error(
        extractErrorMessage(error) ||
        t("common.error", { defaultValue: "Copy failed" }),
      );
    }
  };

  const handleResume = async () => {
    if (!selectedSession?.resumeCommand) return;

    if (!isMac()) {
      await handleCopy(
        selectedSession.resumeCommand,
        t("sessionManager.resumeCommandCopied"),
      );
      return;
    }

    try {
      await sessionsApi.launchTerminal({
        command: selectedSession.resumeCommand,
        cwd: selectedSession.projectDir ?? undefined,
      });
      toast.success(t("sessionManager.terminalLaunched"));
    } catch (error) {
      const fallback = selectedSession.resumeCommand;
      await handleCopy(fallback, t("sessionManager.resumeFallbackCopied"));
      toast.error(extractErrorMessage(error) || t("sessionManager.openFailed"));
    }
  };

  const handleDeleteConfirm = async () => {
    if (!deleteTarget?.sourcePath || deleteSessionMutation.isPending) {
      return;
    }

    setDeleteTarget(null);
    await deleteSessionMutation.mutateAsync({
      providerId: deleteTarget.providerId,
      sessionId: deleteTarget.sessionId,
      sourcePath: deleteTarget.sourcePath,
    });
  };

  const handleSendMessage = async () => {
    if (
      !selectedSession ||
      !messageInput.trim() ||
      sendMessageMutation.isPending
    ) {
      return;
    }

    try {
      await sendMessageMutation.mutateAsync({
        providerId: selectedSession.providerId,
        sourcePath: selectedSession.sourcePath!,
        message: messageInput.trim(),
        instance: activeInstance,
      });
      setMessageInput("");
      setTimeout(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
      }, 100);
    } catch (error) {
      // Error handled by mutation toast
    }
  };

  const renderSessionList = () => (
    <div className="flex flex-col flex-1 min-h-0 bg-muted/10">
      <div className="py-3 px-4 border-b shrink-0">
        {isSearchOpen ? (
          <div className="relative flex-1">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
            <Input
              ref={searchInputRef}
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder={t("sessionManager.searchPlaceholder")}
              className="h-9 pl-9 pr-9 text-sm rounded-full bg-background"
              autoFocus
              onKeyDown={(e) => {
                if (e.key === "Escape") {
                  setIsSearchOpen(false);
                  setSearch("");
                }
              }}
              onBlur={() => {
                if (search.trim() === "") setIsSearchOpen(false);
              }}
            />
            <Button
              variant="ghost"
              size="icon"
              className="absolute right-1 top-1/2 -translate-y-1/2 size-7 rounded-full text-muted-foreground"
              onClick={() => {
                setIsSearchOpen(false);
                setSearch("");
              }}
            >
              <X className="size-4" />
            </Button>
          </div>
        ) : (
          <div className="flex items-center justify-between gap-2 h-9">
            <div className="flex items-center gap-2">
              <span className="text-sm font-semibold">
                {t("sessionManager.sessionList")}
              </span>
              <Badge
                variant="secondary"
                className="text-xs rounded-full px-1.5 py-0 h-5 flex items-center justify-center"
              >
                {filteredSessions.length}
              </Badge>
            </div>
            <div className="flex items-center gap-1">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-8 rounded-full"
                    onClick={() => {
                      setIsSearchOpen(true);
                      setTimeout(() => searchInputRef.current?.focus(), 0);
                    }}
                  >
                    <Search className="size-4" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>
                  {t("sessionManager.searchSessions")}
                </TooltipContent>
              </Tooltip>

              <Select
                value={providerFilter}
                onValueChange={(value) =>
                  setProviderFilter(value as ProviderFilter)
                }
              >
                <Tooltip>
                  <TooltipTrigger asChild>
                    <SelectTrigger className="size-8 rounded-full p-0 flex items-center justify-center border-0 bg-transparent hover:bg-muted focus:ring-0 shadow-none">
                      <ProviderIcon
                        icon={
                          providerFilter === "all"
                            ? "apps"
                            : getProviderIconName(providerFilter)
                        }
                        name={providerFilter}
                        size={16}
                      />
                    </SelectTrigger>
                  </TooltipTrigger>
                  <TooltipContent>
                    {providerFilter === "all"
                      ? t("sessionManager.providerFilterAll")
                      : providerFilter}
                  </TooltipContent>
                </Tooltip>
                <SelectContent side="bottom" align="end">
                  <SelectItem value="all">
                    <div className="flex items-center gap-2">
                      <ProviderIcon icon="apps" name="all" size={14} />
                      <span>{t("sessionManager.providerFilterAll")}</span>
                    </div>
                  </SelectItem>
                  <SelectItem value="codex">
                    <div className="flex items-center gap-2">
                      <ProviderIcon icon="openai" name="codex" size={14} />
                      <span>Codex</span>
                    </div>
                  </SelectItem>
                  <SelectItem value="claude">
                    <div className="flex items-center gap-2">
                      <ProviderIcon icon="claude" name="claude" size={14} />
                      <span>Claude Code</span>
                    </div>
                  </SelectItem>
                  <SelectItem value="opencode">
                    <div className="flex items-center gap-2">
                      <ProviderIcon icon="opencode" name="opencode" size={14} />
                      <span>OpenCode</span>
                    </div>
                  </SelectItem>
                  <SelectItem value="openclaw">
                    <div className="flex items-center gap-2">
                      <ProviderIcon icon="openclaw" name="openclaw" size={14} />
                      <span>OpenClaw</span>
                    </div>
                  </SelectItem>
                  <SelectItem value="gemini">
                    <div className="flex items-center gap-2">
                      <ProviderIcon icon="gemini" name="gemini" size={14} />
                      <span>Gemini CLI</span>
                    </div>
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        )}
      </div>
      <div className="flex-1 min-h-0 overflow-y-auto no-scrollbar">
        <div className="p-3">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <RefreshCw className="size-5 animate-spin text-muted-foreground" />
            </div>
          ) : filteredSessions.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <MessageSquare className="size-8 text-muted-foreground/50 mb-2" />
              <p className="text-sm text-muted-foreground">
                {t("sessionManager.noSessions")}
              </p>
            </div>
          ) : (
            <div className="space-y-1">
              {filteredSessions.map((session) => {
                const isSelected =
                  selectedKey !== null &&
                  getSessionKey(session) === selectedKey;
                return (
                  <SessionItem
                    key={getSessionKey(session)}
                    session={session}
                    isSelected={isSelected}
                    onSelect={(key) => {
                      setSelectedKey(key);
                      setIsMobileDrawerOpen(false);
                    }}
                  />
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* App Navigation for Desktop Unified Sidebar */}
      <div className="hidden md:flex flex-col gap-0.5 p-2 py-3 border-t shrink-0 mt-auto bg-muted/10">
        <div className="flex flex-wrap gap-1 items-center justify-center">
          {NAV_ITEMS.map((item) => (
            <Tooltip key={item.id}>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className={`rounded-full size-10 transition-colors ${item.id === "sessions"
                      ? "bg-primary/10 text-primary hover:bg-primary/15"
                      : "text-muted-foreground hover:text-foreground hover:bg-muted"
                    }`}
                  onClick={() => setCurrentView?.(item.id)}
                >
                  <item.icon className="w-5 h-5" />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right">
                {t(item.labelKey, item.labelFallback)}
              </TooltipContent>
            </Tooltip>
          ))}
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="rounded-full size-10 transition-colors text-muted-foreground hover:text-foreground hover:bg-muted"
                onClick={() => openSettings?.()}
              >
                <Settings className="w-5 h-5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="right">
              {t("common.settings", "Settings")}
            </TooltipContent>
          </Tooltip>
        </div>
      </div>
    </div>
  );

  return (
    <TooltipProvider>
      <div className="absolute inset-0 flex flex-col md:flex-row overflow-hidden bg-background">
        <div
          className="md:hidden flex items-center justify-between px-2 h-14 border-b bg-background/95 shrink-0 safe-area-top"
          style={{
            paddingTop: isMac() ? "28px" : 0,
            height: isMac() ? "84px" : "56px",
          }}
        >
          <div className="flex items-center gap-1 w-[80px]">
            <Sheet
              open={isMobileDrawerOpen}
              onOpenChange={setIsMobileDrawerOpen}
            >
              <SheetTrigger asChild>
                <Button variant="ghost" size="icon" className="rounded-full">
                  <Menu className="size-5" />
                </Button>
              </SheetTrigger>
              <SheetContent
                side="left"
                className="p-0 w-[85vw] max-w-sm flex flex-col border-r-0"
              >
                {renderSessionList()}
              </SheetContent>
            </Sheet>
          </div>
          <div className="font-semibold text-base truncate flex-1 text-center select-none">
            {t("sessionManager.title", "Sessions")}
          </div>
          <div className="flex items-center justify-end gap-1 w-[80px]">
            <Button variant="ghost" size="icon" className="rounded-full">
              <MessageSquarePlus className="size-5" />
            </Button>
          </div>
        </div>

        {/* Left Sidebar - Hidden on mobile, shown on tablet & desktop */}
        <div
          className="hidden md:flex flex-col w-[220px] lg:w-[260px] border-r border-border/50 shrink-0 h-full"
          style={{ paddingTop: isMac() ? 28 : 0 }}
        >
          {renderSessionList()}
        </div>

        <div
          className="flex-1 flex flex-col min-w-0 h-full bg-background relative overflow-hidden"
          ref={detailRef}
          style={{ paddingTop: isMac() ? 28 : 0 }}
        >
          {!selectedSession ? (
            <div className="flex-1 flex flex-col items-center justify-center text-primary/40 p-8 h-full">
              <div className="size-16 md:size-20 rounded-full bg-primary/5 flex items-center justify-center mb-6">
                <MessageSquare className="size-8 md:size-10" />
              </div>
              <h2 className="text-xl md:text-2xl font-medium text-foreground mb-2">
                {t("sessionManager.welcome", {
                  defaultValue: "How can I help you today?",
                })}
              </h2>
              <p className="text-sm text-center max-w-sm text-primary/60">
                {t("sessionManager.selectSession", {
                  defaultValue:
                    "Select a session from the sidebar or start a new chat.",
                })}
              </p>
            </div>
          ) : (
            <div className="flex-1 flex flex-col overflow-hidden h-full relative">
              {/* Actions Header - Desktop */}
              <div className="absolute top-4 right-4 z-10 hidden md:flex items-center gap-2 pointer-events-auto">
                {isMac() && (
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Button
                        size="icon"
                        variant="ghost"
                        className="size-8 rounded-full bg-background/50 backdrop-blur-md text-muted-foreground hover:text-foreground shadow-sm border border-border/50"
                        onClick={() => void handleResume()}
                        disabled={
                          !selectedSession.resumeCommand ||
                          activeInstance?.type === "remote"
                        }
                        title={
                          activeInstance?.type === "remote"
                            ? t(
                              "sessionManager.remoteNoTerminal",
                              "Terminal launch not available for remote instances",
                            )
                            : undefined
                        }
                      >
                        <Play className="size-4 pl-0.5" />
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>
                      {t("sessionManager.resume", { defaultValue: "Resume" })}
                    </TooltipContent>
                  </Tooltip>
                )}
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button
                      size="icon"
                      variant="ghost"
                      className="size-8 rounded-full bg-destructive/10 backdrop-blur-md text-destructive hover:bg-destructive hover:text-white shadow-sm border border-destructive/20 transition-colors"
                      onClick={() => setDeleteTarget(selectedSession)}
                      disabled={
                        !selectedSession.sourcePath ||
                        deleteSessionMutation.isPending
                      }
                      aria-label={t("sessionManager.delete", {
                        defaultValue: "删除会话",
                      })}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    {t("sessionManager.delete", { defaultValue: "Delete" })}
                  </TooltipContent>
                </Tooltip>
              </div>

              <div className="flex-1 flex h-full overflow-hidden">
                <div className="flex-1 flex flex-col relative h-full">
                  <ScrollArea className="flex-1">
                    <div className="p-4 md:p-8 max-w-4xl mx-auto min-h-full pb-40">
                      {isLoadingMessages ? (
                        <div className="flex flex-col items-center justify-center py-20">
                          <RefreshCw className="size-6 animate-spin text-primary/50 mb-4" />
                          <p className="text-sm text-muted-foreground">
                            Loading history...
                          </p>
                        </div>
                      ) : (
                        <div className="flex flex-col space-y-2 pb-6">
                          <div className="flex flex-col items-center py-12 px-4 text-center">
                            <div className="size-12 rounded-full bg-primary/10 flex items-center justify-center mb-4 text-primary">
                              <ProviderIcon
                                icon={getProviderIconName(
                                  selectedSession.providerId,
                                )}
                                name={selectedSession.providerId}
                                size={24}
                              />
                            </div>
                            <h1 className="text-2xl font-semibold">
                              {formatSessionTitle(selectedSession)}
                            </h1>
                            <p className="text-muted-foreground text-sm mt-1">
                              {formatTimestamp(
                                selectedSession.lastActiveAt ??
                                selectedSession.createdAt,
                              )}
                            </p>
                          </div>
                          {messages.map((message, index) => (
                            <SessionMessageItem
                              key={`${message.role}-${index}`}
                              message={message}
                              index={index}
                              isActive={activeMessageIndex === index}
                              setRef={(el) => {
                                if (el) messageRefs.current.set(index, el);
                              }}
                              onCopy={(content) =>
                                handleCopy(
                                  content,
                                  t("sessionManager.messageCopied", {
                                    defaultValue: "Copied",
                                  }),
                                )
                              }
                            />
                          ))}
                          <div ref={messagesEndRef} className="h-4" />
                        </div>
                      )}
                    </div>
                  </ScrollArea>

                  {selectedSession.providerId === "openclaw" && (
                    <div className="absolute bottom-0 left-0 right-0 p-4 pb-6 bg-gradient-to-t from-background via-background/95 to-transparent z-20 pointer-events-none">
                      <div className="relative flex items-end gap-2 w-full max-w-4xl mx-auto bg-muted/40 dark:bg-muted/20 backdrop-blur-xl border border-border/60 rounded-[28px] p-2 focus-within:bg-background focus-within:ring-4 focus-within:ring-primary/10 focus-within:border-primary/30 transition-all shadow-sm pointer-events-auto mt-2">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="shrink-0 size-9 md:size-10 rounded-full text-muted-foreground hover:text-foreground hover:bg-muted/50 transition-colors"
                        >
                          <Plus className="size-5" />
                        </Button>
                        <textarea
                          value={messageInput}
                          onChange={(e) => setMessageInput(e.target.value)}
                          placeholder={t("sessionManager.chatPlaceholder", {
                            defaultValue: "Ask OpenClaw anything...",
                          })}
                          className="flex-1 min-h-[40px] max-h-[200px] py-2 md:py-2.5 px-2 bg-transparent resize-none focus:outline-none text-sm md:text-base leading-relaxed text-foreground placeholder-muted-foreground/70 scrollbar-none"
                          rows={1}
                          onKeyDown={(e) => {
                            if (e.key === "Enter" && !e.shiftKey) {
                              e.preventDefault();
                              handleSendMessage();
                            }
                          }}
                        />
                        <Button
                          size="icon"
                          className="shrink-0 size-9 md:size-10 rounded-full bg-primary text-primary-foreground shadow-md group hover:scale-105 transition-all w-9 h-9"
                          onClick={handleSendMessage}
                          disabled={
                            !messageInput.trim() ||
                            sendMessageMutation.isPending
                          }
                        >
                          {sendMessageMutation.isPending ? (
                            <RefreshCw className="size-4 animate-spin" />
                          ) : (
                            <Send className="size-4 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform" />
                          )}
                        </Button>
                      </div>
                      <div className="text-center mt-2 text-xs md:text-xs text-muted-foreground pointer-events-auto">
                        OpenClaw can make mistakes. Consider verifying its
                        actions.
                      </div>
                    </div>
                  )}
                </div>

                <div className="hidden lg:block w-[240px] xl:w-[260px] shrink-0 transition-all border-l border-border/50 bg-background/50">
                  <SessionTocSidebar
                    items={userMessagesToc}
                    onItemClick={scrollToMessage}
                  />
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
      <ConfirmDialog
        isOpen={Boolean(deleteTarget)}
        title={t("sessionManager.deleteConfirmTitle", {
          defaultValue: "删除会话",
        })}
        message={
          deleteTarget
            ? t("sessionManager.deleteConfirmMessage", {
              defaultValue:
                "将永久删除本地会话“{{title}}”\nSession ID: {{sessionId}}\n\n此操作不可恢复。",
              title: formatSessionTitle(deleteTarget),
              sessionId: deleteTarget.sessionId,
            })
            : ""
        }
        confirmText={t("sessionManager.deleteConfirmAction", {
          defaultValue: "删除会话",
        })}
        cancelText={t("common.cancel", { defaultValue: "取消" })}
        variant="destructive"
        onConfirm={() => void handleDeleteConfirm()}
        onCancel={() => {
          if (!deleteSessionMutation.isPending) {
            setDeleteTarget(null);
          }
        }}
      />
    </TooltipProvider>
  );
}
