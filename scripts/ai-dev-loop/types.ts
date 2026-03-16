/**
 * AI Development Loop - Type Definitions
 */

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
  };

  pendingFailures: TestFailure[];
  resolvedFailures: ResolvedFailure[];
  skippedFailures: SkippedFailure[];

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
  name: 'unit' | 'rust' | 'integration' | 'e2e';
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
