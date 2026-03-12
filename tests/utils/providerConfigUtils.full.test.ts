/**
 * TDD Tests: utils/providerConfigUtils.ts
 *
 * Exhaustive tests for every exported function.
 * All tests are pure unit tests (no mocks needed – functions are pure).
 */
import { describe, expect, it } from "vitest";
import {
  validateJsonConfig,
  updateCommonConfigSnippet,
  hasCommonConfigSnippet,
  getApiKeyFromConfig,
  hasApiKeyField,
  setApiKeyInConfig,
  applyTemplateValues,
  updateTomlCommonConfigSnippet,
  hasTomlCommonConfigSnippet,
  extractCodexBaseUrl,
  setCodexBaseUrl,
  extractCodexModelName,
  setCodexModelName,
} from "@/utils/providerConfigUtils";

// ──────────────────────────────────────────────
// validateJsonConfig
// ──────────────────────────────────────────────
describe("validateJsonConfig", () => {
  it("returns '' for empty / whitespace input", () => {
    expect(validateJsonConfig("")).toBe("");
    expect(validateJsonConfig("   ")).toBe("");
  });

  it("returns '' for a valid JSON object", () => {
    expect(validateJsonConfig('{"a":1}')).toBe("");
    expect(validateJsonConfig("{}")).toBe("");
  });

  it("returns error message for a JSON array", () => {
    const msg = validateJsonConfig('["a","b"]');
    expect(msg).not.toBe("");
    expect(msg).toMatch(/JSON|对象/);
  });

  it("returns error message for invalid JSON", () => {
    const msg = validateJsonConfig("{bad json}");
    expect(msg).not.toBe("");
  });

  it("uses custom fieldName in error message", () => {
    const msg = validateJsonConfig("[1]", "MCP配置");
    expect(msg).toContain("MCP配置");
  });
});

// ──────────────────────────────────────────────
// updateCommonConfigSnippet
// ──────────────────────────────────────────────
describe("updateCommonConfigSnippet", () => {
  it("merges snippet into config when enabled=true", () => {
    const base = JSON.stringify({ env: { A: "1" } });
    const snippet = JSON.stringify({ env: { B: "2" } });
    const { updatedConfig, error } = updateCommonConfigSnippet(base, snippet, true);
    expect(error).toBeUndefined();
    const parsed = JSON.parse(updatedConfig);
    expect(parsed.env.A).toBe("1");
    expect(parsed.env.B).toBe("2");
  });

  it("removes snippet from config when enabled=false", () => {
    const base = JSON.stringify({ env: { A: "1", B: "2" } });
    const snippet = JSON.stringify({ env: { B: "2" } });
    const { updatedConfig } = updateCommonConfigSnippet(base, snippet, false);
    const parsed = JSON.parse(updatedConfig);
    expect(parsed.env.A).toBe("1");
    expect(parsed.env.B).toBeUndefined();
  });

  it("returns error when base JSON is invalid", () => {
    const { error } = updateCommonConfigSnippet("{bad}", "{}", true);
    expect(error).toBeDefined();
    expect(error).toMatch(/解析失败|JSON/);
  });

  it("returns error when snippet is not a JSON object", () => {
    const { error } = updateCommonConfigSnippet("{}", '["array"]', true);
    expect(error).toBeDefined();
  });

  it("no-op when snippet is empty string", () => {
    const base = JSON.stringify({ a: 1 });
    const { updatedConfig, error } = updateCommonConfigSnippet(base, "  ", true);
    expect(error).toBeUndefined();
    expect(JSON.parse(updatedConfig)).toEqual({ a: 1 });
  });

  it("does not mutate nested objects (deep-clone)", () => {
    const base = JSON.stringify({ env: { A: "1" } });
    const snippet = JSON.stringify({ env: { A: "OVERRIDE" } });
    const { updatedConfig } = updateCommonConfigSnippet(base, snippet, true);
    // original base string unmodified
    expect(JSON.parse(base).env.A).toBe("1");
    expect(JSON.parse(updatedConfig).env.A).toBe("OVERRIDE");
  });
});

// ──────────────────────────────────────────────
// hasCommonConfigSnippet
// ──────────────────────────────────────────────
describe("hasCommonConfigSnippet", () => {
  it("returns true when config fully contains snippet", () => {
    const config = JSON.stringify({ env: { A: "1", B: "2" } });
    const snippet = JSON.stringify({ env: { A: "1" } });
    expect(hasCommonConfigSnippet(config, snippet)).toBe(true);
  });

  it("returns false when snippet key is different value", () => {
    const config = JSON.stringify({ env: { A: "1" } });
    const snippet = JSON.stringify({ env: { A: "different" } });
    expect(hasCommonConfigSnippet(config, snippet)).toBe(false);
  });

  it("returns false for empty snippet string", () => {
    expect(hasCommonConfigSnippet("{}", "  ")).toBe(false);
  });

  it("returns false on parse errors", () => {
    expect(hasCommonConfigSnippet("{bad}", "{}")).toBe(false);
  });

  it("returns false when snippet has key missing from config", () => {
    const config = JSON.stringify({ env: { A: "1" } });
    const snippet = JSON.stringify({ env: { A: "1", MISSING: "x" } });
    expect(hasCommonConfigSnippet(config, snippet)).toBe(false);
  });
});

