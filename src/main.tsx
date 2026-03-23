import React from "react";
import { QueryClientProvider } from "@tanstack/react-query";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { message } from "@tauri-apps/plugin-dialog";
import { attachConsole } from "@tauri-apps/plugin-log";
import { exit } from "@tauri-apps/plugin-process";
import ReactDOM from "react-dom/client";
import { ThemeProvider } from "@/components/theme-provider";
import { queryClient } from "@/lib/query";
import { Toaster } from "@/components/ui/sonner";
import App from "./App";
import { UpdateProvider } from "./contexts/UpdateContext";
import i18n from "./i18n";
import "./index.css";
import "@/lib/browser-mock";

interface ConfigLoadErrorPayload {
  path?: string;
  error?: string;
}

function applyPlatformClass(): void {
  const userAgent = navigator.userAgent || "";
  const platform = (navigator.platform || "").toLowerCase();
  const isMac = /mac/i.test(userAgent) || platform.includes("mac");
  if (isMac) {
    document.body.classList.add("is-mac");
  }
}

async function handleConfigLoadError(
  payload: ConfigLoadErrorPayload | null,
): Promise<void> {
  const path = payload?.path ?? "~/.haipee/config.json";
  const detail = payload?.error ?? "Unknown error";

  await message(
    i18n.t("errors.configLoadFailedMessage", {
      path,
      detail,
      defaultValue:
        "无法读取配置文件：\n{{path}}\n\n错误详情：\n{{detail}}\n\n请手动检查 JSON 是否有效，或从同目录的备份文件（如 config.json.bak）恢复。\n\n应用将退出以便您进行修复。",
    }),
    {
      title: i18n.t("errors.configLoadFailedTitle", {
        defaultValue: "配置加载失败",
      }),
      kind: "error",
    },
  );

  await exit(1);
}

function subscribeConfigLoadError(): void {
  void listen("configLoadError", async (event) => {
    await handleConfigLoadError(event.payload as ConfigLoadErrorPayload | null);
  }).catch((error) => {
    console.error("Failed to subscribe configLoadError event", error);
  });
}

function renderApp(rootElement: HTMLElement): void {
  ReactDOM.createRoot(rootElement).render(
    <React.StrictMode>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider defaultTheme="dark" storageKey="haipee-theme">
          <UpdateProvider>
            <App />
            <Toaster />
          </UpdateProvider>
        </ThemeProvider>
      </QueryClientProvider>
    </React.StrictMode>,
  );
}

async function checkInitError(): Promise<void> {
  const initError = await Promise.race([
    invoke("get_init_error") as Promise<ConfigLoadErrorPayload | null>,
    new Promise<null>((resolve) => setTimeout(() => resolve(null), 3000)),
  ]);

  if (initError && (initError.path || initError.error)) {
    await handleConfigLoadError(initError);
  }
}

async function bootstrap(): Promise<void> {
  applyPlatformClass();
  subscribeConfigLoadError();

  const rootElement = document.getElementById("root");
  if (!rootElement) {
    console.error("Root element not found");
    return;
  }

  renderApp(rootElement);

  if (typeof window !== "undefined" && (window as any).__TAURI_INTERNALS__) {
    try {
      void attachConsole();
    } catch (error) {
      console.error("Failed to attach console", error);
    }

    try {
      await checkInitError();
    } catch (error) {
      console.error("Init error check failed", error);
    }
  }
}

void bootstrap();
