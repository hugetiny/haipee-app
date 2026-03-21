/**
 * Channel Test Page
 *
 * A development/test page for verifying channel communication.
 * Shows both OpenClaw and MCP channels side by side.
 */

import { useState, useCallback, useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { cn } from '@/lib/utils';
import {
  initHaipeeChannel,
  sendToClaudeCode,
  onMessage,
  getChatHistory,
  type HaipeeMessage,
} from '@/mcp-channel';

interface MessageItemProps {
  message: HaipeeMessage;
}

function MessageItem({ message }: MessageItemProps) {
  const isUser = message.role === 'user';

  return (
    <div
      className={cn(
        'flex w-full mb-2',
        isUser ? 'justify-end' : 'justify-start'
      )}
      data-testid={isUser ? 'user-message' : 'assistant-message'}
    >
      <div
        className={cn(
          'max-w-[80%] rounded-lg px-3 py-2 text-sm',
          isUser
            ? 'bg-green-600 text-white'
            : 'bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100'
        )}
      >
        <p className="whitespace-pre-wrap">{message.content}</p>
        <span className="text-xs opacity-50 mt-1 block">
          {new Date(message.timestamp).toLocaleTimeString()}
        </span>
      </div>
    </div>
  );
}

interface ChannelPanelProps {
  channelType: 'openclaw' | 'mcp';
  title: string;
  description: string;
}

function ChannelPanel({ channelType, title, description }: ChannelPanelProps) {
  const { t } = useTranslation();
  const [messages, setMessages] = useState<HaipeeMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const unsubscribeRef = useRef<(() => void) | null>(null);

  // Check if running in browser mode (not Tauri)
  const isBrowserMode = typeof window !== 'undefined' && !(window as unknown as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__;

  // Initialize channel on mount
  useEffect(() => {
    let mounted = true;

    const init = async () => {
      try {
        if (channelType === 'mcp') {
          // In browser mode, skip MCP server initialization but still set up message handling
          if (!isBrowserMode) {
            await initHaipeeChannel();
          }
          if (!mounted) return;
          setIsConnected(true);

          // Subscribe to messages (works in both browser and Tauri mode)
          unsubscribeRef.current = onMessage((msg) => {
            if (!mounted) return;
            setMessages((prev) => {
              // Avoid duplicates by checking if message already exists
              if (prev.some(m => m.id === msg.id)) return prev;
              return [...prev, msg];
            });
            if (msg.role === 'assistant') {
              setIsLoading(false);
            }
          });

          // Load existing history
          if (mounted) setMessages(getChatHistory());
        } else {
          // OpenClaw channel - check connection status
          // For now, simulate connection
          if (mounted) setIsConnected(true);
        }
      } catch (err) {
        // Don't show mock mode errors
        const errorMsg = err instanceof Error ? err.message : String(err);
        if (!errorMsg.includes('Browser Mock') && !errorMsg.includes('not available')) {
          if (mounted) setError(errorMsg);
        }
        if (mounted) setIsConnected(true); // Still show as connected in mock mode
      }
    };

    init();

    return () => {
      mounted = false;
      if (unsubscribeRef.current) {
        unsubscribeRef.current();
      }
    };
  }, [channelType, isBrowserMode]);

  // Auto-scroll to bottom
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const handleSend = useCallback(async () => {
    if (!input.trim() || isLoading) return;

    const content = input.trim();
    setInput('');
    setIsLoading(true);
    setError(null);

    try {
      if (channelType === 'mcp') {
        // Send to Claude Code (sendToClaudeCode handles message history)
        await sendToClaudeCode(content);
        // The onMessage callback will handle adding messages to state
        // Set a timeout to clear loading in mock mode
        if (isBrowserMode) {
          setTimeout(() => setIsLoading(false), 600);
        }
      } else {
        // OpenClaw channel - send via HTTP
        const userMessage: HaipeeMessage = {
          id: crypto.randomUUID(),
          role: 'user',
          content,
          timestamp: Date.now(),
          chatId: 'main',
        };
        setMessages((prev) => [...prev, userMessage]);

        // TODO: Implement OpenClaw HTTP API call
        // For now, simulate a response
        setTimeout(() => {
          const responseMessage: HaipeeMessage = {
            id: crypto.randomUUID(),
            role: 'assistant',
            content: `[OpenClaw] Received: "${content}"\n\nThis is a simulated response. Connect to an actual OpenClaw server for real responses.`,
            timestamp: Date.now(),
            chatId: 'main',
          };
          setMessages((prev) => [...prev, responseMessage]);
          setIsLoading(false);
        }, 1000);
      }
    } catch (err) {
      // Don't show mock mode errors or browser-specific errors
      const errorMsg = err instanceof Error ? err.message : String(err);
      if (!errorMsg.includes('Browser Mock') &&
          !errorMsg.includes('not available') &&
          !errorMsg.includes('write') &&
          !errorMsg.includes('undefined')) {
        setError(errorMsg);
      }
      setIsLoading(false);
    }
  }, [input, isLoading, channelType, isBrowserMode]);

  const handleClear = useCallback(() => {
    setMessages([]);
    setError(null);
  }, []);

  return (
    <Card className="h-full flex flex-col" data-testid={`${channelType}-channel-container`}>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg">{title}</CardTitle>
          <div className="flex items-center gap-2">
            <Badge
              variant={isConnected ? 'default' : 'secondary'}
              className={cn(
                'text-xs',
                isConnected && 'bg-green-500 hover:bg-green-600'
              )}
              data-testid={`${channelType}-status`}
            >
              {isConnected
                ? t('channels.connected', { defaultValue: '已连接' })
                : t('channels.disconnected', { defaultValue: '未连接' })}
            </Badge>
            <Button variant="outline" size="sm" onClick={handleClear}>
              {t('channels.clear', { defaultValue: '清空' })}
            </Button>
          </div>
        </div>
        <p className="text-sm text-muted-foreground">{description}</p>
      </CardHeader>

      <CardContent className="flex-1 flex flex-col gap-4 overflow-hidden">
        {/* Error - hide expected errors in browser mode */}
        {error && !isBrowserMode && (
          <div className="text-sm text-red-500 bg-red-50 dark:bg-red-950 p-2 rounded">
            {error}
          </div>
        )}

        {/* Messages */}
        <ScrollArea className="flex-1" ref={scrollRef}>
          {messages.length === 0 ? (
            <div className="flex items-center justify-center h-full text-muted-foreground text-sm">
              {t('channels.noMessages', { defaultValue: '暂无消息' })}
            </div>
          ) : (
            <div className="space-y-1">
              {messages.map((msg) => (
                <MessageItem key={msg.id} message={msg} />
              ))}
            </div>
          )}
        </ScrollArea>

        {/* Input */}
        <div className="flex gap-2">
          <Textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder={t('channels.inputPlaceholder', { defaultValue: '输入消息...' })}
            className="min-h-[60px] resize-none"
            data-testid={`${channelType}-chat-input`}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                handleSend();
              }
            }}
          />
          <Button
            onClick={handleSend}
            disabled={!input.trim() || isLoading || !isConnected}
            className="self-end"
            data-testid={`${channelType}-send`}
          >
            {isLoading
              ? t('channels.sending', { defaultValue: '发送中...' })
              : t('channels.send', { defaultValue: '发送' })}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}