// ──────────────────────────────────────────────
// getApiKeyFromConfig
// ──────────────────────────────────────────────
describe("getApiKeyFromConfig", () => {
  it("extracts ANTHROPIC_AUTH_TOKEN (default/claude appType)", () => {
    const cfg = JSON.stringify({ env: { ANTHROPIC_AUTH_TOKEN: "sk-token" } });
    expect(getApiKeyFromConfig(cfg)).toBe("sk-token");
  });

  it("falls back to ANTHROPIC_API_KEY when AUTH_TOKEN missing", () => {
    const cfg = JSON.stringify({ env: { ANTHROPIC_API_KEY: "sk-api" } });
    expect(getApiKeyFromConfig(cfg)).toBe("sk-api");
  });

  it("extracts GEMINI_API_KEY when appType=gemini", () => {
    const cfg = JSON.stringify({ env: { GEMINI_API_KEY: "AIza-key" } });
    expect(getApiKeyFromConfig(cfg, "gemini")).toBe("AIza-key");
  });

  it("extracts CODEX_API_KEY when appType=codex", () => {
    const cfg = JSON.stringify({ env: { CODEX_API_KEY: "cx-key" } });
    expect(getApiKeyFromConfig(cfg, "codex")).toBe("cx-key");
  });

  it("extracts top-level apiKey field (Bedrock preset)", () => {
    const cfg = JSON.stringify({ apiKey: "bedrock-key" });
    expect(getApiKeyFromConfig(cfg)).toBe("bedrock-key");
  });

  it("ignores top-level apiKey if it contains template placeholder", () => {
    const cfg = JSON.stringify({ apiKey: "${API_KEY}" });
    // Must not return the placeholder as-is – falls through to env
    const result = getApiKeyFromConfig(cfg);
    expect(result).not.toBe("${API_KEY}");
  });

  it("returns '' when no env key present", () => {
    const cfg = JSON.stringify({ env: {} });
    expect(getApiKeyFromConfig(cfg)).toBe("");
  });

  it("returns '' on invalid JSON", () => {
    expect(getApiKeyFromConfig("{bad}")).toBe("");
  });
});

// ──────────────────────────────────────────────
// hasApiKeyField
// ──────────────────────────────────────────────
describe("hasApiKeyField", () => {
  it("returns true when ANTHROPIC_AUTH_TOKEN present", () => {
    expect(hasApiKeyField(JSON.stringify({ env: { ANTHROPIC_AUTH_TOKEN: "" } }))).toBe(true);
  });

  it("returns true when ANTHROPIC_API_KEY present", () => {
    expect(hasApiKeyField(JSON.stringify({ env: { ANTHROPIC_API_KEY: "" } }))).toBe(true);
  });

  it("returns true when top-level apiKey present", () => {
    expect(hasApiKeyField(JSON.stringify({ apiKey: "" }))).toBe(true);
  });

  it("returns false when env exists but has no api key key", () => {
    expect(hasApiKeyField(JSON.stringify({ env: { OTHER: "x" } }))).toBe(false);
  });

  it("returns false on invalid JSON", () => {
    expect(hasApiKeyField("{bad}")).toBe(false);
  });

  it("returns true for GEMINI_API_KEY when appType=gemini", () => {
    expect(hasApiKeyField(JSON.stringify({ env: { GEMINI_API_KEY: "" } }), "gemini")).toBe(true);
  });

  it("returns false for GEMINI_API_KEY when appType is default (claude)", () => {
    const cfg = JSON.stringify({ env: { GEMINI_API_KEY: "" } });
    expect(hasApiKeyField(cfg)).toBe(false);
  });
});

