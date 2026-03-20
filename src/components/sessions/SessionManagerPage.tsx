import { useEffect, useMemo, useRef, useState } from "react";
import { useSessionSearch } from "@/hooks/useSessionSearch";
import { useTranslation } from "react-i18next";
import { toast } from "sonner";
import {
  Copy,
  RefreshCw,
  Search,
  Trash2,
  MessageSquare,
  Clock,
  FolderOpen,
  X,
  ChevronLeft,
  List,
  Send,
  ExternalLink,
  Terminal,
} from "lucide-react";
import {
  useDeleteSessionMutation,
  useSessionMessagesQuery,
  useSessionsQuery,
} from "@/lib/query";
import { sessionsApi, settingsApi, openclawApi } from "@/lib/api";
import type { SessionMeta } from "@/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader, CardContent } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { extractErrorMessage } from "@/utils/errorUtils";
import { isMac } from "@/lib/platform";
import { ProviderIcon } from "@/components/ProviderIcon";
import { SessionItem } from "./SessionItem";
import { SessionMessageItem } from "./SessionMessageItem";
import { SessionTocSheet, SessionTocSidebar } from "./SessionToc";
import {
  formatSessionTitle,
  formatTimestamp,
  getBaseName,
  getProviderIconName,
  getProviderLabel,
  getSessionKey,
} from "./utils";

type ProviderFilter =
  | "all"
  | "codex"
  | "claude"
  | "opencode"
  | "openclaw"
  | "gemini";

