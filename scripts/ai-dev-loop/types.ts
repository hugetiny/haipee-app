/**
 * AI Development Loop - Type Definitions
 */

// ═══════════════════════════════════════════════════════════════════
// Diagnostic Types
// ═══════════════════════════════════════════════════════════════════

export interface ScreenshotData {
  testName: string;
  path: string;
  timestamp: number;
  baseline?: string;  // Path to baseline screenshot for comparison
  diffScore?: number;  // 0-1 difference score if compared
}

export interface ConsoleEntry {
  level: 'error' | 'warn' | 'info' | 'debug' | 'log';
  message: string;
  timestamp: number;
  source?: string;  // e.g., "react", "tauri-ipc"
  stackTrace?: string;
}

export interface NetworkRequest {
  url: string;
  method: string;
  status?: number;
  statusText?: string;
  duration: number;
  timestamp: number;
  error?: string;
  requestHeaders?: Record<string, string>;
  responseHeaders?: Record<string, string>;
  body?: string;
}

export interface IpcCall {
  command: string;
  args?: Record<string, unknown>;
  result?: unknown;
  error?: string;
  duration: number;
  timestamp: number;
  success: boolean;
}

export interface AppState {
  url: string;
  title: string;
  domSnapshot?: string;
  localStorage?: Record<string, string>;
  sessionStorage?: Record<string, string>;
}

// ═══════════════════════════════════════════════════════════════════
// CrabNebula DevTools Types (TRIAL - remove after 2026-04-01)
// ═══════════════════════════════════════════════════════════════════

export interface CrabNebulaTimelineEvent {
  timestamp: number;
  type: 'ipc' | 'log' | 'performance' | 'window';
  name: string;
  data: Record<string, unknown>;
  duration?: number;
}

export interface CrabNebulaPerformanceSnapshot {
  timestamp: number;
  cpuUsage: number;
  memoryUsageMB: number;
  memoryTotalMB: number;
}

export interface CrabNebulaRustLog {
  timestamp: number;
  level: 'TRACE' | 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
  target: string;
  message: string;
  modulePath?: string;
  file?: string;
  line?: number;
}

export interface CrabNebulaDevToolsData {
  timeline: CrabNebulaTimelineEvent[];
  performanceSnapshots: CrabNebulaPerformanceSnapshot[];
  rustLogs: CrabNebulaRustLog[];
  capturedAt: number;
  connected: boolean;
}

// ═══════════════════════════════════════════════════════════════════
// Fix Strategy Types
// ═══════════════════════════════════════════════════════════════════

export interface FixAttempt {
  failureId: string;
  strategy: string;
  timestamp: number;
  duration: number;
  success: boolean;
  filesModified: string[];
  error?: string;
  diagnostics?: DiagnosticData;
}

export interface FixPattern {
  id: string;
  name: string;
  failureType: FailureType;
  errorPattern: string;  // Regex pattern to match error messages
  solution: string;  // Description of the fix pattern
  filesModified: string[];
  successCount: number;
  failureCount: number;
  lastUsed: number;
  confidence: number;  // 0-1 confidence score
}

export interface FixStrategy {
  name: string;
  priority: number;  // Lower = higher priority
  canHandle: (failure: TestFailure) => boolean;
  execute: (failure: TestFailure, context: FixContext) => Promise<FixResult>;
}

export interface StrategyResult {
  strategy: string;
  result: FixResult;
  duration: number;
  diagnostics?: DiagnosticData;
}

// ═══════════════════════════════════════════════════════════════════
// Diagnostic Collection Types
// ═══════════════════════════════════════════════════════════════════

export interface DiagnosticData {
  screenshots: ScreenshotData[];
  consoleLogs: ConsoleEntry[];
  networkRequests: NetworkRequest[];
  ipcCalls: IpcCall[];
  appState?: AppState;
  crashLog?: string;
  binaryLog?: string;
  collectedAt: number;
  crabnebulaData?: CrabNebulaDevToolsData;  // TRIAL: CrabNebula DevTools - remove after 2026-04-01
}

export interface FixContext {
  failure: TestFailure;
  diagnostics: DiagnosticData;
  history: {
    previousFixAttempts: FixAttempt[];
    similarFailures: TestFailure[];
    successfulFixPatterns: FixPattern[];
  };
  codebase: {
    testFile: string;
    sourceFiles: string[];
    recentChanges: GitDiff[];
    relatedTests: string[];
  };
}

