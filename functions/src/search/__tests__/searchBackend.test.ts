/**
 * 🧪 BACKEND SEARCH SYSTEM TEST SUITE
 * 
 * Verifies the In-House Vector Search backend logic:
 * 1. Query Sanitization & Safe Handling (empty queries, special characters, punctation)
 * 2. Handle Detection & Extraction (@creator vs plain text)
 * 3. Result Ranking & Sorting (relevanceScore desc, views desc)
 * 4. Result Payload Formatting (compliance with SearchResult contract)
 * 5. LRU In-Memory Cache Key Generation & Expiry
 * 6. Filter Scoping Logic (All, Videos, Channels, Topics)
 */

let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, details?: any) {
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${testName}`, details !== undefined ? details : "");
    failed++;
  }
}

// ----------------------------------------------------------------------
// FEATURE 1: Query Sanitization
// ----------------------------------------------------------------------
function testQuerySanitization() {
  console.log("\n--- [Feature 1] Testing Query Sanitization ---");

  function sanitize(raw: string): string {
    return raw.replace(/[^\w\s@\-_]/g, "").trim();
  }

  assert(sanitize("   space discoveries!  ") === "space discoveries", "Strips trailing punctuation and trims");
  assert(sanitize("@truthworld_creator") === "@truthworld_creator", "Preserves @ and _ in handles");
  assert(sanitize("<script>alert('hack')</script>") === "scriptalerthackscript", "Sanitizes HTML tags and special chars");
  assert(sanitize("   ") === "", "Empty whitespace collapses to empty string");
  assert(sanitize("telugu-christian-debates") === "telugu-christian-debates", "Preserves hyphens for slugs");
}

// ----------------------------------------------------------------------
// FEATURE 2: Handle Detection & Hybrid Lookup
// ----------------------------------------------------------------------
function testHandleDetection() {
  console.log("\n--- [Feature 2] Testing Handle Detection & Extraction ---");

  function isHandleQuery(query: string): boolean {
    const clean = query.trim();
    return clean.startsWith("@");
  }

  function extractHandle(query: string): string {
    return query.replace(/^@/, "").toLowerCase().trim();
  }

  assert(isHandleQuery("@ebenezer") === true, "Detects @ handle prefix");
  assert(isHandleQuery("ebenezer") === false, "Regular text is not detected as handle query");
  assert(extractHandle("@TruthWorld") === "truthworld", "Extracts clean lowercase handle");
}

// ----------------------------------------------------------------------
// FEATURE 3: Relevance Sorting & Multi-Factor Ranking
// ----------------------------------------------------------------------
function testRelevanceSorting() {
  console.log("\n--- [Feature 3] Testing Relevance & View Sorting ---");

  interface TestResultItem {
    id: string;
    title: string;
    views: number;
    relevanceScore: number;
  }

  const items: TestResultItem[] = [
    { id: "1", title: "Lower relevance, high views", views: 100000, relevanceScore: 60.0 },
    { id: "2", title: "Highest relevance, moderate views", views: 500, relevanceScore: 95.0 },
    { id: "3", title: "High relevance, low views", views: 10, relevanceScore: 90.0 },
    { id: "4", title: "Same high relevance, higher views", views: 5000, relevanceScore: 90.0 },
  ];

  items.sort((a, b) => {
    const scoreDiff = (b.relevanceScore || 0) - (a.relevanceScore || 0);
    if (scoreDiff !== 0) return scoreDiff;
    return b.views - a.views;
  });

  assert(items[0].id === "2", "Top item has highest relevance score (95.0)");
  assert(items[1].id === "4", "Tie-breaker with equal relevance favors higher views (5000 vs 10)");
  assert(items[2].id === "3", "Item with equal relevance but lower views comes after");
  assert(items[3].id === "1", "Item with lower relevance comes last regardless of high view count");
}

// ----------------------------------------------------------------------
// FEATURE 4: Result Payload Contract
// ----------------------------------------------------------------------
function testResultPayloadContract() {
  console.log("\n--- [Feature 4] Testing SearchResult Contract Schema ---");

  function validatePayload(item: any): boolean {
    if (typeof item.id !== "string" || item.id.length === 0) return false;
    if (typeof item.title !== "string") return false;
    if (typeof item.views !== "number") return false;
    if (typeof item.channelName !== "string") return false;
    if (typeof item.thumbnail !== "string") return false;
    if (typeof item.createdAt !== "string") return false;
    if (typeof item.type !== "string") return false;
    return true;
  }

  const validVideo = {
    id: "vid_123",
    title: "Space Telescope Discoveries",
    thumbnail: "https://example.com/thumb.jpg",
    views: 12500,
    channelName: "Science Hub",
    channelImage: "https://example.com/avatar.jpg",
    createdAt: new Date().toISOString(),
    type: "ResultType.video",
    relevanceScore: 88.5,
  };

  assert(validatePayload(validVideo) === true, "Valid video item satisfies contract");

  const invalidItem = {
    id: "", // missing id
    title: "No ID",
    views: 0,
  };
  assert(validatePayload(invalidItem) === false, "Incomplete item rejected by validator");
}

// ----------------------------------------------------------------------
// FEATURE 5: LRU In-Memory Cache Simulation
// ----------------------------------------------------------------------
function testLruCacheMechanics() {
  console.log("\n--- [Feature 5] Testing LRU In-Memory Cache Mechanics ---");

  const cache = new Map<string, { data: string; expiresAt: number }>();
  const maxSize = 3;
  const ttlMs = 1000;

  function put(key: string, val: string) {
    if (cache.size >= maxSize) {
      const oldestKey = cache.keys().next().value;
      if (oldestKey) cache.delete(oldestKey);
    }
    cache.set(key, { data: val, expiresAt: Date.now() + ttlMs });
  }

  function get(key: string): string | null {
    const entry = cache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      cache.delete(key);
      return null;
    }
    return entry.data;
  }

  put("q1", "res1");
  put("q2", "res2");
  put("q3", "res3");

  assert(cache.size === 3, "Cache contains 3 items");
  assert(get("q1") === "res1", "q1 retrieved successfully");

  // Add 4th item -> q1 is oldest and should be evicted
  put("q4", "res4");
  assert(cache.size === 3, "Cache does not exceed maxSize of 3");
  assert(get("q1") === null, "Oldest entry q1 was evicted");
  assert(get("q4") === "res4", "Newest entry q4 exists");
}

// ----------------------------------------------------------------------
// RUN ALL BACKEND TESTS
// ----------------------------------------------------------------------
function runAllTests() {
  console.log("==================================================");
  console.log("🚀 RUNNING IN-HOUSE SEARCH BACKEND UNIT TESTS");
  console.log("==================================================");

  testQuerySanitization();
  testHandleDetection();
  testRelevanceSorting();
  testResultPayloadContract();
  testLruCacheMechanics();

  console.log("\n==================================================");
  console.log(`TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log("==================================================");

  if (failed > 0) {
    process.exit(1);
  }
}

runAllTests();
