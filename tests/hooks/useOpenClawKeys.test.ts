/**
 * TDD Tests: openclaw query key structure (useOpenClaw.ts – openclawKeys)
 *
 * These are pure unit tests – no React / DOM needed.
 * They enforce that the query key factory returns stable,
 * hierarchically-correct tuples so cache invalidation works correctly.
 */
import { describe, expect, it } from "vitest";
import { openclawKeys } from "@/hooks/useOpenClaw";

describe("openclawKeys query key factory", () => {
  const INSTANCE = "default";

  it("all is the root key tuple", () => {
    expect(openclawKeys.all).toEqual(["openclaw"]);
  });

  it("liveProviderIds key starts with the root", () => {
    const key = openclawKeys.liveProviderIds(INSTANCE);
    expect(key[0]).toBe("openclaw");
    expect(key).toContain(INSTANCE);
    expect(key).toContain("liveProviderIds");
  });

  it("defaultModel key starts with the root", () => {
    const key = openclawKeys.defaultModel(INSTANCE);
    expect(key[0]).toBe("openclaw");
    expect(key).toContain("defaultModel");
  });

  it("env key starts with the root", () => {
    const key = openclawKeys.env(INSTANCE);
    expect(key[0]).toBe("openclaw");
    expect(key).toContain("env");
  });

  it("tools key starts with the root", () => {
    const key = openclawKeys.tools(INSTANCE);
    expect(key[0]).toBe("openclaw");
    expect(key).toContain("tools");
  });

  it("agentsDefaults key starts with the root", () => {
    const key = openclawKeys.agentsDefaults(INSTANCE);
    expect(key[0]).toBe("openclaw");
    expect(key).toContain("agentsDefaults");
  });

  it("health key starts with the root", () => {
    const key = openclawKeys.health(INSTANCE);
    expect(key[0]).toBe("openclaw");
    expect(key).toContain("health");
  });

  it("jsonSection key includes both instanceId and section name", () => {
    const key = openclawKeys.jsonSection(INSTANCE, "browser");
    expect(key[0]).toBe("openclaw");
    expect(key).toContain(INSTANCE);
    expect(key).toContain("jsonSection");
    expect(key).toContain("browser");
  });

  it("rawJson key starts with the root", () => {
    const key = openclawKeys.rawJson(INSTANCE);
    expect(key[0]).toBe("openclaw");
    expect(key).toContain("rawJson");
  });

  it("different instances produce different keys", () => {
    const a = openclawKeys.env("instance-a");
    const b = openclawKeys.env("instance-b");
    expect(JSON.stringify(a)).not.toBe(JSON.stringify(b));
  });

  it("different sections produce different jsonSection keys", () => {
    const browser = openclawKeys.jsonSection(INSTANCE, "browser");
    const gateway = openclawKeys.jsonSection(INSTANCE, "gateway");
    expect(JSON.stringify(browser)).not.toBe(JSON.stringify(gateway));
  });
});