// ──────────────────────────────────────────────
// setApiKeyInConfig
// ──────────────────────────────────────────────
describe("setApiKeyInConfig", () => {
  it("updates ANTHROPIC_AUTH_TOKEN in place", () => {
    const cfg = JSON.stringify({ env: { ANTHROPIC_AUTH_TOKEN: "old" } });
    const result = JSON.parse(setApiKeyInConfig(cfg, "new-key"));
    expect(result.env.ANTHROPIC_AUTH_TOKEN).toBe("new-key");
  });

  it("updates ANTHROPIC_API_KEY when AUTH_TOKEN absent", () => {
    const cfg = JSON.stringify({ env: { ANTHROPIC_API_KEY: "old" } });
    const result = JSON.parse(setApiKeyInConfig(cfg, "new"));
    expect(result.env.ANTHROPIC_API_KEY).toBe("new");
  });

  it("does not create field when createIfMissing=false (default)", () => {
    const cfg = JSON.stringify({ env: {} });
    const result = setApiKeyInConfig(cfg, "new");
    expect(JSON.parse(result).env).toEqual({});
  });

  it("creates ANTHROPIC_AUTH_TOKEN when createIfMissing=true", () => {
    const cfg = JSON.stringify({ env: {} });
    const result = JSON.parse(setApiKeyInConfig(cfg, "new", { createIfMissing: true }));
    expect(result.env.ANTHROPIC_AUTH_TOKEN).toBe("new");
  });

  it("updates top-level apiKey when field exists", () => {
    const cfg = JSON.stringify({ apiKey: "old" });
    const result = JSON.parse(setApiKeyInConfig(cfg, "new"));
    expect(result.apiKey).toBe("new");
  });

  it("updates GEMINI_API_KEY when appType=gemini", () => {
    const cfg = JSON.stringify({ env: { GEMINI_API_KEY: "old" } });
    const result = JSON.parse(setApiKeyInConfig(cfg, "new", { appType: "gemini" }));
    expect(result.env.GEMINI_API_KEY).toBe("new");
  });

  it("returns original string on parse error", () => {
    expect(setApiKeyInConfig("{bad}", "new")).toBe("{bad}");
  });
});

// ──────────────────────────────────────────────
// applyTemplateValues
// ──────────────────────────────────────────────
describe("applyTemplateValues", () => {
  it("replaces ${KEY} placeholders in nested strings", () => {
    const config = { env: { ANTHROPIC_BASE_URL: "https://example.com/${ENDPOINT_ID}/api" } };
    const templateValues = {
      ENDPOINT_ID: { label: "ID", placeholder: "", editorValue: "ep-123" },
    };
    const result = applyTemplateValues(config, templateValues);
    expect(result.env.ANTHROPIC_BASE_URL).toBe("https://example.com/ep-123/api");
  });

  it("uses defaultValue when editorValue is undefined", () => {
    const config = { url: "${REGION}" };
    const tpl = { REGION: { label: "R", placeholder: "", defaultValue: "us-west-2", editorValue: "" } };
    // editorValue is "" (empty), so it is used (not defaultValue)
    const result = applyTemplateValues(config, tpl);
    expect(result.url).toBe("");
  });

  it("does not modify non-template strings", () => {
    const config = { name: "haipee" };
    expect(applyTemplateValues(config, {})).toEqual({ name: "haipee" });
  });

  it("traverses arrays", () => {
    const config = { args: ["--region=${REGION}", "--x"] };
    const tpl = { REGION: { label: "R", placeholder: "", editorValue: "eu" } };
    const result = applyTemplateValues(config, tpl);
    expect(result.args[0]).toBe("--region=eu");
    expect(result.args[1]).toBe("--x");
  });

  it("is no-op when templateValues is undefined", () => {
    const config = { a: "${X}" };
    expect(applyTemplateValues(config, undefined)).toEqual({ a: "${X}" });
  });
});

// ──────────────────────────────────────────────
// extractCodexBaseUrl & setCodexBaseUrl
// ──────────────────────────────────────────────
describe("extractCodexBaseUrl", () => {
  it("extracts base_url with double quotes", () => {
    expect(extractCodexBaseUrl(`base_url = "https://api.example.com/v1"`)).toBe(
      "https://api.example.com/v1",
    );
  });

  it("extracts base_url with single quotes", () => {
    expect(extractCodexBaseUrl(`base_url = 'https://api.example.com/v1'`)).toBe(
      "https://api.example.com/v1",
    );
  });

  it("returns undefined for null/empty", () => {
    expect(extractCodexBaseUrl(null)).toBeUndefined();
    expect(extractCodexBaseUrl("")).toBeUndefined();
  });

  it("returns undefined when no base_url line", () => {
    expect(extractCodexBaseUrl(`model = "gpt-4"`)).toBeUndefined();
  });
});