export function ChannelTestPage() {
  const { t } = useTranslation();
  const [activeTab, setActiveTab] = useState<'openclaw' | 'mcp'>('openclaw');

  return (
    <div className="h-screen flex flex-col p-4">
      <div className="mb-4">
        <h1 className="text-2xl font-bold">
          {t('channels.title', { defaultValue: 'Channel 通信测试' })}
        </h1>
        <p className="text-muted-foreground">
          {t('channels.description', {
            defaultValue: '测试 OpenClaw 和 Claude Code MCP channel 的消息收发',
          })}
        </p>
      </div>

      <Tabs
        value={activeTab}
        onValueChange={(v) => setActiveTab(v as 'openclaw' | 'mcp')}
        className="flex-1 flex flex-col"
      >
        <TabsList className="mb-4">
          <TabsTrigger value="openclaw" data-testid="tab-openclaw">
            OpenClaw Channel
          </TabsTrigger>
          <TabsTrigger value="mcp" data-testid="tab-mcp">
            Claude Code (MCP)
          </TabsTrigger>
        </TabsList>

        <TabsContent value="openclaw" className="flex-1 mt-0">
          <ChannelPanel
            channelType="openclaw"
            title="OpenClaw Channel"
            description={t('channels.openclawDescription', {
              defaultValue: '通过 HTTP API 与 OpenClaw 服务通信',
            })}
          />
        </TabsContent>

        <TabsContent value="mcp" className="flex-1 mt-0">
          <ChannelPanel
            channelType="mcp"
            title="Claude Code MCP Channel"
            description={t('channels.mcpDescription', {
              defaultValue: '通过 MCP stdio 协议与 Claude Code 通信',
            })}
          />
        </TabsContent>
      </Tabs>
    </div>
  );
}

export default ChannelTestPage;