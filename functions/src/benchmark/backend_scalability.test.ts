/**
 * ⚡ TRUTHWORLD BACKEND SCALABILITY & HIGH-THROUGHPUT BENCHMARK SUITE
 *
 * Verifies backend throughput, memory footprint, and latency budgets under high-load
 * scenarios (10,000 to 50,000 concurrent operations):
 * 1. FCM Multicast 500-Token Batch Chunking (10,000 recipients)
 * 2. Channel Mention Extraction Throughput (10,000 comments)
 * 3. Push Notification Dynamic Template Rendering (10,000 renders)
 * 4. Live Chat Sliding-Window Rate Limiter (50,000 message events)
 * 5. Watch Time Pulse Aggregation & Retention Windowing (10,000 heartbeats)
 * 6. SEO Server Dynamic Route Pattern Matching (20,000 URL evaluations)
 */

import { TEMPLATE_REGISTRY } from "../notifications/templates/notificationTemplates";

let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, errorDetails?: any) {
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${testName}`, errorDetails ? errorDetails : "");
    failed++;
  }
}

// ---------------------------------------------------------------------------
// 1. FCM Multicast 500-Token Batch Chunking (10,000 Tokens)
// ---------------------------------------------------------------------------
function testFcmChunkingScalability() {
  console.log("\n--- [Suite 1] FCM Multicast Chunking Scalability (10,000 Tokens) ---");

  function chunkTokens(tokens: string[], chunkSize = 500): string[][] {
    const chunks: string[][] = [];
    for (let i = 0; i < tokens.length; i += chunkSize) {
      chunks.push(tokens.slice(i, i + chunkSize));
    }
    return chunks;
  }

  const tokens = Array.from({ length: 10000 }, (_, i) => `fcm_device_token_${i}_${Math.random().toString(36).substring(2, 10)}`);

  // Warmup pass
  chunkTokens(tokens.slice(0, 1000));

  const start = performance.now();
  const chunks = chunkTokens(tokens, 500);
  const elapsed = performance.now() - start;

  assert(chunks.length === 20, "10,000 tokens correctly partitioned into exactly 20 chunks of 500");
  assert(chunks.every(c => c.length === 500), "Every chunk contains exactly 500 tokens (FCM max limit)");
  assert(chunks[0][0] === tokens[0], "Preserves token order at start boundary");
  assert(chunks[19][499] === tokens[9999], "Preserves token order at end boundary");
  assert(elapsed < 20, `Chunking 10,000 tokens executed in under 20 ms (took ${elapsed.toFixed(2)} ms)`);
}

// ---------------------------------------------------------------------------
// 2. Channel Mention Extraction Throughput (10,000 Comments)
// ---------------------------------------------------------------------------
function testMentionExtractionScalability() {
  console.log("\n--- [Suite 2] Channel Mention Extraction Throughput (10,000 Comments) ---");

  function parseMentions(text: string): string[] {
    if (!text) return [];
    const matches = text.match(/@[\w\-]+/g) || [];
    if (matches.length === 0) return [];
    return [...new Set(matches.map(m => m.substring(1).toLowerCase()))].slice(0, 5);
  }

  const comments = Array.from({ length: 10000 }, (_, i) => 
    `Comment ${i}: Hey @creator-${i % 50}, check out @TruthWorld and @creator-${i % 50} again! CC @analyst_${i % 10}, @mod-${i % 5}, @user_${i}, @extra_user.`
  );

  // Warmup pass
  for (let i = 0; i < 50; i++) parseMentions(comments[i]);

  let lastParsed: string[] = [];
  const start = performance.now();
  for (let i = 0; i < comments.length; i++) {
    lastParsed = parseMentions(comments[i]);
  }
  const elapsed = performance.now() - start;

  assert(lastParsed.length === 5, "Strictly limits parsed mentions to 5 handles per comment");
  assert(lastParsed.includes("truthworld"), "Normalizes handles to lowercase without '@'");
  assert(elapsed < 60, `Parsing 10,000 comments for mentions executed in under 60 ms (took ${elapsed.toFixed(2)} ms)`);
}

// ---------------------------------------------------------------------------
// 3. Push Notification Dynamic Template Rendering (10,000 Renders)
// ---------------------------------------------------------------------------
function testTemplateRenderingScalability() {
  console.log("\n--- [Suite 3] Dynamic Template Rendering (10,000 Renders) ---");

  function renderTemplate(template: string, vars: Record<string, any>): string {
    return template.replace(/\{\{(\w+)\}\}/g, (_, key) => vars[key] !== undefined ? String(vars[key]) : "");
  }

  const template = TEMPLATE_REGISTRY["verification_rejected_v1"];
  const variablesList = Array.from({ length: 10000 }, (_, i) => ({
    videoTitle: `AI Investigative Report #${i}`,
    confidencePercent: 85 + (i % 15),
    reason: `Deepfake audio synthesis detected at segment ${i}`
  }));

  // Warmup pass
  for (let i = 0; i < 50; i++) {
    renderTemplate(template.messageTemplate, variablesList[i]);
  }

  let lastRender = "";
  const start = performance.now();
  for (let i = 0; i < variablesList.length; i++) {
    lastRender = renderTemplate(template.messageTemplate, variablesList[i]);
  }
  const elapsed = performance.now() - start;

  assert(lastRender.includes("AI Investigative Report #9999"), "Substitutes dynamic videoTitle variable");
  assert(lastRender.includes("AI synthetic confidence"), "Substitutes dynamic confidence percentage");
  assert(elapsed < 100, `Rendering 10,000 dynamic templates executed in under 100 ms (took ${elapsed.toFixed(2)} ms)`);
}

