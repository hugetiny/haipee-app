import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { formatDistanceToNow } from '@/utils/dateUtils';
import type { ChatMessage as ChatMessageType } from './types';
import { Loader2, AlertCircle, FileText, Bot, User } from 'lucide-react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';

interface ChatMessageProps {
  message: ChatMessageType;
  className?: string;
}

export function ChatMessage({ message, className }: ChatMessageProps) {
  const { t } = useTranslation();
  const isUser = message.role === 'user';

  const formattedTime = useMemo(() => {
    return formatDistanceToNow(message.timestamp);
  }, [message.timestamp]);

  const renderContent = (content: string) => {
    const codeBlockRegex = /```(\w+)?\n([\s\S]*?)```/g;
    const parts: React.ReactNode[] = [];
    let lastIndex = 0;
    let match;

    while ((match = codeBlockRegex.exec(content)) !== null) {
      if (match.index > lastIndex) {
        parts.push(
          <span key={`text-${lastIndex}`} className="whitespace-pre-wrap">
            {content.slice(lastIndex, match.index)}
          </span>
        );
      }

      const language = match[1] || 'text';
      const code = match[2];

      parts.push(
        <div key={`code-${match.index}`} className="my-3 rounded-lg overflow-hidden border border-green-500/20">
          <div className="flex items-center justify-between px-3 py-1.5 bg-green-500/10 border-b border-green-500/20">
            <span className="text-xs text-green-400 font-mono">{language}</span>
            <button
              onClick={() => navigator.clipboard.writeText(code)}
              className="text-xs text-green-400 hover:text-green-300 transition-colors"
            >
              {t('common.copy', { defaultValue: '复制' })}
            </button>
          </div>
          <SyntaxHighlighter
            language={language}
            style={vscDarkPlus}
            customStyle={{
              margin: 0,
              padding: '1rem',
              background: '#0a0a0a',
              fontSize: '0.875rem',
            }}
          >
            {code}
          </SyntaxHighlighter>
        </div>
      );

      lastIndex = match.index + match[0].length;
    }

    if (lastIndex < content.length) {
      parts.push(
        <span key={`text-${lastIndex}`} className="whitespace-pre-wrap">
          {content.slice(lastIndex)}
        </span>
      );
    }

    return parts.length > 0 ? parts : content;
  };

  return (
    <div
      className={cn(
        'flex gap-3 p-4',
        isUser ? 'flex-row-reverse' : 'flex-row',
        className
      )}
    >
      {/* Avatar */}
      <div
        className={cn(
          'flex-shrink-0 w-8 h-8 rounded-lg flex items-center justify-center',
          isUser
            ? 'bg-green-500/20 text-green-400'
            : 'bg-green-500/10 text-green-500'
        )}
      >
        {isUser ? (
          <User className="w-4 h-4" />
        ) : (
          <Bot className="w-4 h-4" />
        )}
      </div>

      {/* Message Content */}
      <div
        className={cn(
          'flex-1 max-w-[85%]',
          isUser ? 'text-right' : 'text-left'
        )}
      >
        {/* Header */}
        <div
          className={cn(
            'flex items-center gap-2 mb-1',
            isUser ? 'justify-end' : 'justify-start'
          )}
        >
          <span className="text-xs text-muted-foreground">
            {isUser ? t('chat.you', { defaultValue: '你' }) : 'AI'}
          </span>
          <span className="text-xs text-muted-foreground/60">
            {formattedTime}
          </span>
          {message.isStreaming && (
            <Loader2 className="w-3 h-3 animate-spin text-green-500" />
          )}
        </div>

        {/* Content */}
        <div
          className={cn(
            'inline-block rounded-2xl px-4 py-2.5 text-sm leading-relaxed',
            isUser
              ? 'bg-green-500/20 text-green-50 border border-green-500/30'
              : 'bg-card text-foreground border border-border'
          )}
        >
          {renderContent(message.content)}
        </div>

        {/* Error */}
        {message.error && (
          <div className="flex items-center gap-1.5 mt-2 text-red-400 text-xs">
            <AlertCircle className="w-3.5 h-3.5" />
            <span>{message.error}</span>
          </div>
        )}

        {/* Attachments */}
        {message.attachments && message.attachments.length > 0 && (
          <div className={cn('flex gap-2 mt-2', isUser ? 'justify-end' : 'justify-start')}>
            {message.attachments.map((attachment) => (
              <div
                key={attachment.id}
                className="flex items-center gap-1.5 px-2 py-1 rounded bg-green-500/10 border border-green-500/20 text-xs"
              >
                <FileText className="w-3 h-3 text-green-400" />
                <span className="text-green-300 truncate max-w-[150px]">
                  {attachment.name}
                </span>
              </div>
            ))}
          </div>
        )}

        {/* Thinking */}
        {message.thinking && (
          <div className="mt-2 p-2 rounded bg-green-500/5 border border-green-500/10 text-xs text-green-400/80">
            <span className="font-medium">{t('chat.thinking', { defaultValue: '思考中' })}:</span>
            <span className="ml-1 italic">{message.thinking}</span>
          </div>
        )}
      </div>
    </div>
  );
}
