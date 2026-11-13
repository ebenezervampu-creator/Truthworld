/**
 * ⚡ TRUTHWORLD P95 & P99 LATENCY BENCHMARK & SLA ENFORCEMENT SUITE
 *
 * Measures high-resolution latencies (via process.hrtime.bigint()) across TruthWorld's
 * core computational and high-throughput backend services.
 *
 * Verifies that:
 * 1. Feed Ranking & Ingestion Scoring: P95 <= 0.50ms, P99 <= 1.00ms
 * 2. Sliding-Window Event Rate Limiter: P95 <= 0.05ms, P99 <= 0.20ms
 * 3. FCM Token Batching & Chunking: P95 <= 0.05ms, P99 <= 0.15ms
 * 4. Watch Time Heartbeat Aggregation: P95 <= 0.05ms, P99 <= 0.15ms
 * 5. Dynamic SEO Route Matching: P95 <= 0.05ms, P99 <= 0.10ms
 * 6. Search Tokenizer & Relevance Scoring: P95 <= 0.10ms, P99 <= 0.30ms
 * 7. Distributed Counter Shard Aggregation: P95 <= 0.05ms, P99 <= 0.15ms
 * 8. L1 Feed Memory Cache Lookup & Eviction SLA: P95 <= 0.50ms, P99 <= 1.00ms
 * 9. L1 Full In-Process Serving Pipeline (Lookup + JSON + ETag): P95 <= 1.00ms, P99 <= 2.00ms
 */

import * as crypto from "crypto";
process.env.NODE_ENV = "test";
import { DualBoundedLruCache } from "../shared/memory-cache";
import { isWeakETagMatch } from "../feed/publicFeedServer";

interface LatencyStats {
  suiteName: string;
  samples: number;
  minMs: number;
  meanMs: number;
  p50Ms: number;
  p90Ms: number;
  p95Ms: number;
  p99Ms: number;
  p999Ms: number;
  maxMs: number;
  p95BudgetMs: number;
  p99BudgetMs: number;
  p95Pass: boolean;
  p99Pass: boolean;
  opsPerSec: number;
}

function computePercentiles(
  suiteName: string,
  durationsMs: number[],
  p95BudgetMs: number,
  p99BudgetMs: number
): LatencyStats {
  const sorted = [...durationsMs].sort((a, b) => a - b);
  const n = sorted.length;
  const sum = sorted.reduce((acc, val) => acc + val, 0);

  const minMs = sorted[0];
  const maxMs = sorted[n - 1];
  const meanMs = sum / n;
  const p50Ms = sorted[Math.floor(n * 0.50)];
  const p90Ms = sorted[Math.floor(n * 0.90)];
  const p95Ms = sorted[Math.floor(n * 0.95)];
  const p99Ms = sorted[Math.floor(n * 0.99)];
  const p999Ms = sorted[Math.floor(n * 0.999)];
  const opsPerSec = sum > 0 ? Math.round((n / sum) * 1000) : 0;

  return {
    suiteName,
    samples: n,
    minMs,
    meanMs,
    p50Ms,
    p90Ms,
    p95Ms,
    p99Ms,
    p999Ms,
    maxMs,
    p95BudgetMs,
    p99BudgetMs,
    p95Pass: p95Ms <= p95BudgetMs,
    p99Pass: p99Ms <= p99BudgetMs,
    opsPerSec,
  };
}

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition: boolean, description: string) {
  totalTests++;
  if (condition) {
    console.log(`  ✅ PASS: ${description}`);
    passedTests++;
  } else {
    console.error(`  ❌ FAIL: ${description}`);
    failedTests++;
  }
}

