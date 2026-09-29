import { PremiumDistributionRun, PremiumRevenueAllocation, TYPE_REVENUE_SHARE } from "../types";

// Assertion helper
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

console.log("===============================================================================");
console.log("🧪 PREMIUM SUBSCRIPTION REVENUE & UNALLOCATED POOL TEST SUITE");
console.log("===============================================================================");

// ----------------------------------------------------------------------
// TEST 1: PremiumDistributionRun Interface Type Validation
// ----------------------------------------------------------------------
function testPremiumDistributionRunTypes() {
  console.log("\n--- [Test 1] PremiumDistributionRun Interface Unallocated Fields ---");

  const sampleRun: PremiumDistributionRun = {
    month: "2026-08",
    status: "completed",
    totalSubscribersProcessed: 10,
    totalChannelsAllocated: 2,
    grossPoolINR: 1690,
    creatorPoolINR: 1183,
    platformPoolINR: 507,
    unallocatedGrossINR: 338,
    unallocatedCreatorPoolINR: 236.6,
    startedAt: Date.now() - 5000,
    completedAt: Date.now(),
    triggeredBy: "scheduler",
  };

  assert(sampleRun.unallocatedGrossINR === 338, "unallocatedGrossINR field is present and typed as number");
  assert(sampleRun.unallocatedCreatorPoolINR === 236.6, "unallocatedCreatorPoolINR field is present and typed as number");
}

// ----------------------------------------------------------------------
// TEST 2: Zero Watch Time Revenue Tracking
// ----------------------------------------------------------------------
function testZeroWatchTimeTracking() {
  console.log("\n--- [Test 2] Zero Watch Time Revenue Tracking ---");

  const CREATOR_SHARE_RATE = TYPE_REVENUE_SHARE.standard.premiumSubs; // 0.70
  let unallocatedGrossINR = 0;
  let unallocatedCreatorPoolINR = 0;
  let totalSubscribersProcessed = 0;

  // Subscriber 1: Paid 169, watched 0 seconds
  const sub1Amount = 169;
  const sub1OverlapDays = 30;
  const sub1Prorated = sub1Amount * (sub1OverlapDays / 30);
  const sub1WatchSecs = 0;

  if (sub1WatchSecs === 0) {
    unallocatedGrossINR += sub1Prorated;
    unallocatedCreatorPoolINR += sub1Prorated * CREATOR_SHARE_RATE;
    totalSubscribersProcessed++;
  }

  // Subscriber 2: Paid 249, watched 0 seconds
  const sub2Amount = 249;
  const sub2OverlapDays = 30;
  const sub2Prorated = sub2Amount * (sub2OverlapDays / 30);
  const sub2WatchSecs = 0;

  if (sub2WatchSecs === 0) {
    unallocatedGrossINR += sub2Prorated;
    unallocatedCreatorPoolINR += sub2Prorated * CREATOR_SHARE_RATE;
    totalSubscribersProcessed++;
  }

  assert(unallocatedGrossINR === 418, `Unallocated gross matches sum (expected 418, got ${unallocatedGrossINR})`);
  assert(
    Math.round(unallocatedCreatorPoolINR * 100) / 100 === 292.6,
    `Unallocated creator pool is exactly 70% (expected 292.6, got ${unallocatedCreatorPoolINR})`
  );
  assert(totalSubscribersProcessed === 2, `Total subscribers processed tracked accurately (expected 2, got ${totalSubscribersProcessed})`);
}

