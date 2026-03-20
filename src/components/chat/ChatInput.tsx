import { useState, useRef, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { Send, Paperclip, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import type { ChatAttachment } from './types';

interface ChatInputProps {
  onSend: (message: string, attachments?: ChatAttachment[]) => void;
  onStop?: () => void;
  isLoading?: boolean;
  disabled?: boolean;
  placeholder?: string;
  className?: string;
}

export function ChatInput({
  onSend,
  onStop,
  isLoading = false,
  disabled = false,
  placeholder,
  className,
}: ChatInputProps) {
  const { t } = useTranslation();
  const [input, setInput] = useState('');
  const [attachments, setAttachments] = useState<ChatAttachment[]>([]);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSend = useCallback(() => {
    if (!input.trim() || isLoading || disabled) return;

    onSend(input.trim(), attachments.length > 0 ? attachments : undefined);
    setInput('');
    setAttachments([]);

    // Reset textarea height
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
  }, [input, attachments, isLoading, disabled, onSend]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSend();
      }
    },
    [handleSend]
  );

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLTextAreaElement>) => {
      setInput(e.target.value);

      // Auto-resize textarea
      const textarea = e.target;
      textarea.style.height = 'auto';
      textarea.style.height = `${Math.min(textarea.scrollHeight, 200)}px`;
    },
    []
  );

  const handleFileSelect = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = e.target.files;
      if (!files) return;

      const newAttachments: ChatAttachment[] = Array.from(files).map((file) => ({
        id: crypto.randomUUID(),
        name: file.name,
        type: file.type,
        size: file.size,
      }));

      setAttachments((prev) => [...prev, ...newAttachments]);

      // Clear input
      e.target.value = '';
    },
    []
  );

  const removeAttachment = useCallback((id: string) => {
    setAttachments((prev) => prev.filter((a) => a.id !== id));
  }, []);

  return (
    <div
      className={cn(
        'border-t border-green-500/20 bg-background/95 backdrop-blur-sm p-4',
        className
      )}
    >
      {/* Attachments */}
      {attachments.length > 0 && (
        <div className="flex flex-wrap gap-2 mb-3">
          {attachments.map((attachment) => (
            <div
              key={attachment.id}
              className="flex items-center gap-2 px-2 py-1 rounded-md bg-green-500/10 border border-green-500/20 text-xs"
            >
              <span className="text-green-300 truncate max-w-[150px]">
                {attachment.name}
              </span>
              <button
                onClick={() => removeAttachment(attachment.id)}
                className="text-green-400 hover:text-green-200"
              >
                ×
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Input Area */}
      <div className="flex items-end gap-2">
        {/* File Attachment */}
        <label className="flex-shrink-0">
          <input
            type="file"
            multiple
            className="hidden"
            onChange={handleFileSelect}
            disabled={isLoading || disabled}
          />
          <Button
            type="button"
            variant="ghost"
            size="icon"
            className="h-9 w-9 text-green-400 hover:text-green-300 hover:bg-green-500/10"
            disabled={isLoading || disabled}
          >
            <Paperclip className="h-4 w-4" />
          </Button>
        </label>

        {/* Text Input */}
        <Textarea
          ref={textareaRef}
          value={input}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          placeholder={
            placeholder || t('chat.inputPlaceholder', { defaultValue: '输入消息...' })
          }
          disabled={disabled}
          className={cn(
            'flex-1 min-h-[40px] max-h-[200px] resize-none',
            'bg-green-500/5 border-green-500/20 focus:border-green-500/50',
            'placeholder:text-muted-foreground/50'
          )}
          rows={1}
        />

        {/* Send/Stop Button */}
        {isLoading ? (
          <Button
            type="button"
            variant="destructive"
            size="icon"
            className="flex-shrink-0 h-9 w-9"
            onClick={onStop}
          >
            <Loader2 className="h-4 w-4 animate-spin" />
          </Button>
        ) : (
          <Button
            type="button"
            size="icon"
            className={cn(
              'flex-shrink-0 h-9 w-9',
              input.trim()
                ? 'bg-green-500 hover:bg-green-600 text-white'
                : 'bg-muted text-muted-foreground'
            )}
            onClick={handleSend}
            disabled={!input.trim() || disabled}
          >
            <Send className="h-4 w-4" />
          </Button>
        )}
      </div>

      {/* Keyboard Hint */}
      <div className="mt-2 text-center">
        <span className="text-xs text-muted-foreground/50">
          {t('chat.keyboardHint', { defaultValue: 'Enter 发送, Shift+Enter 换行' })}
        </span>
      </div>
    </div>
  );
}