// ---------------------------------------------------------------------------
// 1. Feed Ranking & Ingestion Scoring
// ---------------------------------------------------------------------------
function benchmarkFeedRanking(): LatencyStats {
  interface CandidateVideo {
    id: string;
    views: number;
    likes: number;
    createdAtMs: number;
    truthScore: number;
    credibilityVerified: boolean;
  }

  const now = Date.now();
  const pool: CandidateVideo[] = Array.from({ length: 1000 }, (_, i) => ({
    id: `vid_${i}`,
    views: Math.floor(Math.random() * 50000),
    likes: Math.floor(Math.random() * 5000),
    createdAtMs: now - (i * 3600000), // past 1000 hours
    truthScore: 50 + (i % 50),
    credibilityVerified: i % 2 === 0,
  }));

  function scoreVideo(v: CandidateVideo, refTime: number): number {
    const ageHours = Math.max(1, (refTime - v.createdAtMs) / 3600000);
    const recencyWeight = 1 / Math.pow(ageHours, 0.4);
    const engagement = Math.log10(v.views + 1) * 10 + Math.log10(v.likes + 1) * 5;
    const truthMultiplier = v.credibilityVerified ? (v.truthScore / 100) * 1.5 : 1.0;
    return (engagement * recencyWeight) * truthMultiplier;
  }

  const iterations = 10000;
  const durations: number[] = new Array(iterations);

  // Warmup
  for (let i = 0; i < 500; i++) scoreVideo(pool[i % 1000], now);

  for (let i = 0; i < iterations; i++) {
    const sample = pool[i % 1000];
    const t0 = process.hrtime.bigint();
    scoreVideo(sample, now);
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("Feed Ranking & Ingestion Scoring", durations, 0.50, 1.00);
}

// ---------------------------------------------------------------------------
// 2. Sliding-Window Event Rate Limiter
// ---------------------------------------------------------------------------
function benchmarkChatRateLimiter(): LatencyStats {
  class SlidingWindowRateLimiter {
    private readonly windowMs: number;
    private readonly maxRequests: number;
    private readonly userTimestamps: Map<string, number[]> = new Map();

    constructor(windowMs = 5000, maxRequests = 5) {
      this.windowMs = windowMs;
      this.maxRequests = maxRequests;
    }

    public isAllowed(userId: string, nowMs: number): boolean {
      let timestamps = this.userTimestamps.get(userId);
      if (!timestamps) {
        timestamps = [];
        this.userTimestamps.set(userId, timestamps);
      }
      const threshold = nowMs - this.windowMs;
      let validIndex = 0;
      while (validIndex < timestamps.length && timestamps[validIndex] <= threshold) {
        validIndex++;
      }
      if (validIndex > 0) timestamps.splice(0, validIndex);

      if (timestamps.length < this.maxRequests) {
        timestamps.push(nowMs);
        return true;
      }
      return false;
    }
  }

  const limiter = new SlidingWindowRateLimiter(5000, 5);
  const now = 1700000000000;
  const iterations = 50000;
  const durations: number[] = new Array(iterations);

  // Warmup
  for (let i = 0; i < 500; i++) limiter.isAllowed(`warm_${i % 100}`, now + i);

  for (let i = 0; i < iterations; i++) {
    const userId = `user_${i % 2500}`;
    const timestamp = now + (i % 6000);
    const t0 = process.hrtime.bigint();
    limiter.isAllowed(userId, timestamp);
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("Event Rate Limiter (50k events)", durations, 0.05, 0.20);
}

// ---------------------------------------------------------------------------
// 3. FCM Notification Token Batching
// ---------------------------------------------------------------------------
function benchmarkFcmBatching(): LatencyStats {
  function chunkTokens(tokens: string[], chunkSize = 500): string[][] {
    const chunks: string[][] = [];
    for (let i = 0; i < tokens.length; i += chunkSize) {
      chunks.push(tokens.slice(i, i + chunkSize));
    }
    return chunks;
  }

  const tokens = Array.from({ length: 500 }, (_, i) => `fcm_token_${i}_${Math.random().toString(36).substring(2, 8)}`);
  const iterations = 10000;
  const durations: number[] = new Array(iterations);

  // Warmup
  for (let i = 0; i < 500; i++) chunkTokens(tokens);

  for (let i = 0; i < iterations; i++) {
    const t0 = process.hrtime.bigint();
    chunkTokens(tokens);
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("FCM Multicast Batch Partitioning", durations, 0.05, 0.15);
}

// ---------------------------------------------------------------------------
// 4. Watch Time Heartbeat Aggregation
// ---------------------------------------------------------------------------
function benchmarkWatchTimeAggregation(): LatencyStats {
  interface VideoMetrics {
    totalSeconds: number;
    heartbeats: number;
    uniqueViewers: Set<string>;
  }

  const metricsMap = new Map<string, VideoMetrics>();
  const iterations = 20000;
  const durations: number[] = new Array(iterations);

  function processPulse(videoId: string, viewerId: string, pulseSeconds: number) {
    let m = metricsMap.get(videoId);
    if (!m) {
      m = { totalSeconds: 0, heartbeats: 0, uniqueViewers: new Set() };
      metricsMap.set(videoId, m);
    }
    m.totalSeconds += pulseSeconds;
    m.heartbeats += 1;
    m.uniqueViewers.add(viewerId);
  }

  // Warmup
  for (let i = 0; i < 500; i++) processPulse(`vid_${i % 100}`, `usr_${i % 500}`, 15);

  for (let i = 0; i < iterations; i++) {
    const vid = `vid_${i % 500}`;
    const usr = `usr_${i % 2500}`;
    const t0 = process.hrtime.bigint();
    processPulse(vid, usr, 15);
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("Watch Time Heartbeat Stream Aggregator", durations, 0.05, 0.15);
}

// ---------------------------------------------------------------------------
// 5. Dynamic SEO Route Pattern Matcher
// ---------------------------------------------------------------------------
function benchmarkSeoRouteMatcher(): LatencyStats {
  const routes = [
    { pattern: /^\/v\/([a-zA-Z0-9_-]+)$/, type: "video" },
    { pattern: /^\/shorts\/([a-zA-Z0-9_-]+)$/, type: "shorts" },
    { pattern: /^\/@([a-zA-Z0-9_.-]+)$/, type: "channel" },
    { pattern: /^\/T\/([a-zA-Z0-9_-]+)$/, type: "topic" },
    { pattern: /^\/embed\/([a-zA-Z0-9_-]+)$/, type: "embed" },
    { pattern: /^\/post\/([a-zA-Z0-9_-]+)$/, type: "community_post" },
  ];

  function matchRoute(path: string): string {
    for (let r = 0; r < routes.length; r++) {
      if (routes[r].pattern.test(path)) return routes[r].type;
    }
    return "spa_fallback";
  }

  const testPaths = [
    "/v/dQw4w9WgXcQ",
    "/shorts/short_123456",
    "/@ebenezer_vampu",
    "/T/geopolitics_truth",
    "/embed/emb_789012",
    "/post/post_345678",
    "/unknown/page/path",
  ];

  const iterations = 20000;
  const durations: number[] = new Array(iterations);

  // Warmup
  for (let i = 0; i < 500; i++) matchRoute(testPaths[i % testPaths.length]);

  for (let i = 0; i < iterations; i++) {
    const path = testPaths[i % testPaths.length];
    const t0 = process.hrtime.bigint();
    matchRoute(path);
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("Dynamic SEO Route Pattern Matcher", durations, 0.05, 0.10);
}

// ---------------------------------------------------------------------------
// 6. In-House Search Query Tokenization & Relevance Scoring
// ---------------------------------------------------------------------------
function benchmarkSearchScorer(): LatencyStats {
  function tokenizeAndScore(query: string, candidateTitle: string, candidateTags: string[]): number {
    const sanitized = query.toLowerCase().replace(/[^a-z0-9\s]/g, "").trim();
    const tokens = sanitized.split(/\s+/).filter(Boolean);
    if (tokens.length === 0) return 0;

    let score = 0;
    const lowerTitle = candidateTitle.toLowerCase();
    for (const token of tokens) {
      if (lowerTitle.includes(token)) score += 10;
      for (const tag of candidateTags) {
        if (tag.toLowerCase() === token) score += 5;
      }
    }
    return score;
  }

  const sampleTitles = [
    "AI-Powered Fact Checking and Autonomous Deepfake Analysis",
    "Global Geopolitics and Verified Economic Perspectives",
    "TruthWorld Engine: Multi-Lingual Speech Synthesis at Scale",
    "Epistemic Integrity in Modern Digital Journalism",
  ];
  const sampleTags = ["ai", "factcheck", "truthworld", "journalism", "geopolitics", "economy"];
  const queries = ["ai fact checking", "truthworld engine", "geopolitics deepfake", "journalism truth"];

  const iterations = 10000;
  const durations: number[] = new Array(iterations);

  // Warmup
  for (let i = 0; i < 500; i++) {
    tokenizeAndScore(queries[i % queries.length], sampleTitles[i % sampleTitles.length], sampleTags);
  }

  for (let i = 0; i < iterations; i++) {
    const q = queries[i % queries.length];
    const title = sampleTitles[i % sampleTitles.length];
    const t0 = process.hrtime.bigint();
    tokenizeAndScore(q, title, sampleTags);
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("Search Tokenizer & Relevance Scorer", durations, 0.10, 0.30);
}

// ---------------------------------------------------------------------------
// 7. Distributed Counter Shard Aggregation
// ---------------------------------------------------------------------------
function benchmarkDistributedCounterSharding(): LatencyStats {
  const NUM_SHARDS = 10;
  const shards = new Array(NUM_SHARDS).fill(0);

  function incrementCounter(): void {
    const shardIndex = Math.floor(Math.random() * NUM_SHARDS);
    shards[shardIndex] += 1;
  }

  function readTotalCount(): number {
    let total = 0;
    for (let i = 0; i < NUM_SHARDS; i++) total += shards[i];
    return total;
  }

  const iterations = 10000;
  const durations: number[] = new Array(iterations);

  // Warmup
  for (let i = 0; i < 500; i++) {
    incrementCounter();
    readTotalCount();
  }

  for (let i = 0; i < iterations; i++) {
    const t0 = process.hrtime.bigint();
    incrementCounter();
    readTotalCount();
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("Distributed Counter Shard Aggregation", durations, 0.05, 0.15);
}

// ---------------------------------------------------------------------------
// 8. L1 Feed Memory Cache Lookup & Eviction SLA
// ---------------------------------------------------------------------------
function benchmarkL1FeedCache(): LatencyStats {
  const cache = new DualBoundedLruCache({
    maxEntries: 150,
    maxTotalBytes: 16 * 1024 * 1024,
    maxEntryBytes: 256 * 1024,
    defaultTtlSeconds: 60,
  });

  const sampleFeedPayload = {
    feed: Array.from({ length: 24 }, (_, i) => ({
      id: `vid_benchmark_${i}`,
      title: `TruthWorld Video Benchmark Headline ${i}`,
      videoUrl: `https://storage.googleapis.com/truthworld/videos/vid_${i}.mp4`,
      thumbnailUrl: `https://storage.googleapis.com/truthworld/thumbs/vid_${i}.jpg`,
      views: 1250 + i * 50,
      likes: 420 + i * 10,
      createdAt: Date.now() - i * 3600000,
    })),
    count: 24,
    hasMore: true,
    category: "all",
    lang: "all",
  };

  // Pre-seed 50 cache entries
  for (let c = 0; c < 50; c++) {
    cache.set(`edge_feed_home_cat_${c % 10}_lang_en_24_p1`, sampleFeedPayload, 60);
  }

  const iterations = 10000;
  const durations: number[] = new Array(iterations);

  // Warmup
  for (let i = 0; i < 500; i++) {
    cache.get(`edge_feed_home_cat_${i % 10}_lang_en_24_p1`);
  }

  for (let i = 0; i < iterations; i++) {
    const key = `edge_feed_home_cat_${i % 10}_lang_en_24_p1`;
    const t0 = process.hrtime.bigint();
    cache.get(key);
    const t1 = process.hrtime.bigint();
    durations[i] = Number(t1 - t0) / 1_000_000;
  }

  return computePercentiles("L1 Feed Memory Cache Lookup", durations, 0.50, 1.00);
}

// ---------------------------------------------------------------------------
// 9. L1 Full In-Process Serving Pipeline (Lookup + Serialization + ETag + 304)
// ---------------------------------------------------------------------------
function benchmarkL1FullPipeline(): LatencyStats {
  const cache = new DualBoundedLruCache({
    maxEntries: 150,
    maxTotalBytes: 16 * 1024 * 1024,
    maxEntryBytes: 256 * 1024,
    defaultTtlSeconds: 60,
  });

  const sampleFeedPayload = {
    feed: Array.from({ length: 24 }, (_, i) => ({
      id: `vid_pipeline_${i}`,
      title: `TruthWorld Comprehensive Benchmark Video Item ${i}`,
      videoUrl: `https://storage.googleapis.com/truthworld/videos/vid_${i}.mp4`,
      thumbnailUrl: `https://storage.googleapis.com/truthworld/thumbs/vid_${i}.jpg`,
      views: 2400 + i * 80,
      likes: 850 + i * 20,
      createdAt: Date.now() - i * 3600000,
      category: "science",
      lang: "en",
    })),
    count: 24,
    hasMore: true,
    category: "science",
    lang: "en",
    cachedAt: new Date().toISOString(),
    edgeServed: true,
  };

  // Seed cache
  for (let c = 0; c < 20; c++) {
    cache.set(`edge_feed_home_cat_${c % 5}_lang_en_24_p1`, sampleFeedPayload, 60);
  }

  // Pre-compute an ETag for simulating conditional 304 requests
  const sampleJson = JSON.stringify(sampleFeedPayload);
  const sampleETag = 'W/"' + crypto.createHash("sha256").update(sampleJson).digest("hex").substring(0, 24) + '"';

  const batches = 5;
  const iterationsPerBatch = 2000;
  const totalIterations = batches * iterationsPerBatch;
  const durations: number[] = new Array(totalIterations);

  let durationIndex = 0;

  // Warmup
  for (let w = 0; w < 500; w++) {
    const cached = cache.get(`edge_feed_home_cat_0_lang_en_24_p1`);
    if (cached) {
      const s = JSON.stringify(cached);
      crypto.createHash("sha256").update(s).digest("hex");
    }
  }

  for (let b = 0; b < batches; b++) {
    for (let i = 0; i < iterationsPerBatch; i++) {
      const key = `edge_feed_home_cat_${i % 5}_lang_en_24_p1`;
      const clientETag = i % 2 === 0 ? sampleETag : 'W/"different_etag"';

      const t0 = process.hrtime.bigint();

      // 1. In-process cache retrieval & recency touch
      let cached = cache.get<typeof sampleFeedPayload>(key);
      if (!cached) {
        cache.set(key, sampleFeedPayload, 60);
        cached = sampleFeedPayload;
      }

      // 2. Response serialization
      const serialized = JSON.stringify(cached);

      // 3. RFC 9110 SHA-256 ETag generation
      const computedETag =
        'W/"' + crypto.createHash("sha256").update(serialized).digest("hex").substring(0, 24) + '"';

      // 4. Weak comparison conditional 304 evaluation
      const is304 = isWeakETagMatch(clientETag, computedETag);
      if (is304 && !computedETag) {
        throw new Error("Invalid ETag state");
      }

      const t1 = process.hrtime.bigint();
      durations[durationIndex++] = Number(t1 - t0) / 1_000_000;
    }
  }

  return computePercentiles("L1 Full In-Process Pipeline (Lookup+ETag)", durations, 1.00, 2.00);
}

// ---------------------------------------------------------------------------
// Main Runner & Formatted Summary Report
// ---------------------------------------------------------------------------
function main() {
  console.log("\n=========================================================================================");
  console.log("⚡ TRUTHWORLD P95 & P99 HIGH-PRECISION LATENCY BENCHMARK & SLA ENFORCEMENT SUITE");
  console.log("=========================================================================================\n");

  const suites: LatencyStats[] = [
    benchmarkFeedRanking(),
    benchmarkChatRateLimiter(),
    benchmarkFcmBatching(),
    benchmarkWatchTimeAggregation(),
    benchmarkSeoRouteMatcher(),
    benchmarkSearchScorer(),
    benchmarkDistributedCounterSharding(),
    benchmarkL1FeedCache(),
    benchmarkL1FullPipeline(),
  ];

  console.log("Latency Results Summary (in milliseconds):");
  console.log("--------------------------------------------------------------------------------------------------------------------------------");
  console.log(
    "Suite Name".padEnd(44) +
    "Samples".padEnd(9) +
    "Min".padEnd(9) +
    "Mean".padEnd(9) +
    "P50".padEnd(9) +
    "P90".padEnd(9) +
    "P95".padEnd(9) +
    "P99".padEnd(9) +
    "Max".padEnd(9) +
    "Throughput".padStart(13)
  );
  console.log("--------------------------------------------------------------------------------------------------------------------------------");

  for (const s of suites) {
    console.log(
      s.suiteName.padEnd(44) +
      String(s.samples).padEnd(9) +
      s.minMs.toFixed(4).padEnd(9) +
      s.meanMs.toFixed(4).padEnd(9) +
      s.p50Ms.toFixed(4).padEnd(9) +
      s.p90Ms.toFixed(4).padEnd(9) +
      s.p95Ms.toFixed(4).padEnd(9) +
      s.p99Ms.toFixed(4).padEnd(9) +
      s.maxMs.toFixed(4).padEnd(9) +
      `${s.opsPerSec.toLocaleString()} ops/s`.padStart(13)
    );
  }
  console.log("--------------------------------------------------------------------------------------------------------------------------------\n");

  console.log("--- P95 & P99 SLA Enforcement Checks ---");
  for (const s of suites) {
    assert(
      s.p95Pass,
      `[${s.suiteName}] P95 latency (${s.p95Ms.toFixed(4)} ms) within budget <= ${s.p95BudgetMs.toFixed(2)} ms`
    );
    assert(
      s.p99Pass,
      `[${s.suiteName}] P99 latency (${s.p99Ms.toFixed(4)} ms) within budget <= ${s.p99BudgetMs.toFixed(2)} ms`
    );
  }

  console.log("\n=========================================================================================");
  console.log(`TOTAL LATENCY SLA VERIFICATIONS: ${passedTests} PASSED, ${failedTests} FAILED out of ${totalTests}`);
  console.log("=========================================================================================\n");

  if (failedTests > 0) {
    process.exit(1);
  }
}

main();