describe("setCodexBaseUrl", () => {
  it("updates existing base_url line", () => {
    const input = `model_provider = "openai"\nbase_url = "https://old.example/v1"\nmodel = "gpt-4"\n`;
    const output = setCodexBaseUrl(input, "https://new.example/v1");
    expect(extractCodexBaseUrl(output)).toBe("https://new.example/v1");
    expect(output).toContain("gpt-4"); // other lines preserved
  });

  it("removes base_url line when set to empty", () => {
    const input = `model_provider = "openai"\nbase_url = "https://old.example/v1"\nmodel = "gpt-4"\n`;
    const output = setCodexBaseUrl(input, "");
    expect(output).not.toMatch(/base_url/);
    expect(output).toContain("gpt-4");
  });

  it("adds base_url when not present and value given", () => {
    const input = `model_provider = "openai"\nmodel = "gpt-4"\n`;
    const output = setCodexBaseUrl(input, "https://new.example/v1");
    expect(extractCodexBaseUrl(output)).toBe("https://new.example/v1");
  });

  it("strips whitespace from the provided URL", () => {
    const input = `base_url = "https://old.example/v1"\n`;
    const output = setCodexBaseUrl(input, "  https://trimmed.example/v1  \n");
    expect(extractCodexBaseUrl(output)).toBe("https://trimmed.example/v1");
  });
});

// ──────────────────────────────────────────────
// extractCodexModelName & setCodexModelName
// ──────────────────────────────────────────────
describe("extractCodexModelName", () => {
  it("extracts model with double quotes", () => {
    expect(extractCodexModelName(`model = "gpt-4o-mini"`)).toBe("gpt-4o-mini");
  });

  it("extracts model with single quotes", () => {
    expect(extractCodexModelName(`model = 'gpt-4o'`)).toBe("gpt-4o");
  });

  it("returns undefined for empty/null", () => {
    expect(extractCodexModelName(null)).toBeUndefined();
    expect(extractCodexModelName("")).toBeUndefined();
  });

  it("returns undefined when no model line", () => {
    expect(extractCodexModelName(`base_url = "https://example.com"`)).toBeUndefined();
  });
});

describe("setCodexModelName", () => {
  it("updates existing model line", () => {
    const input = `model_provider = "openai"\nmodel = "old-model"\n`;
    const output = setCodexModelName(input, "new-model");
    expect(extractCodexModelName(output)).toBe("new-model");
  });

  it("removes model line when set to empty", () => {
    const input = `model_provider = "openai"\nmodel = "old-model"\n`;
    const output = setCodexModelName(input, "");
    expect(output).not.toMatch(/^\s*model\s*=/m);
  });

  it("adds model after model_provider when model absent", () => {
    const input = `model_provider = "openai"\nbase_url = "https://example"\n`;
    const output = setCodexModelName(input, "gpt-4o");
    expect(extractCodexModelName(output)).toBe("gpt-4o");
  });

  it("trims whitespace from model name", () => {
    const input = `model = "old"\n`;
    const output = setCodexModelName(input, "  new-model  \n");
    expect(extractCodexModelName(output)).toBe("new-model");
  });
});

// ──────────────────────────────────────────────
// hasTomlCommonConfigSnippet & updateTomlCommonConfigSnippet
// ──────────────────────────────────────────────
describe("hasTomlCommonConfigSnippet", () => {
  it("returns false for empty snippet", () => {
    expect(hasTomlCommonConfigSnippet(`key = "value"`, "")).toBe(false);
  });

  it("returns true when TOML config contains snippet", () => {
    const config = `key = "value"\nother = "data"\n`;
    const snippet = `key = "value"`;
    expect(hasTomlCommonConfigSnippet(config, snippet)).toBe(true);
  });

  it("returns false when snippet value differs", () => {
    const config = `key = "value"`;
    const snippet = `key = "different"`;
    expect(hasTomlCommonConfigSnippet(config, snippet)).toBe(false);
  });
});

describe("updateTomlCommonConfigSnippet", () => {
  it("merges snippet into TOML config when enabled=true", () => {
    const base = `a = "1"\n`;
    const snippet = `b = "2"\n`;
    const { updatedConfig, error } = updateTomlCommonConfigSnippet(base, snippet, true);
    expect(error).toBeUndefined();
    expect(updatedConfig).toContain("a");
    expect(updatedConfig).toContain("b");
  });

  it("removes snippet from TOML config when enabled=false", () => {
    const base = `a = "1"\nb = "2"\n`;
    const snippet = `b = "2"\n`;
    const { updatedConfig } = updateTomlCommonConfigSnippet(base, snippet, false);
    expect(updatedConfig).toContain("a");
    expect(updatedConfig).not.toContain("b");
  });

  it("returns updatedConfig unchanged with error when TOML invalid", () => {
    const { updatedConfig, error } = updateTomlCommonConfigSnippet("!!!INVALID", `a = "1"`, true);
    expect(error).toBeDefined();
    expect(updatedConfig).toBe("!!!INVALID");
  });
});
