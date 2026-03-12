/**
 * TDD Tests: openclaw/utils.ts
 *
 * Tests every exported function. These define the target behaviour
 * Claude Code must maintain while auto-refactoring.
 */
import { describe, expect, it } from "vitest";
import {
  OPENCLAW_TOOL_PROFILES,
  OPENCLAW_UNSUPPORTED_PROFILE,
  OPENCLAW_UNSET_PROFILE,
  parseOpenClawEnvEditorValue,
  isOpenClawToolsProfile,
  getOpenClawToolsProfileSelectValue,
  getOpenClawUnsupportedProfile,
  getOpenClawTimeoutInputValue,
} from "@/components/openclaw/utils";

// ──────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────
describe("OPENCLAW_TOOL_PROFILES", () => {
  it("contains exactly the four known profiles", () => {
    expect(OPENCLAW_TOOL_PROFILES).toEqual(["minimal", "coding", "messaging", "full"]);
  });

  it("OPENCLAW_UNSUPPORTED_PROFILE is a sentinel string", () => {
    expect(OPENCLAW_UNSUPPORTED_PROFILE).toBe("__unsupported_profile__");
    expect(OPENCLAW_TOOL_PROFILES).not.toContain(OPENCLAW_UNSUPPORTED_PROFILE);
  });

  it("OPENCLAW_UNSET_PROFILE is a sentinel string", () => {
    expect(OPENCLAW_UNSET_PROFILE).toBe("__unset_profile__");
    expect(OPENCLAW_TOOL_PROFILES).not.toContain(OPENCLAW_UNSET_PROFILE);
  });
});

// ──────────────────────────────────────────────
// parseOpenClawEnvEditorValue
// ──────────────────────────────────────────────
describe("parseOpenClawEnvEditorValue", () => {
  it("parses a flat API key object", () => {
    const result = parseOpenClawEnvEditorValue('{"API_KEY":"secret"}');
    expect(result).toEqual({ API_KEY: "secret" });
  });

  it("parses nested vars / shellEnv without stringifying them", () => {
    const result = parseOpenClawEnvEditorValue(`{
      "API_KEY": "secret",
      "vars": { "HTTP_PROXY": "http://127.0.0.1:8080" },
      "shellEnv": { "NODE_OPTIONS": "--max-old-space-size=4096" }
    }`);
    expect(result).toEqual({
      API_KEY: "secret",
      vars: { HTTP_PROXY: "http://127.0.0.1:8080" },
      shellEnv: { NODE_OPTIONS: "--max-old-space-size=4096" },
    });
  });

  it("throws OPENCLAW_ENV_EMPTY for blank input", () => {
    expect(() => parseOpenClawEnvEditorValue("")).toThrow("OPENCLAW_ENV_EMPTY");
    expect(() => parseOpenClawEnvEditorValue("   ")).toThrow("OPENCLAW_ENV_EMPTY");
  });

  it("throws OPENCLAW_ENV_INVALID_JSON for malformed JSON", () => {
    expect(() => parseOpenClawEnvEditorValue("{bad}")).toThrow("OPENCLAW_ENV_INVALID_JSON");
  });

  it("throws OPENCLAW_ENV_OBJECT_REQUIRED for arrays", () => {
    expect(() => parseOpenClawEnvEditorValue('["not","an","object"]')).toThrow(
      "OPENCLAW_ENV_OBJECT_REQUIRED",
    );
  });

  it("throws OPENCLAW_ENV_OBJECT_REQUIRED for primitive JSON", () => {
    expect(() => parseOpenClawEnvEditorValue('"just a string"')).toThrow(
      "OPENCLAW_ENV_OBJECT_REQUIRED",
    );
  });

  it("parses empty object {}", () => {
    expect(parseOpenClawEnvEditorValue("{}")).toEqual({});
  });
});

