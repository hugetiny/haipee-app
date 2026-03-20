import { createRef } from "react";
import { render, screen, waitFor, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, expect, it, vi, beforeEach } from "vitest";

import UnifiedSkillsPanel, {
  type UnifiedSkillsPanelHandle,
} from "@/components/skills/UnifiedSkillsPanel";

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
}

const scanUnmanagedMock = vi.fn();
const toggleSkillAppMock = vi.fn();
const uninstallSkillMock = vi.fn();
const importSkillsMock = vi.fn();
const installFromZipMock = vi.fn();

vi.mock("sonner", () => ({
  toast: {
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
  },
}));

vi.mock("@/hooks/useSkills", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/hooks/useSkills")>();
  return {
    ...actual,
    useInstalledSkills: () => ({
      data: [],
      isLoading: false,
    }),
    useToggleSkillApp: () => ({
      mutateAsync: toggleSkillAppMock,
    }),
    useUninstallSkill: () => ({
      mutateAsync: uninstallSkillMock,
    }),
    useScanUnmanagedSkills: () => ({
      data: [
        {
          directory: "shared-skill",
          name: "Shared Skill",
          description: "Imported from Claude",
          foundIn: ["claude"],
          path: "/tmp/shared-skill",
        },
      ],
      refetch: scanUnmanagedMock,
    }),
    useImportSkillsFromApps: () => ({
      mutateAsync: importSkillsMock,
    }),
    useInstallSkillsFromZip: () => ({
      mutateAsync: installFromZipMock,
    }),
  };
});

describe("UnifiedSkillsPanel", () => {
  beforeEach(() => {
    scanUnmanagedMock.mockResolvedValue({
      data: [
        {
          directory: "shared-skill",
          name: "Shared Skill",
          description: "Imported from Claude",
          foundIn: ["claude"],
          path: "/tmp/shared-skill",
        },
      ],
    });
    toggleSkillAppMock.mockReset();
    uninstallSkillMock.mockReset();
    importSkillsMock.mockReset();
    installFromZipMock.mockReset();
  });

  it("opens the import dialog without crashing when app toggles render", async () => {
    const ref = createRef<UnifiedSkillsPanelHandle>();

    render(
      <QueryClientProvider client={createTestQueryClient()}>
        <UnifiedSkillsPanel
          ref={ref}
          onOpenDiscovery={() => {}}
          currentApp="claude"
        />
      </QueryClientProvider>,
    );

    await act(async () => {
      await ref.current?.openImport();
    });

    await waitFor(() => {
      expect(screen.getByText("skills.import")).toBeInTheDocument();
      expect(screen.getByText("Shared Skill")).toBeInTheDocument();
      expect(screen.getByText("/tmp/shared-skill")).toBeInTheDocument();
    });
  });
});