export interface GitDiff {
  filePath: string;
  additions: number;
  deletions: number;
  patch: string;
}

// ═══════════════════════════════════════════════════════════════════
// Validation Types
// ═══════════════════════════════════════════════════════════════════

export interface ValidationResult {
  passed: boolean;
  regressionTests: RegressionResult[];
  relatedTestsPassed: boolean;
  codeQualityScore: number;
  issues: ValidationIssue[];
}

export interface RegressionResult {
  testName: string;
  passed: boolean;
  duration: number;
  error?: string;
}

export interface ValidationIssue {
  severity: 'error' | 'warning' | 'info';
  message: string;
  file?: string;
  line?: number;
}

export interface RetryStrategy {
  maxAttempts: number;
  backoffMs: number;
  strategyChangeAfter: number;  // N 次后切换策略
  contextExpansion: boolean;    // 是否扩展上下文
}

// ═══════════════════════════════════════════════════════════════════
// Checkpoint & Core Types
// ═══════════════════════════════════════════════════════════════════

export interface Checkpoint {
  timestamp: number;
  runId: string;
  gitCommit: string;
  iteration: number;
  startTime: number;
  duration: number;

  testResults: {
    unit: TestLayerResult;
    rust: TestLayerResult;
    integration: TestLayerResult;
    e2e: TestLayerResult;
    tauri_e2e: TestLayerResult;
  };

  pendingFailures: TestFailure[];
  resolvedFailures: ResolvedFailure[];
  skippedFailures: SkippedFailure[];

  // Enhanced: Fix history and patterns
  fixAttempts: FixAttempt[];
  learnedPatterns: FixPattern[];

  stats: RunStats;
}

export interface TestLayerResult {
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
  tests: TestInfo[];
  rawOutput?: string;
}

export interface TestInfo {
  name: string;
  filePath: string;
  duration: number;
  status: 'passed' | 'failed' | 'skipped';
}

export interface TestFailure {
  id: string;
  testName: string;
  filePath: string;
  errorMessage: string;
  stackTrace?: string;
  type: FailureType;
  fixAttempts: number;
  status: 'pending' | 'fixing' | 'fixed' | 'skipped' | 'manual-required';
  firstSeen: number;
  lastAttempt?: number;
  context?: FailureContext;
  // Enhanced: diagnostic data from last failure
  diagnostics?: DiagnosticData;
  // Enhanced: fix history for this specific failure
  fixHistory?: FixAttempt[];
}

export type FailureType =
  | 'assertion-failure'
  | 'runtime-error'
  | 'timeout-error'
  | 'type-error'
  | 'build-error'
  | 'import-error'
  | 'network-error'
  | 'flaky'
  | 'unknown';

export interface FailureContext {
  sourceFiles: string[];
  testFile: string;
  relatedFiles: string[];
  errorLocation?: {
    file: string;
    line: number;
    column: number;
  };
}

export interface ResolvedFailure {
  failureId: string;
  testName: string;
  resolution: 'fixed' | 'skipped' | 'manual-required';
  fixAttempts: number;
  resolvedAt: number;
  fixDescription?: string;
}

export interface SkippedFailure {
  failureId: string;
  testName: string;
  reason: string;
  skippedAt: number;
}

export interface RunStats {
  totalTestsRun: number;
  totalTestsPassed: number;
  totalTestsFailed: number;
  fixesApplied: number;
  fixesFailed: number;
  fixSuccessRate: number;
  averageFixTime: number;
}

export interface LoopConfig {
  maxDurationHours: number;
  checkpointIntervalMinutes: number;
  maxFixAttempts: number;
  dryRun: boolean;
  resumeFrom?: string;
  targetTest?: string;
  layers: TestLayerConfig[];
}

export interface TestLayerConfig {
  name: 'unit' | 'rust' | 'integration' | 'e2e' | 'tauri-e2e';
  command: string;
  timeout: number;
  priority: number;
}

export interface FixResult {
  success: boolean;
  description?: string;
  filesModified: string[];
  error?: string;
}

export interface AgentResult {
  success: boolean;
  output: string;
  filesModified?: string[];
}