// ──────────────────────────────────────────────
// isOpenClawToolsProfile
// ──────────────────────────────────────────────
describe("isOpenClawToolsProfile", () => {
  it.each(["minimal", "coding", "messaging", "full"] as const)(
    "returns true for '%s'",
    (p) => expect(isOpenClawToolsProfile(p)).toBe(true),
  );

  it("returns false for unsupported sentinel", () => {
    expect(isOpenClawToolsProfile(OPENCLAW_UNSUPPORTED_PROFILE)).toBe(false);
  });

  it("returns false for empty string / undefined", () => {
    expect(isOpenClawToolsProfile("")).toBe(false);
    expect(isOpenClawToolsProfile(undefined)).toBe(false);
  });

  it("returns false for arbitrary strings", () => {
    expect(isOpenClawToolsProfile("default")).toBe(false);
    expect(isOpenClawToolsProfile("CODING")).toBe(false);
  });
});

// ──────────────────────────────────────────────
// getOpenClawToolsProfileSelectValue
// ──────────────────────────────────────────────
describe("getOpenClawToolsProfileSelectValue", () => {
  it("returns UNSET_PROFILE for undefined/empty", () => {
    expect(getOpenClawToolsProfileSelectValue(undefined)).toBe(OPENCLAW_UNSET_PROFILE);
    expect(getOpenClawToolsProfileSelectValue("")).toBe(OPENCLAW_UNSET_PROFILE);
  });

  it("returns the profile itself for known profiles", () => {
    for (const p of OPENCLAW_TOOL_PROFILES) {
      expect(getOpenClawToolsProfileSelectValue(p)).toBe(p);
    }
  });

  it("returns UNSUPPORTED sentinel for unknown profiles", () => {
    expect(getOpenClawToolsProfileSelectValue("default")).toBe(OPENCLAW_UNSUPPORTED_PROFILE);
    expect(getOpenClawToolsProfileSelectValue("custom-profile")).toBe(OPENCLAW_UNSUPPORTED_PROFILE);
  });
});

// ──────────────────────────────────────────────
// getOpenClawUnsupportedProfile
// ──────────────────────────────────────────────
describe("getOpenClawUnsupportedProfile", () => {
  it("returns null for known profiles", () => {
    for (const p of OPENCLAW_TOOL_PROFILES) {
      expect(getOpenClawUnsupportedProfile(p)).toBeNull();
    }
  });

  it("returns null for undefined/empty", () => {
    expect(getOpenClawUnsupportedProfile(undefined)).toBeNull();
    expect(getOpenClawUnsupportedProfile("")).toBeNull();
  });

  it("returns the raw unknown profile string", () => {
    expect(getOpenClawUnsupportedProfile("default")).toBe("default");
    expect(getOpenClawUnsupportedProfile("custom-xyz")).toBe("custom-xyz");
  });
});

// ──────────────────────────────────────────────
// getOpenClawTimeoutInputValue
// ──────────────────────────────────────────────
describe("getOpenClawTimeoutInputValue", () => {
  it("returns '' for null/undefined defaults", () => {
    expect(getOpenClawTimeoutInputValue(null)).toBe("");
    expect(getOpenClawTimeoutInputValue(undefined)).toBe("");
    expect(getOpenClawTimeoutInputValue({})).toBe("");
  });

  it("prefers timeoutSeconds over legacy timeout", () => {
    expect(getOpenClawTimeoutInputValue({ timeoutSeconds: 120, timeout: 30 })).toBe("120");
  });

  it("falls back to legacy timeout when timeoutSeconds is absent", () => {
    expect(getOpenClawTimeoutInputValue({ timeout: 45 })).toBe("45");
  });

  it("returns '' when both are absent", () => {
    expect(getOpenClawTimeoutInputValue({ model: { primary: "m" } })).toBe("");
  });

  it("handles zero timeout as '0'", () => {
    expect(getOpenClawTimeoutInputValue({ timeoutSeconds: 0 })).toBe("0");
    expect(getOpenClawTimeoutInputValue({ timeout: 0 })).toBe("0");
  });
});
