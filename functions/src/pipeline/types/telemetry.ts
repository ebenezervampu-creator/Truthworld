/**
 * Telemetry types — epistemic telemetry, cost metrics, performance, scaling.
 */

import type { ChannelType } from './pipeline.js';

export interface EpistemicTelemetry {
  claimId: string;
  claimHash: string;
  videoId: string;
  category: string;
  riskLevel: string;
  verificationOutcome: string;
  verificationPath: string;
  latencyMs: number;
  providerUsed: string;
  fallbackUsed: boolean;
  cacheHit: boolean;
  retryCount: number;
  confidenceDelta: number;
  costUsd: number;
  timestamp: number;
}

export interface CacheEntry<T = any> {
  key: string;
  value: T;
  ttl: number;
  createdAt: number;
  hitCount: number;
  source: 'memory' | 'firestore';
}

export interface CostMetrics {
  jobId: string;
  geminiCalls: number;
  geminiTokens: number;
  ttsCalls: number;
  ttsCharacters: number;
  translationCalls: number;
  translationCharacters: number;
  cacheSavings: {
    geminiCallsAvoided: number;
    ttsCallsAvoided: number;
    translationCallsAvoided: number;
  };
  estimatedCostUsd: number;
}

export interface PerformanceConfig {
  maxClaimsPerType: Record<ChannelType, number>;
  cacheEnabled: boolean;
  cacheTTL: Record<string, number>;
  parallelWorkers: number;
  chunkDuration: number;
  priorityQueue: boolean;
}

export interface ScalingConfig {
  serviceName: string;
  minInstances: number;
  maxInstances: number;
  concurrency: number;
  cpu: number;
  memoryMb: number;
  timeoutSeconds: number;
}

export interface WorkerConfig {
  type: 'fact' | 'dubbing' | 'transcription' | 'aggregation';
  instances: number;
  queueName: string;
  deadLetterTopic: string;
  maxRetries: number;
  ackDeadline: number;
}

export interface HealthStatus {
  service: string;
  status: 'healthy' | 'degraded' | 'unhealthy';
  uptime: number;
  activeJobs: number;
  memoryUsage: number;
  lastCheck: number;
}

export interface CDNConfig {
  enabled: boolean;
  bucketName: string;
  cacheTTL: number;
  signedUrlExpiry: number;
  allowedOrigins: string[];
}