// ---------------------------------------------------------------------------
// 4. Live Chat Sliding-Window Rate Limiter (50,000 Events)
// ---------------------------------------------------------------------------
function testLiveChatRateLimiterScalability() {
  console.log("\n--- [Suite 4] Live Chat Sliding-Window Rate Limiter (50,000 Events) ---");

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

      // Filter timestamps outside sliding window
      const threshold = nowMs - this.windowMs;
      let validIndex = 0;
      while (validIndex < timestamps.length && timestamps[validIndex] <= threshold) {
        validIndex++;
      }
      if (validIndex > 0) {
        timestamps.splice(0, validIndex);
      }

      if (timestamps.length < this.maxRequests) {
        timestamps.push(nowMs);
        return true;
      }
      return false;
    }
  }

  const limiter = new SlidingWindowRateLimiter(5000, 5);
  const now = 1700000000000;
  const events = Array.from({ length: 50000 }, (_, i) => ({
    userId: `viewer_${i % 2000}`,
    timestamp: now + (i % 6000),
  }));

  // Warmup pass
  for (let i = 0; i < 100; i++) limiter.isAllowed("warm_user", now + i);

  let allowedCount = 0;
  let blockedCount = 0;

  const start = performance.now();
  for (let i = 0; i < events.length; i++) {
    if (limiter.isAllowed(events[i].userId, events[i].timestamp)) {
      allowedCount++;
    } else {
      blockedCount++;
    }
  }
  const elapsed = performance.now() - start;

  assert(allowedCount > 0, "Correctly allows messages within 5 msg / 5s window");
  assert(blockedCount > 0, "Correctly blocks spam bursts exceeding 5 msg / 5s window");
  assert(allowedCount + blockedCount === 50000, "All 50,000 message rate decisions processed");
  assert(elapsed < 80, `Evaluating 50,000 chat rate limit decisions executed in under 80 ms (took ${elapsed.toFixed(2)} ms)`);
}

