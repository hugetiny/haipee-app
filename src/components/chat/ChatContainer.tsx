import { useEffect, useRef, useCallback, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { ScrollArea } from '@/components/ui/scroll-area';
import { useChat } from './useChat';
import { ChatMessage } from './ChatMessage';
import { ChatInput } from './ChatInput';
import { ChatSessionList } from './ChatSessionList';
import type { ChatAttachment } from './types';
import { AlertCircle, Wifi, WifiOff } from 'lucide-react';
import { getChatProviderInfo, sendChatMessage, type ChatProviderInfo } from '@/lib/api/chat';

interface ChatContainerProps {
  providerId: string;
  appId: string;
  className?: string;
}

export function ChatContainer({ providerId, appId, className }: ChatContainerProps) {
  const { t } = useTranslation();
  const scrollRef = useRef<HTMLDivElement>(null);
  const cleanupRef = useRef<(() => void) | null>(null);
  // Tracks accumulated streamed content for the current message
  const streamContentRef = useRef<string>('');
  const [providerInfo, setProviderInfo] = useState<ChatProviderInfo | null>(null);

  const {
    sessions,
    currentSessionId,
    currentSession,
    isLoading,
    error,
    createSession,
    deleteSession,
    setCurrentSession,
    addMessage,
    updateMessage,
    setStreaming,
    setLoading,
    setError,
  } = useChat();

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [currentSession?.messages]);

  // Create initial session if none exists
  useEffect(() => {
    if (sessions.length === 0) {
      createSession(providerId, appId);
    }
  }, [sessions.length, createSession, providerId, appId]);

  // Fetch provider info on mount and when appId changes
  useEffect(() => {
    let active = true;
    getChatProviderInfo(appId)
      .then((info) => {
        if (active) setProviderInfo(info);
      })
      .catch(() => {
        if (active) setProviderInfo(null);
      });
    return () => {
      active = false;
    };
  }, [appId]);

  // Cleanup streaming listeners on unmount
  useEffect(() => {
    return () => {
      if (cleanupRef.current) {
        cleanupRef.current();
        cleanupRef.current = null;
      }
    };
  }, []);

  const handleSendMessage = useCallback(
    async (content: string, attachments?: ChatAttachment[]) => {
      if (!currentSession) return;

      setError(null);

      // Add user message
      const userMessage = {
        id: crypto.randomUUID(),
        role: 'user' as const,
        content,
        timestamp: Date.now(),
        attachments,
      };
      addMessage(currentSession.id, userMessage);

      // Create assistant message placeholder
      const assistantMessageId = crypto.randomUUID();
      const assistantMessage = {
        id: assistantMessageId,
        role: 'assistant' as const,
        content: '',
        timestamp: Date.now(),
        isStreaming: true,
      };
      addMessage(currentSession.id, assistantMessage);
      setLoading(true);

      // Reset stream content tracker
      streamContentRef.current = '';

      // Capture session ID for closure (currentSession may change)
      const sessionId = currentSession.id;

      // Build message history for context
      const history = [
        ...currentSession.messages.map((m) => ({ role: m.role, content: m.content })),
        { role: 'user', content },
      ];

      try {
        // Cancel any existing streaming
        if (cleanupRef.current) {
          cleanupRef.current();
          cleanupRef.current = null;
        }

        const cleanup = await sendChatMessage(
          appId,
          sessionId,
          assistantMessageId,
          history,
          providerInfo?.defaultModel ?? null,
          {
            onChunk: (delta) => {
              streamContentRef.current += delta;
              updateMessage(sessionId, assistantMessageId, {
                content: streamContentRef.current,
              });
            },
            onDone: () => {
              setStreaming(sessionId, assistantMessageId, false);
              setLoading(false);
              cleanupRef.current = null;
            },
            onError: (err) => {
              setError(err);
              updateMessage(sessionId, assistantMessageId, {
                error: t('chat.sendError', { defaultValue: '发送消息失败' }),
                isStreaming: false,
              });
              setLoading(false);
              cleanupRef.current = null;
            },
          }
        );
        cleanupRef.current = cleanup;
      } catch (err) {
        const msg = err instanceof Error ? err.message : 'Unknown error';
        setError(msg);
        updateMessage(sessionId, assistantMessageId, {
          error: t('chat.sendError', { defaultValue: '发送消息失败' }),
          isStreaming: false,
        });
        setLoading(false);
      }
    },
    [currentSession, addMessage, updateMessage, setStreaming, setLoading, setError, t, appId, providerInfo]
  );

  const handleStopStreaming = useCallback(() => {
    if (!currentSession) return;

    if (cleanupRef.current) {
      cleanupRef.current();
      cleanupRef.current = null;
    }

    const streamingMessage = currentSession.messages.find((m) => m.isStreaming);
    if (streamingMessage) {
      setStreaming(currentSession.id, streamingMessage.id, false);
    }
    setLoading(false);
  }, [currentSession, setStreaming, setLoading]);

  return (
    <div className={cn('flex h-full overflow-hidden bg-background', className)}>
      {/* Session List */}
      <ChatSessionList
        sessions={sessions}
        currentSessionId={currentSessionId}
        onSelectSession={setCurrentSession}
        onCreateSession={() => createSession(providerId, appId)}
        onDeleteSession={deleteSession}
        className="w-64 flex-shrink-0"
      />

      {/* Chat Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Provider Status Bar */}
        <div className="px-4 py-2 border-b border-green-500/20 flex items-center gap-2 bg-background/80">
          {providerInfo ? (
            <>
              <Wifi className="h-3.5 w-3.5 text-green-500" />
              <span className="text-xs text-green-400 font-mono">
                {providerInfo.providerName}
              </span>
              <span className="text-xs text-muted-foreground/50">·</span>
              <span className="text-xs text-muted-foreground/70 font-mono truncate max-w-[200px]">
                {providerInfo.defaultModel}
              </span>
            </>
          ) : (
            <>
              <WifiOff className="h-3.5 w-3.5 text-muted-foreground" />
              <span className="text-xs text-muted-foreground">
                {t('chat.noProvider', { defaultValue: '未配置供应商' })}
              </span>
            </>
          )}
        </div>

        {/* Messages */}
        <ScrollArea ref={scrollRef} className="flex-1 p-4">
          {currentSession?.messages.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-center p-8">
              <div className="w-16 h-16 rounded-full bg-green-500/10 flex items-center justify-center mb-4">
                <span className="text-2xl">💬</span>
              </div>
              <h3 className="text-lg font-medium text-foreground mb-2">
                {t('chat.welcome', { defaultValue: '开始新的对话' })}
              </h3>
              <p className="text-sm text-muted-foreground max-w-sm">
                {t('chat.welcomeDescription', {
                  defaultValue: '发送消息开始与AI助手对话。您可以询问问题、请求代码帮助或进行创意协作。',
                })}
              </p>
              {!providerInfo && (
                <p className="text-xs text-amber-400/80 mt-4 max-w-sm">
                  {t('chat.providerRequired', {
                    defaultValue: '请先在供应商页面配置并激活一个供应商。',
                  })}
                </p>
              )}
            </div>
          ) : (
            <div className="space-y-2">
              {currentSession?.messages.map((message) => (
                <ChatMessage key={message.id} message={message} />
              ))}
            </div>
          )}
        </ScrollArea>

        {/* Error */}
        {error && (
          <div className="px-4 py-2 bg-red-500/10 border-t border-red-500/20 flex items-center gap-2 text-red-400 text-sm">
            <AlertCircle className="h-4 w-4 flex-shrink-0" />
            <span className="truncate">{error}</span>
          </div>
        )}

        {/* Input */}
        <ChatInput
          onSend={handleSendMessage}
          onStop={handleStopStreaming}
          isLoading={isLoading}
          disabled={!currentSession || !providerInfo}
        />
      </div>
    </div>
  );
}