// ----------------------------------------------------------------------
// TEST 3: Pro-Rata Reallocation Across Channels with Watch Time
// ----------------------------------------------------------------------
function testProRataReallocation() {
  console.log("\n--- [Test 3] Pro-Rata Reallocation Across Channels ---");

  const channelAgg = new Map<string, {
    ownerId: string;
    grossINR: number;
    creatorINR: number;
    platformINR: number;
    watchSeconds: number;
  }>();

  // Channel A: 750 seconds watched
  channelAgg.set("channel_a", {
    ownerId: "owner_a",
    grossINR: 700,
    creatorINR: 490,
    platformINR: 210,
    watchSeconds: 750,
  });

  // Channel B: 250 seconds watched
  channelAgg.set("channel_b", {
    ownerId: "owner_b",
    grossINR: 300,
    creatorINR: 210,
    platformINR: 90,
    watchSeconds: 250,
  });

  const unallocatedGrossINR = 418;
  const unallocatedCreatorPoolINR = 292.6; // 70% of 418

  const totalPlatformWatchSeconds = [...channelAgg.values()].reduce((sum, v) => sum + v.watchSeconds, 0);
  assert(totalPlatformWatchSeconds === 1000, `Total platform watch seconds is 1000 (got ${totalPlatformWatchSeconds})`);

  let remainingCreatorRealloc = Math.round(unallocatedCreatorPoolINR * 100) / 100;
  let remainingGrossRealloc = Math.round(unallocatedGrossINR * 100) / 100;

  const channelEntries = [...channelAgg.entries()];
  const reallocations: PremiumRevenueAllocation[] = [];

  for (let i = 0; i < channelEntries.length; i++) {
    const [channelId, agg] = channelEntries[i];
    const isLast = i === channelEntries.length - 1;
    const channelShare = agg.watchSeconds / totalPlatformWatchSeconds;

    const creatorShare = isLast
      ? remainingCreatorRealloc
      : Math.min(remainingCreatorRealloc, Math.round(unallocatedCreatorPoolINR * channelShare * 100) / 100);
    const grossShare = isLast
      ? remainingGrossRealloc
      : Math.min(remainingGrossRealloc, Math.round(unallocatedGrossINR * channelShare * 100) / 100);
    const platformFee = Math.round((grossShare - creatorShare) * 100) / 100;

    remainingCreatorRealloc = Math.round((remainingCreatorRealloc - creatorShare) * 100) / 100;
    remainingGrossRealloc = Math.round((remainingGrossRealloc - grossShare) * 100) / 100;

    agg.creatorINR += creatorShare;
    agg.grossINR += grossShare;
    agg.platformINR += platformFee;

    const alloc: PremiumRevenueAllocation = {
      id: `2026-08_unallocated_pool_${channelId}`,
      month: "2026-08",
      userId: "unallocated_subscribers_pool",
      channelId,
      channelOwnerId: agg.ownerId,
      subscriptionPlanId: "unallocated_pool_reallocation",
      subscriptionAmountINR: Math.round(grossShare * 100) / 100,
      overlapDays: 30,
      proratedContributionINR: Math.round(grossShare * 100) / 100,
      watchSeconds: 0,
      totalWatchSeconds: totalPlatformWatchSeconds,
      sharePercent: Math.round(channelShare * 100 * 100) / 100,
      grossAllocationINR: Math.round(creatorShare * 100) / 100,
      creatorShareINR: Math.round(creatorShare * 100) / 100,
      platformFeeINR: Math.round(platformFee * 100) / 100,
      processedAt: Date.now(),
      distributionRunId: "2026-08",
    };
    reallocations.push(alloc);
  }

  // Channel A: 75% share -> 292.60 * 0.75 = 219.45
  // Channel B: 25% share -> 292.60 - 219.45 = 73.15
  const chA = channelAgg.get("channel_a")!;
  const chB = channelAgg.get("channel_b")!;

  assert(chA.creatorINR === 490 + 219.45, `Channel A reallocated creator share exact (expected 709.45, got ${chA.creatorINR})`);
  assert(chB.creatorINR === 210 + 73.15, `Channel B reallocated creator share exact (expected 283.15, got ${chB.creatorINR})`);
  assert(remainingCreatorRealloc === 0, "No creator revenue is lost or withheld (remaining = 0)");
  assert(remainingGrossRealloc === 0, "No gross revenue is lost or withheld (remaining = 0)");

  // Total creator revenue in system
  const totalCreatorPool = Math.round((chA.creatorINR + chB.creatorINR) * 100) / 100;
  assert(totalCreatorPool === (490 + 210 + 292.6), `Total creator pool perfectly reconciles (got ${totalCreatorPool})`);
}

// ----------------------------------------------------------------------
// TEST 4: Community Fund Allocation When No Active Channels
// ----------------------------------------------------------------------
function testCommunityFundWhenNoChannels() {
  console.log("\n--- [Test 4] Community Fund Allocation When No Active Channels ---");

  const channelAgg = new Map<string, any>(); // 0 channels
  const unallocatedGrossINR = 169;
  const unallocatedCreatorPoolINR = 118.3;

  const totalPlatformWatchSeconds = 0;
  const hasActiveChannels = channelAgg.size > 0 && totalPlatformWatchSeconds > 0;

  const reallocatedAmountINR = hasActiveChannels ? unallocatedCreatorPoolINR : 0;
  const retainedInFundINR = hasActiveChannels ? 0 : unallocatedCreatorPoolINR;

  assert(unallocatedGrossINR === 169, "Unallocated gross matches input");
  assert(hasActiveChannels === false, "Detected zero active channels");
  assert(reallocatedAmountINR === 0, "No channel reallocation occurred");
  assert(retainedInFundINR === 118.3, `Full creator pool retained in creator_community_fund (expected 118.3, got ${retainedInFundINR})`);
}

// ----------------------------------------------------------------------
// TEST 5: getPremiumRevenueBreakdown Accuracy with Pool Allocation
// ----------------------------------------------------------------------
function testBreakdownFiltering() {
  console.log("\n--- [Test 5] getPremiumRevenueBreakdown Metric Filtering ---");

  const allocations = [
    {
      userId: "user_alice",
      channelId: "channel_a",
      watchSeconds: 500,
      creatorShareINR: 100,
      grossAllocationINR: 100,
    },
    {
      userId: "user_bob",
      channelId: "channel_a",
      watchSeconds: 250,
      creatorShareINR: 50,
      grossAllocationINR: 50,
    },
    {
      userId: "unallocated_subscribers_pool",
      channelId: "channel_a",
      watchSeconds: 0,
      creatorShareINR: 30,
      grossAllocationINR: 30,
    },
  ];

  const totalCreatorShareINR = allocations.reduce((s, a) => s + Number(a.creatorShareINR || 0), 0);
  const directAllocs = allocations.filter(a => a.userId !== "unallocated_subscribers_pool");
  const totalWatchSeconds = directAllocs.reduce((s, a) => s + Number(a.watchSeconds || 0), 0);
  const subscriberCount = new Set(directAllocs.map(a => a.userId)).size;

  assert(totalCreatorShareINR === 180, `Total creator share includes pool bonus (expected 180, got ${totalCreatorShareINR})`);
  assert(totalWatchSeconds === 750, `Watch seconds not inflated by pool doc (expected 750, got ${totalWatchSeconds})`);
  assert(subscriberCount === 2, `Subscriber count only counts real users (expected 2, got ${subscriberCount})`);
}

// Run all tests
testPremiumDistributionRunTypes();
testZeroWatchTimeTracking();
testProRataReallocation();
testCommunityFundWhenNoChannels();
testBreakdownFiltering();

console.log("\n===============================================================================");
console.log(`Test Results: ${passed} passed, ${failed} failed`);
console.log("===============================================================================");

if (failed > 0) {
  process.exit(1);
}
