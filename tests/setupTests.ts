import "@testing-library/jest-dom";
import { afterAll, afterEach, beforeAll, vi } from "vitest";
import { cleanup } from "@testing-library/react";
import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import { server } from "./msw/server";
import { resetProviderState } from "./msw/state";
import "./msw/tauriMocks";

beforeAll(async () => {
  server.listen({ onUnhandledRequest: "warn" });
  await i18n.use(initReactI18next).init({
    lng: "zh",
    fallbackLng: "zh",
    resources: {
      zh: {
        translation: {
          usage: {
            title: "用量信息",
            loading: "加载中...",
            refresh: "刷新",
            refreshUsage: "刷新用量",
            lastUpdated: "更新时间",
            justNow: "刚刚",
            minutesAgo: "{{count}} 分钟前",
            hoursAgo: "{{count}} 小时前",
            daysAgo: "{{count}} 天前",
            error: {
              title: "用量查询失败",
              default: "查询失败",
            },
            queryFailed: "查询失败",
            plan: "套餐",
            total: "总量",
            used: "已用",
            remaining: "剩余",
            expiresAt: "到期时间",
            unlimited: "无限",
            quotaExceeded: "用量超限",
            checkError: "检查用量时出错",
          },
        },
      },
      en: {
        translation: {
          usage: {
            title: "Usage Info",
            loading: "Loading...",
            refresh: "Refresh",
            lastUpdated: "Last updated",
            justNow: "just now",
            minutesAgo: "{{count}} minutes ago",
            hoursAgo: "{{count}} hours ago",
            daysAgo: "{{count}} days ago",
            error: {
              title: "Usage Query Failed",
              default: "Query failed",
            },
            plan: "Plan",
            total: "Total",
            used: "Used",
            remaining: "Remaining",
            expiresAt: "Expires at",
            unlimited: "Unlimited",
            quotaExceeded: "Quota exceeded",
            checkError: "Error checking usage",
          },
        },
      },
    },
    interpolation: {
      escapeValue: false,
    },
  });
});

afterEach(() => {
  cleanup();
  resetProviderState();
  server.resetHandlers();
  vi.clearAllMocks();
});

afterAll(() => {
  server.close();
});
