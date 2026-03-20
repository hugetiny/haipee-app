import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { formatDistanceToNow } from '@/utils/dateUtils';
import type { ChatSession } from './types';
import { Plus, MessageSquare, Trash2, MoreVertical } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ScrollArea } from '@/components/ui/scroll-area';

interface ChatSessionListProps {
  sessions: ChatSession[];
  currentSessionId: string | null;
  onSelectSession: (sessionId: string) => void;
  onCreateSession: () => void;
  onDeleteSession: (sessionId: string) => void;
  className?: string;
}

export function ChatSessionList({
  sessions,
  currentSessionId,
  onSelectSession,
  onCreateSession,
  onDeleteSession,
  className,
}: ChatSessionListProps) {
  const { t } = useTranslation();

  const sortedSessions = useMemo(() => {
    return [...sessions].sort((a, b) => b.updatedAt - a.updatedAt);
  }, [sessions]);

  const getSessionPreview = (session: ChatSession) => {
    const lastMessage = session.messages[session.messages.length - 1];
    if (!lastMessage) return t('chat.noMessages', { defaultValue: '暂无消息' });
    return lastMessage.content.slice(0, 50) + (lastMessage.content.length > 50 ? '...' : '');
  };

  return (
    <div className={cn('flex flex-col h-full border-r border-green-500/20 bg-card/50', className)}>
      {/* Header */}
      <div className="flex items-center justify-between p-3 border-b border-green-500/20">
        <h3 className="font-semibold text-sm text-foreground">
          {t('chat.sessions', { defaultValue: '会话' })}
        </h3>
        <Button
          variant="ghost"
          size="sm"
          className="h-8 gap-1 text-green-400 hover:text-green-300 hover:bg-green-500/10"
          onClick={onCreateSession}
        >
          <Plus className="h-4 w-4" />
          <span className="text-xs">{t('chat.newSession', { defaultValue: '新建' })}</span>
        </Button>
      </div>

      {/* Session List */}
      <ScrollArea className="flex-1">
        <div className="p-2 space-y-1">
          {sortedSessions.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground text-sm">
              {t('chat.noSessions', { defaultValue: '没有会话' })}
            </div>
          ) : (
            sortedSessions.map((session) => (
              <div
                key={session.id}
                className={cn(
                  'group relative flex items-start gap-2 p-2.5 rounded-lg cursor-pointer transition-colors',
                  currentSessionId === session.id
                    ? 'bg-green-500/20 border border-green-500/30'
                    : 'hover:bg-green-500/5 border border-transparent'
                )}
                onClick={() => onSelectSession(session.id)}
              >
                <MessageSquare
                  className={cn(
                    'h-4 w-4 mt-0.5 flex-shrink-0',
                    currentSessionId === session.id ? 'text-green-400' : 'text-muted-foreground'
                  )}
                />

                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2">
                    <span
                      className={cn(
                        'font-medium text-sm truncate',
                        currentSessionId === session.id ? 'text-green-300' : 'text-foreground'
                      )}
                    >
                      {session.title}
                    </span>
                  </div>

                  <p className="text-xs text-muted-foreground truncate mt-0.5">
                    {getSessionPreview(session)}
                  </p>

                  <span className="text-xs text-muted-foreground/60 mt-1">
                    {formatDistanceToNow(session.updatedAt)}
                  </span>
                </div>

                {/* Actions */}
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7 opacity-0 group-hover:opacity-100 transition-opacity"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <MoreVertical className="h-3.5 w-3.5" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem
                      className="text-red-400 focus:text-red-400"
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeleteSession(session.id);
                      }}
                    >
                      <Trash2 className="h-4 w-4 mr-2" />
                      {t('common.delete', { defaultValue: '删除' })}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            ))
          )}
        </div>
      </ScrollArea>
    </div>
  );
}