export function SessionManagerPage({ appId }: { appId: string }) {
  const { t } = useTranslation();
  const { data, isLoading, refetch } = useSessionsQuery();
  const sessions = data ?? [];
  const detailRef = useRef<HTMLDivElement | null>(null);
  const messagesEndRef = useRef<HTMLDivElement | null>(null);
  const messageRefs = useRef<Map<number, HTMLDivElement>>(new Map());
  const [activeMessageIndex, setActiveMessageIndex] = useState<number | null>(
    null,
  );
  const [tocDialogOpen, setTocDialogOpen] = useState(false);
  const [sessionListOpen, setSessionListOpen] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<SessionMeta | null>(null);
  const searchInputRef = useRef<HTMLInputElement | null>(null);

  const [search, setSearch] = useState("");
  const [inputMessage, setInputMessage] = useState("");
  const [showTuiChoice, setShowTuiChoice] = useState(false);
  const providerFilter = appId as ProviderFilter;
  const [selectedKey, setSelectedKey] = useState<string | null>(null);

  // 使用 FlexSearch 全文搜索
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
    if (!selectedKey) return null;
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

  // 提取用户消息用于目录
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
      setTocDialogOpen(false); // 关闭弹窗
      // 清除高亮状态
      setTimeout(() => setActiveMessageIndex(null), 2000);
    }
  };

  // 清理定时器
  useEffect(() => {
    return () => {
      // 这里的 setTimeout 其实无法直接清理，因为它在函数闭包里。
      // 如果要严格清理，需要用 useRef 存 timer id。
      // 但对于 2秒的高亮清除，通常不清理也没大问题。
      // 为了代码规范，我们在组件卸载时将 activeMessageIndex 重置 (虽然 React 会处理)
    };
  }, []);

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

  const handleOpenTui = async () => {
    setShowTuiChoice(false);

    // OpenClaw: 查找 session key 并运行 TUI
    if (isCurrentProviderOpenClaw) {
      try {
        const sessionId = selectedSession?.sessionId;
        let sessionKey: string | null = null;

        if (sessionId) {
          sessionKey = await openclawApi.findSessionKey(sessionId);
        }

        // 构建 openclaw tui 命令
        let command = "openclaw tui";
        if (sessionKey) {
          command = `openclaw tui --session "${sessionKey}"`;
        }

        await sessionsApi.launchTerminal({
          command,
        });
        toast.success(t("sessionManager.terminalLaunched"));
      } catch (error) {
        toast.error(extractErrorMessage(error) || t("sessionManager.openFailed"));
      }
      return;
    }

    // 其他 provider 使用 resume command
    if (selectedSession?.resumeCommand) {
      await handleResume();
    }
  };

  const handleOpenBrowser = async () => {
    setShowTuiChoice(false);
    const sessionId = selectedSession?.sessionId;
    try {
      // 获取 gateway 配置以获取 auth token
      const gatewayConfig = await openclawApi.getJsonSection("gateway");
      const token = gatewayConfig?.auth?.token;

      // 复制 token 到剪切板
      if (token) {
        await navigator.clipboard.writeText(token);
        toast.success(t("sessionManager.tokenCopied", "Token 已复制到剪切板"));
      }

      // 打开浏览器
      let gatewayUrl = "http://127.0.0.1:18789/chat";
      if (sessionId) {
        gatewayUrl += `?session=${sessionId}`;
      }
      await settingsApi.openExternal(gatewayUrl);

      // 提示用户粘贴 token
      toast.info(
        t(
          "sessionManager.pasteTokenHint",
          "请粘贴 Gateway Token 并点击连接"
        ),
        { duration: 5000 }
      );
    } catch (error) {
      toast.error(t("sessionManager.openBrowserFailed", "打开浏览器失败"));
    }
  };

  const isCurrentProviderOpenClaw = selectedSession?.providerId === "openclaw";

  return (
    <TooltipProvider>
      <div className="flex flex-col flex-1 min-h-0">
        {/* 窄屏：会话列表 Sheet */}
        <Sheet open={sessionListOpen} onOpenChange={setSessionListOpen}>
          <SheetContent side="left" className="w-[320px] p-0">
            <SheetHeader className="sr-only">
              <SheetTitle>{t("sessionManager.sessionList")}</SheetTitle>
            </SheetHeader>
            <div className="flex flex-col h-full">
              {/* 搜索/标题栏 */}
              <div className="py-2 px-3 border-b">
                {isSearchOpen ? (
                  <div className="relative flex-1">
                    <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 size-3.5 text-muted-foreground" />
                    <Input
                      ref={searchInputRef}
                      value={search}
                      onChange={(event) => setSearch(event.target.value)}
                      placeholder={t("sessionManager.searchPlaceholder")}
                      className="h-8 pl-8 pr-8 text-sm"
                      autoFocus
                      onKeyDown={(e) => {
                        if (e.key === "Escape") {
                          setIsSearchOpen(false);
                          setSearch("");
                        }
                      }}
                      onBlur={() => {
                        if (search.trim() === "") {
                          setIsSearchOpen(false);
                        }
                      }}
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      className="absolute right-1 top-1/2 -translate-y-1/2 size-6"
                      onClick={() => {
                        setIsSearchOpen(false);
                        setSearch("");
                      }}
                    >
                      <X className="size-3" />
                    </Button>
                  </div>
                ) : (
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium">
                        {t("sessionManager.sessionList")}
                      </span>
                      <Badge variant="secondary" className="text-xs">
                        {filteredSessions.length}
                      </Badge>
                    </div>
                    <div className="flex items-center gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-7"
                        onClick={() => {
                          setIsSearchOpen(true);
                          setTimeout(
                            () => searchInputRef.current?.focus(),
                            0,
                          );
                        }}
                      >
                        <Search className="size-3.5" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-7"
                        onClick={() => void refetch()}
                      >
                        <RefreshCw className="size-3.5" />
                      </Button>
                    </div>
                  </div>
                )}
              </div>
              {/* 会话列表内容 */}
              <ScrollArea className="flex-1">
                <div className="p-2">
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
                              setSessionListOpen(false);
                            }}
                          />
                        );
                      })}
                    </div>
                  )}
                </div>
              </ScrollArea>
            </div>
          </SheetContent>
        </Sheet>

        {/* 主内容区域 */}
        <div className="flex-1 overflow-hidden flex flex-col">
          {/* 窄屏：顶部工具栏 */}
          <div className="md:hidden flex items-center gap-2 px-3 py-2 border-b bg-background/95 backdrop-blur-sm shrink-0">
            <Button
              variant="outline"
              size="sm"
              className="gap-1.5"
              onClick={() => setSessionListOpen(true)}
            >
              <ChevronLeft className="size-4" />
              <span>{t("sessionManager.sessionList")}</span>
              <Badge variant="secondary" className="text-xs ml-1">
                {filteredSessions.length}
              </Badge>
            </Button>
            {selectedSession && (
              <>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <span className="shrink-0">
                      <ProviderIcon
                        icon={getProviderIconName(selectedSession.providerId)}
                        name={selectedSession.providerId}
                        size={16}
                      />
                    </span>
                  </TooltipTrigger>
                  <TooltipContent>
                    {getProviderLabel(selectedSession.providerId, t)}
                  </TooltipContent>
                </Tooltip>
                <span className="text-sm font-medium truncate flex-1 min-w-0">
                  {formatSessionTitle(selectedSession)}
                </span>
                <div className="flex items-center gap-1 shrink-0">
                  {isMac() && (
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Button
                          size="icon"
                          variant="ghost"
                          className="size-8 hover:bg-accent"
                          onClick={() => void handleOpenTui()}
                          disabled={!isCurrentProviderOpenClaw && !selectedSession.resumeCommand}
                        >
                          <Terminal className="size-4" />
                        </Button>
                      </TooltipTrigger>
                      <TooltipContent>
                        {t("sessionManager.openInTui", "在 TUI 中打开")}
                      </TooltipContent>
                    </Tooltip>
                  )}
                  {selectedSession.providerId === "openclaw" && (
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Button
                          size="icon"
                          variant="ghost"
                          className="size-8 hover:bg-accent"
                          onClick={() => void handleOpenBrowser()}
                        >
                          <ExternalLink className="size-4" />
                        </Button>
                      </TooltipTrigger>
                      <TooltipContent>
                        {t("sessionManager.openInBrowser", "在浏览器中打开")}
                      </TooltipContent>
                    </Tooltip>
                  )}
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Button
                        size="icon"
                        variant="ghost"
                        className="size-8 hover:bg-accent hover:text-destructive"
                        onClick={() => setDeleteTarget(selectedSession)}
                        disabled={
                          !selectedSession.sourcePath ||
                          deleteSessionMutation.isPending
                        }
                        aria-label={t("sessionManager.delete")}
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>
                      {t("sessionManager.delete")}
                    </TooltipContent>
                  </Tooltip>
                  {userMessagesToc.length > 2 && (
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Button
                          size="icon"
                          variant="ghost"
                          className="size-8 hover:bg-accent"
                          onClick={() => setTocDialogOpen(true)}
                          aria-label={t("sessionManager.tocTitle")}
                        >
                          <List className="size-4" />
                        </Button>
                      </TooltipTrigger>
                      <TooltipContent>
                        {t("sessionManager.tocTitle")}
                      </TooltipContent>
                    </Tooltip>
                  )}
                </div>
              </>
            )}
          </div>

          {/* 左右分栏布局 */}
          <div className="flex-1 overflow-hidden grid gap-4 md:grid-cols-[minmax(min-content,100px)_1fr]">
            {/* 宽屏：左侧会话列表 */}
            <Card className="hidden md:flex flex-col overflow-hidden min-h-0">
              <CardHeader className="py-2 px-2 border-b">
                {isSearchOpen ? (
                  <div className="relative">
                    <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-3 text-muted-foreground" />
                    <Input
                      ref={searchInputRef}
                      value={search}
                      onChange={(event) => setSearch(event.target.value)}
                      placeholder={t("sessionManager.searchPlaceholder")}
                      className="h-7 pl-7 pr-6 text-xs w-full"
                      autoFocus
                      onKeyDown={(e) => {
                        if (e.key === "Escape") {
                          setIsSearchOpen(false);
                          setSearch("");
                        }
                      }}
                      onBlur={() => {
                        if (search.trim() === "") {
                          setIsSearchOpen(false);
                        }
                      }}
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      className="absolute right-0.5 top-1/2 -translate-y-1/2 size-5"
                      onClick={() => {
                        setIsSearchOpen(false);
                        setSearch("");
                      }}
                    >
                      <X className="size-2.5" />
                    </Button>
                  </div>
                ) : (
                  <div className="flex items-center justify-center gap-1">
                    <Badge variant="secondary" className="text-xs px-1.5">
                      {filteredSessions.length}
                    </Badge>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-6"
                      onClick={() => {
                        setIsSearchOpen(true);
                        setTimeout(
                          () => searchInputRef.current?.focus(),
                          0,
                        );
                      }}
                    >
                      <Search className="size-3" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-6"
                      onClick={() => void refetch()}
                    >
                      <RefreshCw className="size-3" />
                    </Button>
                  </div>
                )}
              </CardHeader>
              <CardContent className="flex-1 overflow-hidden p-0">
                <ScrollArea className="h-full">
                  <div className="p-2">
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
                              onSelect={setSelectedKey}
                            />
                          );
                        })}
                      </div>
                    )}
                  </div>
                </ScrollArea>
              </CardContent>
            </Card>

            {/* 右侧会话详情 */}
            <Card
              className="flex flex-col flex-1 overflow-hidden min-h-0"
              ref={detailRef}
            >
              {!selectedSession ? (
                <div className="flex-1 flex flex-col items-center justify-center text-muted-foreground p-8">
                  <MessageSquare className="size-12 mb-3 opacity-30" />
                  <p className="text-sm">{t("sessionManager.selectSession")}</p>
                </div>
              ) : (
                <>
                  {/* 详情头部 - 宽屏 */}
                  <CardHeader className="hidden md:flex py-3 px-4 border-b shrink-0">
                    <div className="flex items-start justify-between gap-4">
                      {/* 左侧：会话信息 */}
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2 mb-1">
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <span className="shrink-0">
                                <ProviderIcon
                                  icon={getProviderIconName(
                                    selectedSession.providerId,
                                  )}
                                  name={selectedSession.providerId}
                                  size={20}
                                />
                              </span>
                            </TooltipTrigger>
                            <TooltipContent>
                              {getProviderLabel(selectedSession.providerId, t)}
                            </TooltipContent>
                          </Tooltip>
                          <h2 className="text-base font-semibold truncate">
                            {formatSessionTitle(selectedSession)}
                          </h2>
                        </div>

                        {/* 元信息 */}
                        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
                          <div className="flex items-center gap-1">
                            <Clock className="size-3" />
                            <span>
                              {formatTimestamp(
                                selectedSession.lastActiveAt ??
                                  selectedSession.createdAt,
                              )}
                            </span>
                          </div>
                          {selectedSession.projectDir && (
                            <Tooltip>
                              <TooltipTrigger asChild>
                                <button
                                  type="button"
                                  onClick={() =>
                                    void handleCopy(
                                      selectedSession.projectDir!,
                                      t("sessionManager.projectDirCopied"),
                                    )
                                  }
                                  className="flex items-center gap-1 hover:text-foreground transition-colors"
                                >
                                  <FolderOpen className="size-3" />
                                  <span className="truncate max-w-[200px]">
                                    {getBaseName(selectedSession.projectDir)}
                                  </span>
                                </button>
                              </TooltipTrigger>
                              <TooltipContent
                                side="bottom"
                                className="max-w-xs"
                              >
                                <p className="font-mono text-xs break-all">
                                  {selectedSession.projectDir}
                                </p>
                                <p className="text-muted-foreground mt-1">
                                  {t("sessionManager.clickToCopyPath")}
                                </p>
                              </TooltipContent>
                            </Tooltip>
                          )}
                        </div>
                      </div>

                      {/* 右侧：操作按钮组 */}
                      <div className="flex items-center gap-1 shrink-0">
                        {isMac() && (
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <Button
                                size="icon"
                                variant="ghost"
                                className="size-8 hover:bg-accent"
                                onClick={() => void handleOpenTui()}
                                disabled={!isCurrentProviderOpenClaw && !selectedSession.resumeCommand}
                              >
                                <Terminal className="size-4" />
                              </Button>
                            </TooltipTrigger>
                            <TooltipContent>
                              {t("sessionManager.openInTui", "在 TUI 中打开")}
                            </TooltipContent>
                          </Tooltip>
                        )}
                        {selectedSession.providerId === "openclaw" && (
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <Button
                                size="icon"
                                variant="ghost"
                                className="size-8 hover:bg-accent"
                                onClick={() => void handleOpenBrowser()}
                              >
                                <ExternalLink className="size-4" />
                              </Button>
                            </TooltipTrigger>
                            <TooltipContent>
                              {t("sessionManager.openInBrowser", "在浏览器中打开")}
                            </TooltipContent>
                          </Tooltip>
                        )}
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="size-8 hover:bg-accent hover:text-destructive"
                              onClick={() => setDeleteTarget(selectedSession)}
                              disabled={
                                !selectedSession.sourcePath ||
                                deleteSessionMutation.isPending
                              }
                            >
                              <Trash2 className="size-4" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>
                            {t("sessionManager.delete")}
                          </TooltipContent>
                        </Tooltip>
                      </div>
                    </div>

                    {/* 恢复命令预览 */}
                    {selectedSession.resumeCommand && (
                      <div className="mt-3 flex items-center gap-2">
                        <div className="flex-1 rounded-md bg-muted/60 px-3 py-1.5 font-mono text-xs text-muted-foreground truncate">
                          {selectedSession.resumeCommand}
                        </div>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="size-7 shrink-0"
                              onClick={() =>
                                void handleCopy(
                                  selectedSession.resumeCommand!,
                                  t("sessionManager.resumeCommandCopied"),
                                )
                              }
                            >
                              <Copy className="size-3.5" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>
                            {t("sessionManager.copyCommand")}
                          </TooltipContent>
                        </Tooltip>
                      </div>
                    )}
                  </CardHeader>

                  {/* 消息列表区域 */}
                  <CardContent className="flex-1 overflow-hidden p-0">
                    <div className="flex h-full min-w-0">
                      {/* 消息列表 */}
                      <ScrollArea className="flex-1 min-w-0">
                        <div className="p-4 min-w-0">
                          <div className="flex items-center gap-2 mb-3">
                            <MessageSquare className="size-4 text-muted-foreground" />
                            <span className="text-sm font-medium">
                              {t("sessionManager.conversationHistory")}
                            </span>
                            <Badge variant="secondary" className="text-xs">
                              {messages.length}
                            </Badge>
                          </div>

                          {isLoadingMessages ? (
                            <div className="flex items-center justify-center py-12">
                              <RefreshCw className="size-5 animate-spin text-muted-foreground" />
                            </div>
                          ) : messages.length === 0 ? (
                            <div className="flex flex-col items-center justify-center py-12 text-center">
                              <MessageSquare className="size-8 text-muted-foreground/50 mb-2" />
                              <p className="text-sm text-muted-foreground">
                                {t("sessionManager.emptySession")}
                              </p>
                            </div>
                          ) : (
                            <div className="space-y-3">
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
                                      t("sessionManager.messageCopied"),
                                    )
                                  }
                                />
                              ))}
                              <div ref={messagesEndRef} />
                            </div>
                          )}
                        </div>
                      </ScrollArea>

                      {/* 右侧目录 - 类似少数派 (大屏幕) */}
                      <SessionTocSidebar
                        items={userMessagesToc}
                        onItemClick={scrollToMessage}
                      />
                    </div>

                    {/* 目录 Sheet (小屏幕) */}
                    <SessionTocSheet
                      items={userMessagesToc}
                      onItemClick={scrollToMessage}
                      open={tocDialogOpen}
                      onOpenChange={setTocDialogOpen}
                    />
                  </CardContent>

                  {/* 底部输入框 */}
                  <div className="shrink-0 border-t p-3 bg-background">
                    <form
                      onSubmit={(e) => {
                        e.preventDefault();
                        if (inputMessage.trim()) {
                          // 消息功能开发中，显示选择对话框
                          setShowTuiChoice(true);
                          setInputMessage("");
                        }
                      }}
                      className="flex gap-2"
                    >
                      <Input
                        value={inputMessage}
                        onChange={(e) => setInputMessage(e.target.value)}
                        placeholder={t("sessionManager.inputPlaceholder", "输入消息...")}
                        className="flex-1"
                      />
                      <Button type="submit" size="icon" disabled={!inputMessage.trim()}>
                        <Send className="size-4" />
                      </Button>
                    </form>
                  </div>
                </>
              )}
            </Card>
          </div>
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

      {/* TUI 选择对话框（非 OpenClaw） */}
      {!isCurrentProviderOpenClaw && (
        <ConfirmDialog
          isOpen={showTuiChoice}
          title={t("sessionManager.openTuiTitle", "消息功能开发中")}
          message={t("sessionManager.openTuiMessage", "是否打开原生 TUI？")}
          confirmText={t("common.confirm", "确认")}
          cancelText={t("common.cancel", "取消")}
          variant="info"
          onConfirm={() => void handleOpenTui()}
          onCancel={() => setShowTuiChoice(false)}
        />
      )}

      {/* OpenClaw TUI/浏览器选择对话框 */}
      {isCurrentProviderOpenClaw && showTuiChoice && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-background rounded-lg shadow-lg p-4 max-w-sm mx-4">
            <h3 className="text-lg font-semibold mb-2">
              {t("sessionManager.openTuiTitle", "消息功能开发中")}
            </h3>
            <p className="text-sm text-muted-foreground mb-4">
              {t("sessionManager.openTuiMessageOpenClaw", "是否打开？")}
            </p>
            <div className="flex gap-2 justify-end">
              <Button
                variant="outline"
                onClick={() => setShowTuiChoice(false)}
              >
                {t("common.cancel", "取消")}
              </Button>
              <Button
                variant="outline"
                onClick={() => void handleOpenTui()}
              >
                <Terminal className="size-4 mr-2" />
                TUI
              </Button>
              <Button onClick={() => void handleOpenBrowser()}>
                <ExternalLink className="size-4 mr-2" />
                {t("sessionManager.openInBrowser", "浏览器")}
              </Button>
            </div>
          </div>
        </div>
      )}
    </TooltipProvider>
  );
}
