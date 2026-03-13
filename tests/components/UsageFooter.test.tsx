/**
 * UsageFooter Component Tests
 *
 * Tests for the usage display component including:
 * - Loading states
 * - Error handling
 * - Data display (inline and card modes)
 * - Refresh functionality
 * - Expiration status
 */
import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import UsageFooter from "@/components/UsageFooter";
import { Provider, UsageResult, UsageData } from "@/types";

// Mock the useUsageQuery hook
vi.mock("@/lib/query/queries", () => ({
  useUsageQuery: vi.fn(),
}));

import { useUsageQuery } from "@/lib/query/queries";

const mockUseUsageQuery = vi.mocked(useUsageQuery);

// Test helpers
const createMockProvider = (overrides: Partial<Provider> = {}): Provider => ({
  id: "test-provider",
  name: "Test Provider",
  settingsConfig: {},
  ...overrides,
});

const createMockUsageData = (overrides: Partial<UsageData> = {}): UsageData => ({
  planName: "Test Plan",
  total: 1000,
  used: 500,
  remaining: 500,
  unit: "USD",
  ...overrides,
});

const createMockUsageResult = (
  success: boolean,
  data?: UsageData[],
  error?: string
): UsageResult => ({
  success,
  data,
  error,
});

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

const renderWithQueryClient = (component: React.ReactNode) => {
  const queryClient = createTestQueryClient();
  return render(
    <QueryClientProvider client={queryClient}>{component}</QueryClientProvider>
  );
};

describe("UsageFooter", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // ============================================================================
  // Visibility Tests
  // ============================================================================

  describe("visibility", () => {
    it("returns null when usage is disabled", () => {
      mockUseUsageQuery.mockReturnValue({
        data: undefined,
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      const { container } = renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={false}
          isCurrent={true}
        />
      );

      expect(container.firstChild).toBeNull();
    });

    it("returns null when no usage data exists", () => {
      mockUseUsageQuery.mockReturnValue({
        data: undefined,
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      const { container } = renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(container.firstChild).toBeNull();
    });

    it("returns null when usage data list is empty", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, []),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      const { container } = renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(container.firstChild).toBeNull();
    });
  });

  // ============================================================================
  // Error State Tests
  // ============================================================================

  describe("error state", () => {
    it("displays error message in card mode", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(false, undefined, "API Error"),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText("API Error")).toBeInTheDocument();
    });

    it("displays generic error when no error message provided", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(false),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      // Error is displayed with default error message (usage.queryFailed translation)
      expect(screen.getByText(/查询失败|query failed/i)).toBeInTheDocument();
    });

    it("shows refresh button in error state", () => {
      const mockRefetch = vi.fn();
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(false, undefined, "API Error"),
        isFetching: false,
        lastQueriedAt: null,
        refetch: mockRefetch,
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      // Refresh button has title attribute, look by title or just get the button
      const refreshButton = screen.getByTitle(/刷新用量|refresh usage/i);
      expect(refreshButton).toBeInTheDocument();
    });

    it("calls refetch when refresh button clicked in error state", async () => {
      const mockRefetch = vi.fn();
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(false, undefined, "API Error"),
        isFetching: false,
        lastQueriedAt: null,
        refetch: mockRefetch,
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      const refreshButton = screen.getByTitle(/刷新用量|refresh usage/i);
      fireEvent.click(refreshButton);

      await waitFor(() => {
        expect(mockRefetch).toHaveBeenCalled();
      });
    });

    it("displays inline error in inline mode", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(false, undefined, "API Error"),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
          inline={true}
        />
      );

      expect(screen.getByText(/查询失败|query failed/i)).toBeInTheDocument();
    });
  });

  // ============================================================================
  // Success State Tests (Card Mode)
  // ============================================================================

  describe("success state - card mode", () => {
    it("displays plan name", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData()]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText(/Test Plan/i)).toBeInTheDocument();
    });

    it("displays total amount", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData({ total: 1000 })]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText("1000.00")).toBeInTheDocument();
    });

    it("displays used amount", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData({ used: 600, remaining: 400 })]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText("600.00")).toBeInTheDocument();
    });

    it("displays remaining amount", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData({ used: 300, remaining: 700 })]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText("700.00")).toBeInTheDocument();
    });

    it("displays infinity for unlimited (-1) total", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData({ total: -1 })]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText("∞")).toBeInTheDocument();
    });

    it("displays extra information", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData({ extra: "Extra Info" })]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText("Extra Info")).toBeInTheDocument();
    });
  });

  // ============================================================================
  // Success State Tests (Inline Mode)
  // ============================================================================

  describe("success state - inline mode", () => {
    it("displays compact usage info in inline mode", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData()]),
        isFetching: false,
        lastQueriedAt: Date.now(),
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
          inline={true}
        />
      );

      // Inline mode shows both used (500.00) and remaining (500.00)
      const amounts = screen.getAllByText(/500.00/);
      expect(amounts.length).toBeGreaterThanOrEqual(1);
    });

    it("displays last updated time in inline mode", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData()]),
        isFetching: false,
        lastQueriedAt: Date.now(),
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
          inline={true}
        />
      );

      expect(screen.getByText(/just now|刚刚/i)).toBeInTheDocument();
    });
  });

  // ============================================================================
  // Expiration Tests
  // ============================================================================

  describe("expiration status", () => {
    it("shows expired badge when plan is invalid", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [
          createMockUsageData({ isValid: false, invalidMessage: "Expired" }),
        ]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText("Expired")).toBeInTheDocument();
    });

    it("applies red color to expired plan name", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [
          createMockUsageData({ isValid: false, planName: "Expired Plan" }),
        ]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      const planName = screen.getByText(/Expired Plan/i);
      expect(planName).toHaveClass("text-red-500");
    });
  });

  // ============================================================================
  // Loading State Tests
  // ============================================================================

  describe("loading state", () => {
    it("shows loading spinner during refetch", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [createMockUsageData()]),
        isFetching: true,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      const refreshButton = screen.getByTitle(/刷新用量|refresh usage/i);
      expect(refreshButton).toBeDisabled();
    });
  });

  // ============================================================================
  // Multiple Plans Tests
  // ============================================================================

  describe("multiple plans", () => {
    it("renders multiple usage plans", () => {
      mockUseUsageQuery.mockReturnValue({
        data: createMockUsageResult(true, [
          createMockUsageData({ planName: "Plan A" }),
          createMockUsageData({ planName: "Plan B" }),
        ]),
        isFetching: false,
        lastQueriedAt: null,
        refetch: vi.fn(),
      } as any);

      renderWithQueryClient(
        <UsageFooter
          provider={createMockProvider()}
          providerId="test-provider"
          appId="claude"
          usageEnabled={true}
          isCurrent={true}
        />
      );

      expect(screen.getByText(/Plan A/i)).toBeInTheDocument();
      expect(screen.getByText(/Plan B/i)).toBeInTheDocument();
    });
  });
});
