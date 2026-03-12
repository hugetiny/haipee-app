/**
 * TDD Tests: utils/formatters.ts
 */
import { describe, expect, it } from "vitest";
import { formatJSON, parseSmartMcpJson } from "@/utils/formatters";

describe("formatJSON", () => {
  it("formats compact JSON with 2-space indent", () => {
    const result = formatJSON('{"a":1,"b":2}');
    expect(result).toBe(JSON.stringify({ a: 1, b: 2 }, null, 2));
  });

  it("returns '' for empty / whitespace input", () => {
    expect(formatJSON("")).toBe("");
    expect(formatJSON("   ")).toBe("");
  });

  it("throws on invalid JSON", () => {
    expect(() => formatJSON("{bad json}")).toThrow();
  });

  it("handles nested objects and arrays", () => {
    const input = '{"env":{"A":"1"},"args":["--x","--y"]}';
    const result = formatJSON(input);
    const parsed = JSON.parse(result);
    expect(parsed.env.A).toBe("1");
    expect(parsed.args).toEqual(["--x", "--y"]);
  });
});

describe("parseSmartMcpJson", () => {
  it("parses direct MCP config object (no wrapper)", () => {
    const input = JSON.stringify({ command: "npx", args: ["-y", "server"] });
    const { id, config } = parseSmartMcpJson(input);
    expect(id).toBeUndefined();
    expect(config.command).toBe("npx");
  });

  it("parses single-key wrapped object and extracts id", () => {
    const input = JSON.stringify({ "my-server": { command: "node", args: ["server.js"] } });
    const { id, config } = parseSmartMcpJson(input);
    expect(id).toBe("my-server");
    expect(config.command).toBe("node");
  });

  it("parses key:value fragment starting with quote", () => {
    const input = `"my-server": { "command": "node" }`;
    const { id, config } = parseSmartMcpJson(input);
    expect(id).toBe("my-server");
    expect(config.command).toBe("node");
  });

  it("returns empty config and no id for empty string", () => {
    const { id, config, formattedConfig } = parseSmartMcpJson("  ");
    expect(id).toBeUndefined();
    expect(config).toEqual({});
    expect(formattedConfig).toBe("");
  });

  it("throws for invalid JSON", () => {
    expect(() => parseSmartMcpJson("{bad}")).toThrow();
  });

  it("treats multi-key object as direct config (no id extraction)", () => {
    const input = JSON.stringify({ command: "npx", args: ["-y"] });
    const { id } = parseSmartMcpJson(input);
    expect(id).toBeUndefined();
  });

  it("formattedConfig is always pretty-printed JSON", () => {
    const input = JSON.stringify({ command: "node" });
    const { formattedConfig } = parseSmartMcpJson(input);
    expect(formattedConfig).toBe(JSON.stringify({ command: "node" }, null, 2));
  });
});

/**
 * TDD Tests: utils/providerMetaUtils.ts
 */
import { describe as d2, expect as e2, it as i2 } from "vitest";
import { mergeProviderMeta } from "@/utils/providerMetaUtils";

d2("mergeProviderMeta", () => {
  i2("adds custom_endpoints when customEndpoints is non-empty", () => {
    const result = mergeProviderMeta(undefined, { ep1: { url: "https://ep1.example", addedAt: 123 } });
    e2(result).toBeDefined();
    e2(result!.custom_endpoints).toEqual({ ep1: { url: "https://ep1.example", addedAt: 123 } });
  });

  i2("merges custom_endpoints with existing initialMeta", () => {
    const initial = { usage_script: { url: "https://usage", apiKey: "k" } as any };
    const result = mergeProviderMeta(initial, { ep1: { url: "u", addedAt: 50 } });
    e2(result!.usage_script).toBeDefined();
    e2(result!.custom_endpoints).toBeDefined();
  });

  i2("clears custom_endpoints when passed empty object {}", () => {
    const initial = { custom_endpoints: { ep1: { url: "u", addedAt: 123 } } };
    const result = mergeProviderMeta(initial as any, {});
    e2(result).toBeDefined();
    e2("custom_endpoints" in (result ?? {})).toBe(false);
  });

  i2("returns undefined (no modification) when customEndpoints is null/undefined and no initialMeta", () => {
    e2(mergeProviderMeta(undefined, null)).toBeUndefined();
    e2(mergeProviderMeta(undefined, undefined)).toBeUndefined();
  });

  i2("returns clone of initialMeta unchanged when customEndpoints is null", () => {
    const initial = { usage_script: { url: "u", apiKey: "k" } as any };
    const result = mergeProviderMeta(initial, null);
    // custom_endpoints was not in initial, so still not there
    e2("custom_endpoints" in (result ?? {})).toBe(false);
    e2(result!.usage_script).toBeDefined();
  });

  i2("returns {} (not undefined) when initialMeta had only custom_endpoints and we clear it", () => {
    const initial = { custom_endpoints: { ep1: { url: "u", latencyMs: null } } };
    const result = mergeProviderMeta(initial as any, {});
    // should be empty object, not undefined – signals backend to clear
    e2(result).toEqual({});
  });
});