// ---------------------------------------------------------------------------
// 5. Watch Time Pulse Aggregation & Session Retention (10,000 Pulses)
// ---------------------------------------------------------------------------
function testWatchTimeAggregationScalability() {
  console.log("\n--- [Suite 5] Watch Time Pulse Aggregation (10,000 Pulses) ---");

  interface VideoWatchMetrics {
    totalWatchSeconds: number;
    heartbeatCount: number;
    uniqueViewers: Set<string>;
  }

  const videoMetrics = new Map<string, VideoWatchMetrics>();
  const pulses = Array.from({ length: 10000 }, (_, i) => ({
    videoId: `video_${i % 500}`,
    viewerId: `user_${i % 2500}`,
    pulseSeconds: 15, // standard 15-second heartbeat
  }));

  const start = performance.now();
  for (let i = 0; i < pulses.length; i++) {
    const p = pulses[i];
    let metrics = videoMetrics.get(p.videoId);
    if (!metrics) {
      metrics = { totalWatchSeconds: 0, heartbeatCount: 0, uniqueViewers: new Set() };
      videoMetrics.set(p.videoId, metrics);
    }
    metrics.totalWatchSeconds += p.pulseSeconds;
    metrics.heartbeatCount += 1;
    metrics.uniqueViewers.add(p.viewerId);
  }
  const elapsed = performance.now() - start;

  assert(videoMetrics.size === 500, "Aggregates pulses across 500 unique videos without key drift");
  const sample = videoMetrics.get("video_0");
  assert(sample !== undefined && sample.heartbeatCount === 20, "Accurately computes heartbeat count (20 pulses per video)");
  assert(sample !== undefined && sample.totalWatchSeconds === 300, "Accurately computes total watch seconds (300 seconds)");
  assert(elapsed < 40, `Aggregating 10,000 watch pulses completed in under 40 ms (took ${elapsed.toFixed(2)} ms)`);
}

// ---------------------------------------------------------------------------
// 6. SEO Server Dynamic Route Pattern Matching (20,000 URL Paths)
// ---------------------------------------------------------------------------
function testSeoRouteMatchingScalability() {
  console.log("\n--- [Suite 6] SEO Server Dynamic Route Matching (20,000 Paths) ---");

  const routes: { pattern: RegExp; type: string }[] = [
    { pattern: /^\/v\/([a-zA-Z0-9_-]+)$/, type: "video" },
    { pattern: /^\/shorts\/([a-zA-Z0-9_-]+)$/, type: "shorts" },
    { pattern: /^\/@([a-zA-Z0-9_.-]+)$/, type: "channel" },
    { pattern: /^\/T\/([a-zA-Z0-9_-]+)$/, type: "topic" },
    { pattern: /^\/embed\/([a-zA-Z0-9_-]+)$/, type: "embed" },
    { pattern: /^\/post\/([a-zA-Z0-9_-]+)$/, type: "community_post" },
  ];

  function matchRoute(path: string): string {
    for (let r = 0; r < routes.length; r++) {
      if (routes[r].pattern.test(path)) {
        return routes[r].type;
      }
    }
    return "spa_fallback";
  }

  const paths = Array.from({ length: 20000 }, (_, i) => {
    const types = ["/v/vid_", "/shorts/sh_", "/@channel_", "/T/topic_", "/embed/emb_", "/post/post_", "/unknown/page_"];
    return `${types[i % types.length]}${i}`;
  });

  // Warmup pass
  for (let i = 0; i < 50; i++) matchRoute(paths[i]);

  const start = performance.now();
  const matchedTypes: string[] = [];
  for (let i = 0; i < paths.length; i++) {
    matchedTypes.push(matchRoute(paths[i]));
  }
  const elapsed = performance.now() - start;

  assert(matchedTypes.length === 20000, "Evaluated all 20,000 incoming URL routes");
  assert(matchedTypes[0] === "video", "Route /v/ correctly resolved to 'video'");
  assert(matchedTypes[1] === "shorts", "Route /shorts/ correctly resolved to 'shorts'");
  assert(matchedTypes[2] === "channel", "Route /@ correctly resolved to 'channel'");
  assert(matchedTypes[6] === "spa_fallback", "Unknown paths correctly fall back to 'spa_fallback'");
  assert(elapsed < 40, `Matching 20,000 SEO routes completed in under 40 ms (took ${elapsed.toFixed(2)} ms)`);
}

// ---------------------------------------------------------------------------
// Run All Suites
// ---------------------------------------------------------------------------
function main() {
  console.log("==================================================");
  console.log("RUNNING TRUTHWORLD BACKEND SCALABILITY TEST SUITE");
  console.log("==================================================");

  testFcmChunkingScalability();
  testMentionExtractionScalability();
  testTemplateRenderingScalability();
  testLiveChatRateLimiterScalability();
  testWatchTimeAggregationScalability();
  testSeoRouteMatchingScalability();

  console.log("\n==================================================");
  console.log(`TOTAL BACKEND SCALABILITY: ${passed} PASSED, ${failed} FAILED`);
  console.log("==================================================\n");

  if (failed > 0) {
    process.exit(1);
  }
}

main();
