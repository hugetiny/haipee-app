import { useReducer, useCallback, useMemo } from 'react';
import type { ChatSession, ChatMessage, ChatState, ChatAction } from './types';

const initialState: ChatState = {
  sessions: [],
  currentSessionId: null,
  isLoading: false,
  error: null,
};

function chatReducer(state: ChatState, action: ChatAction): ChatState {
  switch (action.type) {
    case 'CREATE_SESSION': {
      const newSession: ChatSession = {
        id: crypto.randomUUID(),
        title: '新对话',
        messages: [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        providerId: action.payload.providerId,
        appId: action.payload.appId,
      };
      return {
        ...state,
        sessions: [newSession, ...state.sessions],
        currentSessionId: newSession.id,
      };
    }

    case 'DELETE_SESSION': {
      const newSessions = state.sessions.filter((s) => s.id !== action.payload);
      return {
        ...state,
        sessions: newSessions,
        currentSessionId:
          state.currentSessionId === action.payload
            ? newSessions[0]?.id || null
            : state.currentSessionId,
      };
    }

    case 'SET_CURRENT_SESSION':
      return {
        ...state,
        currentSessionId: action.payload,
      };

    case 'ADD_MESSAGE': {
      return {
        ...state,
        sessions: state.sessions.map((session) =>
          session.id === action.payload.sessionId
            ? {
                ...session,
                messages: [...session.messages, action.payload.message],
                updatedAt: Date.now(),
                title:
                  session.messages.length === 0 && action.payload.message.role === 'user'
                    ? action.payload.message.content.slice(0, 20) + '...'
                    : session.title,
              }
            : session
        ),
      };
    }

    case 'UPDATE_MESSAGE': {
      return {
        ...state,
        sessions: state.sessions.map((session) =>
          session.id === action.payload.sessionId
            ? {
                ...session,
                messages: session.messages.map((msg) =>
                  msg.id === action.payload.messageId
                    ? { ...msg, ...action.payload.updates }
                    : msg
                ),
                updatedAt: Date.now(),
              }
            : session
        ),
      };
    }

    case 'SET_STREAMING': {
      return {
        ...state,
        sessions: state.sessions.map((session) =>
          session.id === action.payload.sessionId
            ? {
                ...session,
                messages: session.messages.map((msg) =>
                  msg.id === action.payload.messageId
                    ? { ...msg, isStreaming: action.payload.isStreaming }
                    : msg
                ),
              }
            : session
        ),
      };
    }

    case 'SET_LOADING':
      return {
        ...state,
        isLoading: action.payload,
      };

    case 'SET_ERROR':
      return {
        ...state,
        error: action.payload,
      };

    default:
      return state;
  }
}

export function useChat() {
  const [state, dispatch] = useReducer(chatReducer, initialState);

  const createSession = useCallback((providerId: string, appId: string) => {
    dispatch({ type: 'CREATE_SESSION', payload: { providerId, appId } });
  }, []);

  const deleteSession = useCallback((sessionId: string) => {
    dispatch({ type: 'DELETE_SESSION', payload: sessionId });
  }, []);

  const setCurrentSession = useCallback((sessionId: string) => {
    dispatch({ type: 'SET_CURRENT_SESSION', payload: sessionId });
  }, []);

  const addMessage = useCallback((sessionId: string, message: ChatMessage) => {
    dispatch({ type: 'ADD_MESSAGE', payload: { sessionId, message } });
  }, []);

  const updateMessage = useCallback(
    (sessionId: string, messageId: string, updates: Partial<ChatMessage>) => {
      dispatch({ type: 'UPDATE_MESSAGE', payload: { sessionId, messageId, updates } });
    },
    []
  );

  const setStreaming = useCallback(
    (sessionId: string, messageId: string, isStreaming: boolean) => {
      dispatch({ type: 'SET_STREAMING', payload: { sessionId, messageId, isStreaming } });
    },
    []
  );

  const setLoading = useCallback((isLoading: boolean) => {
    dispatch({ type: 'SET_LOADING', payload: isLoading });
  }, []);

  const setError = useCallback((error: string | null) => {
    dispatch({ type: 'SET_ERROR', payload: error });
  }, []);

  const currentSession = useMemo(() => {
    return state.sessions.find((s) => s.id === state.currentSessionId) || null;
  }, [state.sessions, state.currentSessionId]);

  return {
    sessions: state.sessions,
    currentSessionId: state.currentSessionId,
    currentSession,
    isLoading: state.isLoading,
    error: state.error,
    createSession,
    deleteSession,
    setCurrentSession,
    addMessage,
    updateMessage,
    setStreaming,
    setLoading,
    setError,
  };
}
