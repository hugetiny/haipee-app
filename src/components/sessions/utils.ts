import { SessionMeta } from "@/types";

export const getSessionKey = (session: SessionMeta) =>
  `${session.providerId}:${session.sessionId}:${session.sourcePath ?? ""}`;

export const getBaseName = (value?: string | null) => {
  if (!value) return "";
  const trimmed = value.trim();
  if (!trimmed) return "";
  const normalized = trimmed.replace(/[\\/]+$/, "");
  const parts = normalized.split(/[\\/]/).filter(Boolean);
  return parts[parts.length - 1] || trimmed;
};

export const formatTimestamp = (value?: number) => {
  if (!value) return "";
  return new Date(value).toLocaleString();
};

export const formatRelativeTime = (
  value: number | undefined,
  t: (key: string, options?: Record<string, unknown>) => string,
) => {
  if (!value) return "";
  const now = Date.now();
  const diff = now - value;
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);

  if (minutes < 1) return t("sessionManager.justNow");
  if (minutes < 60) return t("sessionManager.minutesAgo", { count: minutes });
  if (hours < 24) return t("sessionManager.hoursAgo", { count: hours });
  if (days < 7) return t("sessionManager.daysAgo", { count: days });
  return new Date(value).toLocaleDateString();
};

export const getProviderLabel = (
  providerId: string,
  t: (key: string) => string,
) => {
  const key = `apps.${providerId}`;
  const translated = t(key);
  return translated === key ? providerId : translated;
};

// 根据 providerId 获取对应的图标名称
export const getProviderIconName = (providerId: string) => {
  if (providerId === "codex") return "openai";
  if (providerId === "claude") return "claude";
  if (providerId === "opencode") return "opencode";
  if (providerId === "openclaw") return "openclaw";
  return providerId;
};

export const getRoleTone = (role: string) => {
  const normalized = role.toLowerCase();
  if (normalized === "assistant") return "text-blue-500";
  if (normalized === "user") return "text-emerald-500";
  if (normalized === "system") return "text-amber-500";
  if (normalized === "tool") return "text-purple-500";
  return "text-muted-foreground";
};

export const getRoleLabel = (role: string, t: (key: string) => string) => {
  const normalized = role.toLowerCase();
  if (normalized === "assistant") return "AI";
  if (normalized === "user") return t("sessionManager.roleUser");
  if (normalized === "system") return t("sessionManager.roleSystem");
  if (normalized === "tool") return t("sessionManager.roleTool");
  return role;
};

export const formatSessionTitle = (
  session: SessionMeta,
  t?: (key: string) => string,
) => {
  // 1. Prefer explicit title (unless it's just "workspace", which is a common CLI default)
  if (session.title && session.title.toLowerCase() !== "workspace") {
    return session.title;
  }

  // If title is missing or generic "workspace", try using the project directory name
  const dirPath = session.sourcePath || session.projectDir;
  if (dirPath) {
    const dirName = getBaseName(dirPath);
    if (dirName && dirName.toLowerCase() !== "workspace") {
      return dirName;
    }
  }

  // 2. Use Provider Name as the default title format
  // If translation function is provided, use it, otherwise fallback to capitalized providerId
  if (t) {
    const defaultLabel =
      session.providerId.charAt(0).toUpperCase() + session.providerId.slice(1);
    // Special casing for known providers without translation or needing specific format
    if (session.providerId === "openclaw") return "Local OpenClaw";
    if (session.providerId === "claude") return "Claude Code";
    if (session.providerId === "opencode") return "OpenCode";
    if (session.providerId === "codex") return "Codex";
    if (session.providerId === "gemini") return "Gemini CLI";

    const key = `apps.${session.providerId}`;
    const translated = t(key);
    return translated === key ? defaultLabel : translated;
  }

  // Pure fallback
  if (session.providerId === "openclaw") return "Local OpenClaw";
  if (session.providerId === "claude") return "Claude Code";
  return (
    session.providerId.charAt(0).toUpperCase() + session.providerId.slice(1)
  );
};
