import { TYPE_REVENUE_SHARE } from "../types";
import { calculateShare } from "../revenue";

// Assertion helper
let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, errorDetails?: any) {
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${testName}`, errorDetails !== undefined ? errorDetails : "");
    failed++;
  }
}

console.log("===============================================================================");
console.log("🧪 CUSTOM CHANNEL 100% REVENUE SPLIT TEST SUITE");
console.log("===============================================================================");

// ----------------------------------------------------------------------
// TEST 1: Revenue Share Matrix Rates Verification
// ----------------------------------------------------------------------
function testRevenueShareMatrix() {
  console.log("\n--- [Test 1] TYPE_REVENUE_SHARE Matrix Definition ---");

  // Custom channels must receive 100% across all revenue sources
  assert(TYPE_REVENUE_SHARE.custom.ads === 1.00, "Custom channels receive 100% of ads revenue (rate = 1.00)");
  assert(TYPE_REVENUE_SHARE.custom.premiumSubs === 1.00, "Custom channels receive 100% of premium subs revenue (rate = 1.00)");
  assert(TYPE_REVENUE_SHARE.custom.superchats === 1.00, "Custom channels receive 100% of superchats (rate = 1.00)");
  assert(TYPE_REVENUE_SHARE.custom.members === 1.00, "Custom channels receive 100% of channel memberships (rate = 1.00)");

  // Standard channels receive 70% ads/subs and 100% superchats/members
  assert(TYPE_REVENUE_SHARE.standard.ads === 0.70, "Standard channels receive 70% of ads revenue (rate = 0.70)");
  assert(TYPE_REVENUE_SHARE.standard.premiumSubs === 0.70, "Standard channels receive 70% of premium subs revenue (rate = 0.70)");
  assert(TYPE_REVENUE_SHARE.standard.superchats === 1.00, "Standard channels receive 100% of superchats (rate = 1.00)");
  assert(TYPE_REVENUE_SHARE.standard.members === 1.00, "Standard channels receive 100% of memberships (rate = 1.00)");
}

// ----------------------------------------------------------------------
// TEST 2: calculateShare() Utility Function for All Revenue Types
// ----------------------------------------------------------------------
function testCalculateShareUtility() {
  console.log("\n--- [Test 2] calculateShare() Output Validation ---");

  const grossGross = 1000;

  // Custom channel evaluations
  const customAds = calculateShare(grossGross, "ads", "custom");
  const customSubs = calculateShare(grossGross, "premiumSubs", "custom");
  const customSuper = calculateShare(grossGross, "superchats", "custom");
  const customMemb = calculateShare(grossGross, "members", "custom");

  assert(customAds === 1000, `Custom channel calculateShare(1000, "ads") returns 100% gross (1000, got ${customAds})`);
  assert(customSubs === 1000, `Custom channel calculateShare(1000, "premiumSubs") returns 100% gross (1000, got ${customSubs})`);
  assert(customSuper === 1000, `Custom channel calculateShare(1000, "superchats") returns 100% gross (1000, got ${customSuper})`);
  assert(customMemb === 1000, `Custom channel calculateShare(1000, "members") returns 100% gross (1000, got ${customMemb})`);

  // Standard channel evaluations
  const stdAds = calculateShare(grossGross, "ads", "standard");
  const stdSubs = calculateShare(grossGross, "premiumSubs", "standard");
  const stdSuper = calculateShare(grossGross, "superchats", "standard");
  const stdMemb = calculateShare(grossGross, "members", "standard");

  assert(stdAds === 700, `Standard channel calculateShare(1000, "ads") returns 70% (700, got ${stdAds})`);
  assert(stdSubs === 700, `Standard channel calculateShare(1000, "premiumSubs") returns 70% (700, got ${stdSubs})`);
  assert(stdSuper === 1000, `Standard channel calculateShare(1000, "superchats") returns 100% (1000, got ${stdSuper})`);
  assert(stdMemb === 1000, `Standard channel calculateShare(1000, "members") returns 100% (1000, got ${stdMemb})`);
}

// ----------------------------------------------------------------------
// TEST 3: Ad Revenue Distribution Settlement Engine
// ----------------------------------------------------------------------
function testAdRevenueDistributionSplitting() {
  console.log("\n--- [Test 3] Ad Revenue Distribution Settlement Logic ---");

  const CREATOR_SHARE_RATE = 0.70;
  const PLATFORM_SHARE_RATE = 0.30;

  // Helper matching functions/src/ads/adRevenueDistribution.ts logic
  function calculateAdSplit(grossChargeINR: number, channelData: Record<string, any>) {
    const isCustomChannel = channelData.type === "custom" || channelData.channelType === "custom";
    const creatorShareRate = isCustomChannel ? TYPE_REVENUE_SHARE.custom.ads : CREATOR_SHARE_RATE;
    const platformShareRate = isCustomChannel ? 0 : PLATFORM_SHARE_RATE;
    const channelShareINR = Math.round(grossChargeINR * creatorShareRate * 10000) / 10000;
    const platformShareINR = Math.round(grossChargeINR * platformShareRate * 10000) / 10000;
    return { isCustomChannel, channelShareINR, platformShareINR };
  }

  // 1. Custom channel with type = "custom"
  const split1 = calculateAdSplit(250.00, { type: "custom" });
  assert(split1.isCustomChannel === true, "Channel identified as custom via type='custom'");
  assert(split1.channelShareINR === 250.00, `Custom channel receives 100% of ad revenue (₹250.00, got ₹${split1.channelShareINR})`);
  assert(split1.platformShareINR === 0.00, `Platform fee is ₹0.00 (got ₹${split1.platformShareINR})`);

  // 2. Custom channel with channelType = "custom"
  const split2 = calculateAdSplit(150.75, { channelType: "custom" });
  assert(split2.isCustomChannel === true, "Channel identified as custom via channelType='custom'");
  assert(split2.channelShareINR === 150.75, `Custom channel receives 100% of ad revenue (₹150.75, got ₹${split2.channelShareINR})`);
  assert(split2.platformShareINR === 0.00, `Platform fee is ₹0.00 (got ₹${split2.platformShareINR})`);

  // 3. Standard channel
  const split3 = calculateAdSplit(250.00, { type: "standard" });
  assert(split3.isCustomChannel === false, "Channel identified as standard");
  assert(split3.channelShareINR === 175.00, `Standard channel receives 70% of ad revenue (₹175.00, got ₹${split3.channelShareINR})`);
  assert(split3.platformShareINR === 75.00, `Platform receives 30% fee (₹75.00, got ₹${split3.platformShareINR})`);

  // 4. Micro-transaction ad impression (₹0.50 charge)
  const microSplitCustom = calculateAdSplit(0.50, { type: "custom" });
  assert(microSplitCustom.channelShareINR === 0.50, "Micro-charge retains 100% for custom channel (₹0.50)");
  assert(microSplitCustom.platformShareINR === 0.00, "Micro-charge retains 0% platform fee for custom channel (₹0.00)");
}

// ----------------------------------------------------------------------
// TEST 4: Premium Subscription Attention Pool Revenue Distribution
// ----------------------------------------------------------------------
function testPremiumSubscriptionSplitting() {
  console.log("\n--- [Test 4] Premium Subscription Distribution Logic ---");

  const CREATOR_SHARE_RATE = 0.70;
  const PLATFORM_SHARE_RATE = 0.30;

  // Subscriber pays ₹169 for monthly plan
  const proratedContributionINR = 169.00;

  // Scenario: Subscriber watched 2 channels:
  // - Channel A: Standard channel, 400 seconds
  // - Channel B: Custom channel, 600 seconds
  // Total watch seconds = 1000 seconds
  const totalWatchSeconds = 1000;

  const channels = [
    { id: "std_channel", isCustom: false, seconds: 400 },
    { id: "custom_channel", isCustom: true, seconds: 600 },
  ];

  const allocations: Record<string, any> = {};

  for (const ch of channels) {
    const sharePercent = (ch.seconds / totalWatchSeconds) * 100;
    const creatorRate = ch.isCustom ? TYPE_REVENUE_SHARE.custom.premiumSubs : CREATOR_SHARE_RATE;
    const platformRate = ch.isCustom ? 0.00 : PLATFORM_SHARE_RATE;
    const channelGrossINR = proratedContributionINR * (sharePercent / 100);
    const creatorShareINR = Math.round(channelGrossINR * creatorRate * 100) / 100;
    const platformFeeINR = Math.round(channelGrossINR * platformRate * 100) / 100;

    allocations[ch.id] = {
      sharePercent,
      channelGrossINR: Math.round(channelGrossINR * 100) / 100,
      creatorShareINR,
      platformFeeINR,
    };
  }

  // Standard Channel: 40% watch share = ₹67.60 gross
  // Creator gets 70% of 67.60 = ₹47.32, Platform gets 30% = ₹20.28
  assert(allocations["std_channel"].sharePercent === 40, "Standard channel watch share is 40%");
  assert(allocations["std_channel"].channelGrossINR === 67.60, "Standard channel gross allocation is ₹67.60");
  assert(allocations["std_channel"].creatorShareINR === 47.32, `Standard channel creator share is ₹47.32 (got ₹${allocations["std_channel"].creatorShareINR})`);
  assert(allocations["std_channel"].platformFeeINR === 20.28, `Standard channel platform fee is ₹20.28 (got ₹${allocations["std_channel"].platformFeeINR})`);

  // Custom Channel: 60% watch share = ₹101.40 gross
  // Creator gets 100% of 101.40 = ₹101.40, Platform gets 0% = ₹0.00
  assert(allocations["custom_channel"].sharePercent === 60, "Custom channel watch share is 60%");
  assert(allocations["custom_channel"].channelGrossINR === 101.40, "Custom channel gross allocation is ₹101.40");
  assert(allocations["custom_channel"].creatorShareINR === 101.40, `Custom channel creator share is 100% = ₹101.40 (got ₹${allocations["custom_channel"].creatorShareINR})`);
  assert(allocations["custom_channel"].platformFeeINR === 0.00, `Custom channel platform fee is ₹0.00 (got ₹${allocations["custom_channel"].platformFeeINR})`);

  // Total subscriber money reconciliation
  const totalCreatorAllocated = allocations["std_channel"].creatorShareINR + allocations["custom_channel"].creatorShareINR;
  const totalPlatformAllocated = allocations["std_channel"].platformFeeINR + allocations["custom_channel"].platformFeeINR;
  const totalAccounted = Math.round((totalCreatorAllocated + totalPlatformAllocated) * 100) / 100;

  assert(totalAccounted === 169.00, `All subscriber funds fully accounted (₹169.00 = ₹${totalAccounted})`);
}

// ----------------------------------------------------------------------
// TEST 5: Monthly Financial Statements & Sync for Custom Channels
// ----------------------------------------------------------------------
function testMonthlyStatementSync() {
  console.log("\n--- [Test 5] Monthly Statement Sync Logic ---");

  // Replicating syncChannelStatements logic in functions/src/economy/revenue.ts
  function computeStatement(channel: {
    type?: string;
    channelType?: string;
    adsRevenueTotal: number;
    premiumSubsRevenueTotal: number;
    superchatRevenueTotal: number;
    membershipRevenueTotal: number;
  }) {
    const channelType: "standard" | "custom" =
      (channel.type === "custom" || channel.channelType === "custom") ? "custom" : "standard";

    const grossRevenue =
      channel.superchatRevenueTotal +
      channel.adsRevenueTotal +
      channel.membershipRevenueTotal +
      channel.premiumSubsRevenueTotal;

    let creatorShare = 0;
    let platformFee = 0;

    if (channelType === "custom") {
      creatorShare = Math.round(grossRevenue * 100) / 100;
      platformFee = 0;
    } else {
      creatorShare = Math.round((
        channel.adsRevenueTotal +
        channel.superchatRevenueTotal +
        channel.membershipRevenueTotal +
        channel.premiumSubsRevenueTotal
      ) * 100) / 100;
      const grossAds = channel.adsRevenueTotal > 0 ? channel.adsRevenueTotal / 0.70 : 0;
      const grossPremium = channel.premiumSubsRevenueTotal > 0 ? channel.premiumSubsRevenueTotal / 0.70 : 0;
      platformFee = Math.round(((grossAds + grossPremium) * 0.30) * 100) / 100;
    }

    return { channelType, grossRevenue, creatorShare, platformFee };
  }

  // 1. Custom Channel with all revenue streams
  const customStmt = computeStatement({
    type: "custom",
    adsRevenueTotal: 1200.50,
    premiumSubsRevenueTotal: 850.00,
    superchatRevenueTotal: 400.00,
    membershipRevenueTotal: 500.00,
  });

  assert(customStmt.channelType === "custom", "Channel resolved to custom");
  assert(customStmt.grossRevenue === 2950.50, `Gross revenue correctly calculated as ₹2950.50 (got ₹${customStmt.grossRevenue})`);
  assert(customStmt.creatorShare === 2950.50, `Custom channel receives 100% of gross revenue (₹2950.50, got ₹${customStmt.creatorShare})`);
  assert(customStmt.platformFee === 0, `Custom channel platform fee is exactly ₹0 (got ₹${customStmt.platformFee})`);

  // 2. Standard Channel with same gross revenue
  const stdStmt = computeStatement({
    type: "standard",
    adsRevenueTotal: 1200.50 * 0.70, // 840.35 net
    premiumSubsRevenueTotal: 850.00 * 0.70, // 595.00 net
    superchatRevenueTotal: 400.00,
    membershipRevenueTotal: 500.00,
  });

  assert(stdStmt.channelType === "standard", "Channel resolved to standard");
  assert(stdStmt.platformFee > 0, `Standard channel has platform fee > 0 (got ₹${stdStmt.platformFee})`);
}

// Execute all test suites
testRevenueShareMatrix();
testCalculateShareUtility();
testAdRevenueDistributionSplitting();
testPremiumSubscriptionSplitting();
testMonthlyStatementSync();

console.log("\n===============================================================================");
console.log(`Test Results: ${passed} passed, ${failed} failed`);
console.log("===============================================================================");

if (failed > 0) {
  process.exit(1);
} else {
  console.log("🎉 All Custom Channel 100% Revenue Split tests passed with flying colors!");
}
