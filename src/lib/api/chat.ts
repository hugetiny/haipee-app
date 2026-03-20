import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';

export interface ChatMessagePayload {
  role: string;
  content: string;
}

export interface ChatChunkEvent {
  sessionId: string;
  messageId: string;
  delta: string;
}

export interface ChatDoneEvent {
  sessionId: string;
  messageId: string;
}

export interface ChatErrorEvent {
  sessionId: string;
  messageId: string;
  error: string;
}

export interface ChatProviderInfo {
  providerId: string;
  providerName: string;
  baseUrl: string;
  defaultModel: string;
  appType: string;
}

export interface ChatStreamCallbacks {
  onChunk: (delta: string) => void;
  onDone: () => void;
  onError: (error: string) => void;
}

/**
 * Get the current active provider info for a given app type.
 */
export async function getChatProviderInfo(appType: string): Promise<ChatProviderInfo | null> {
  return invoke<ChatProviderInfo | null>('get_chat_provider_info', { appType });
}

/**
 * Send a message to the active provider and stream the response.
 * Returns an unlisten function to clean up event listeners.
 */
export async function sendChatMessage(
  appType: string,
  sessionId: string,
  messageId: string,
  messages: ChatMessagePayload[],
  model: string | null,
  callbacks: ChatStreamCallbacks
): Promise<UnlistenFn> {
  // Set up event listeners before invoking the command
  const unlistenFns: UnlistenFn[] = [];

  const unlistenChunk = await listen<ChatChunkEvent>('chat-chunk', (event) => {
    const { sessionId: sid, messageId: mid, delta } = event.payload;
    if (sid === sessionId && mid === messageId) {
      callbacks.onChunk(delta);
    }
  });
  unlistenFns.push(unlistenChunk);

  const unlistenDone = await listen<ChatDoneEvent>('chat-done', (event) => {
    const { sessionId: sid, messageId: mid } = event.payload;
    if (sid === sessionId && mid === messageId) {
      callbacks.onDone();
      cleanup();
    }
  });
  unlistenFns.push(unlistenDone);

  const unlistenError = await listen<ChatErrorEvent>('chat-error', (event) => {
    const { sessionId: sid, messageId: mid, error } = event.payload;
    if (sid === sessionId && mid === messageId) {
      callbacks.onError(error);
      cleanup();
    }
  });
  unlistenFns.push(unlistenError);

  const cleanup = () => {
    for (const fn of unlistenFns) {
      fn();
    }
  };

  // Fire and forget - the streaming happens via events
  invoke('chat_with_provider', {
    appType,
    sessionId,
    messageId,
    messages,
    model,
  }).catch((err: unknown) => {
    callbacks.onError(err instanceof Error ? err.message : String(err));
    cleanup();
  });

  return cleanup;
}
