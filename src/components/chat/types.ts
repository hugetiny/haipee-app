export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
  isStreaming?: boolean;
  error?: string;
  attachments?: ChatAttachment[];
  thinking?: string;
}

export interface ChatAttachment {
  id: string;
  name: string;
  type: string;
  size: number;
  path?: string;
}

export interface ChatSession {
  id: string;
  title: string;
  messages: ChatMessage[];
  createdAt: number;
  updatedAt: number;
  providerId: string;
  appId: string;
}

export interface ChatState {
  sessions: ChatSession[];
  currentSessionId: string | null;
  isLoading: boolean;
  error: string | null;
}

export type ChatAction =
  | { type: 'CREATE_SESSION'; payload: { providerId: string; appId: string } }
  | { type: 'DELETE_SESSION'; payload: string }
  | { type: 'SET_CURRENT_SESSION'; payload: string }
  | { type: 'ADD_MESSAGE'; payload: { sessionId: string; message: ChatMessage } }
  | { type: 'UPDATE_MESSAGE'; payload: { sessionId: string; messageId: string; updates: Partial<ChatMessage> } }
  | { type: 'SET_STREAMING'; payload: { sessionId: string; messageId: string; isStreaming: boolean } }
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null };
