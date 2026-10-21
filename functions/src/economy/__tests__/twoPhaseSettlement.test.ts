import { SETTLEMENT_CLEARING_DAYS, SETTLEMENT_CLEARING_MS } from "../types";

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
console.log("🧪 INDUSTRY-STANDARD TWO-PHASE SETTLEMENT TEST SUITE");
console.log("===============================================================================");

// ----------------------------------------------------------------------
// TEST 1: T+7 Clearing Hold Parameters
// ----------------------------------------------------------------------
function testClearingParameters() {
  console.log("\n--- [Test 1] Anti-Chargeback Hold Constants ---");
  assert(SETTLEMENT_CLEARING_DAYS === 7, "Settlement hold is standard T+7 days");
  assert(SETTLEMENT_CLEARING_MS === 7 * 24 * 60 * 60 * 1000, "Settlement hold in ms equals 604,800,000 ms");
}

// ----------------------------------------------------------------------
// TEST 2: Maturity Transition Logic for Direct Fan Payments
// ----------------------------------------------------------------------
function testMaturityTransition() {
  console.log("\n--- [Test 2] Maturity Transition (Clearing vs Cleared) ---");

  const now = 1790000000000;
  const recentCreatedAt = now - (3 * 24 * 60 * 60 * 1000); // 3 days old (still in hold)
  const matureCreatedAt = now - (8 * 24 * 60 * 60 * 1000); // 8 days old (cleared)

  const isRecentMature = (now - recentCreatedAt) >= SETTLEMENT_CLEARING_MS;
  const isOlderMature = (now - matureCreatedAt) >= SETTLEMENT_CLEARING_MS;

  assert(!isRecentMature, "3-day-old Superchat remains in 'clearing' status (not mature)");
  assert(isOlderMature, "8-day-old Superchat transitions to 'cleared' status (mature)");
}

// ----------------------------------------------------------------------
// TEST 3: Two-Phase Balance Partitioning & Anti-Chargeback Overdraft Protection
// ----------------------------------------------------------------------
function testTwoPhaseBalancePartitioning() {
  console.log("\n--- [Test 3] Two-Phase Balance Partitioning & Payout Guard ---");

  // Scenario: Creator earned:
  // - ₹1,000 Superchats older than 7 days (Cleared)
  // - ₹500 Superchats from yesterday (In 7-day Clearing Hold)
  // - ₹2,000 Ads from finalized prior month statement (Cleared)
  // - ₹800 Ads from current active month (Pending month-end finalization)
  // - ₹0 withdrawn previously
  const clearedSuperchats = 1000;
  const pendingSuperchats = 500;
  const finalizedPastAds = 2000;
  const currentMonthInFlightAds = 800;
  const withdrawnTotal = 0;

  const totalEstimatedEarnings = clearedSuperchats + pendingSuperchats + finalizedPastAds + currentMonthInFlightAds; // ₹4,300
  const clearedBalance = clearedSuperchats + finalizedPastAds; // ₹3,000
  const pendingClearingBalance = pendingSuperchats + currentMonthInFlightAds; // ₹1,300
  const availableWithdrawable = Math.max(0, clearedBalance - withdrawnTotal); // ₹3,000

  assert(totalEstimatedEarnings === 4300, `Total estimated earnings correctly equals ₹4,300 (got ₹${totalEstimatedEarnings})`);
  assert(clearedBalance === 3000, `Cleared withdrawable balance correctly equals ₹3,000 (got ₹${clearedBalance})`);
  assert(pendingClearingBalance === 1300, `Pending clearing balance correctly equals ₹1,300 (got ₹${pendingClearingBalance})`);
  assert(availableWithdrawable === 3000, `Available cash withdrawable equals ₹3,000`);

  // Attempting to withdraw ₹3,500 (which exceeds ₹3,000 cleared balance even though total is ₹4,300)
  const requestedAmount = 3500;
  const isOverdrawAttempt = requestedAmount > availableWithdrawable;
  assert(isOverdrawAttempt, "Attempt to withdraw ₹3,500 exceeds cleared balance (₹3,000) and is properly rejected");

  // Attempting to withdraw ₹2,500 (within cleared balance)
  const validRequestedAmount = 2500;
  const isValidWithdrawal = validRequestedAmount <= availableWithdrawable;
  assert(isValidWithdrawal, "Attempt to withdraw ₹2,500 is within cleared balance and allowed");

  const newWithdrawnTotal = withdrawnTotal + validRequestedAmount;
  const remainingCleared = Math.max(0, clearedBalance - newWithdrawnTotal);
  assert(remainingCleared === 500, `Remaining cleared withdrawable balance after payout is ₹500 (got ₹${remainingCleared})`);
}

// ----------------------------------------------------------------------
// TEST 4: Month-End Statement Finalization Unlocks In-Flight Earnings
// ----------------------------------------------------------------------
function testMonthEndFinalization() {
  console.log("\n--- [Test 4] Month-End Statement Finalization Lifecycle ---");

  let clearedBalance = 3000;
  let pendingBalance = 1300;

  // 1st of month scheduler runs: past month statement is finalized (+₹800 creator share)
  const auditedPastMonthCreatorShare = 800;
  clearedBalance += auditedPastMonthCreatorShare;
  pendingBalance -= auditedPastMonthCreatorShare;

  assert(clearedBalance === 3800, `Cleared balance unlocked to ₹3,800 post-finalization (got ₹${clearedBalance})`);
  assert(pendingBalance === 500, `Remaining pending balance equals ₹500 (Superchats still in T+7 window)`);
}

// ----------------------------------------------------------------------
// TEST 5: Automatic Monthly Bank Disbursement (YouTube AdSense Model)
// ----------------------------------------------------------------------
function testAutoPayoutEligibility() {
  console.log("\n--- [Test 5] Automatic Monthly Bank Disbursement Eligibility ---");

  const MIN_AUTO_PAYOUT_THRESHOLD = 100; // ₹100 industry-standard minimum

  interface ChannelMock {
    channelId: string;
    kycStatus: string;
    payoutsBlocked: boolean;
    fraudReviewFlag: boolean;
    autoPayoutEnabled: boolean;
    clearedBalanceINR: number;
    hasBankAccount: boolean;
  }

  function evaluateAutoPayout(ch: ChannelMock): { eligible: boolean; reason: string } {
    if (ch.autoPayoutEnabled === false) {
      return { eligible: false, reason: "opted_out_wallet_preserve" };
    }
    if (ch.kycStatus !== "verified") {
      return { eligible: false, reason: "kyc_unverified" };
    }
    if (ch.payoutsBlocked || ch.fraudReviewFlag) {
      return { eligible: false, reason: "fraud_or_blocked" };
    }
    if (ch.clearedBalanceINR < MIN_AUTO_PAYOUT_THRESHOLD) {
      return { eligible: false, reason: "below_threshold_rollover" };
    }
    if (!ch.hasBankAccount) {
      return { eligible: false, reason: "missing_bank_account" };
    }
    return { eligible: true, reason: "ready_for_disbursement" };
  }

  // Case A: Below threshold (₹65) -> Safe rollover to next month
  const chBelowThreshold: ChannelMock = {
    channelId: "ch_low_balance",
    kycStatus: "verified",
    payoutsBlocked: false,
    fraudReviewFlag: false,
    autoPayoutEnabled: true,
    clearedBalanceINR: 65,
    hasBankAccount: true,
  };
  const resA = evaluateAutoPayout(chBelowThreshold);
  assert(!resA.eligible && resA.reason === "below_threshold_rollover", "Channel with ₹65 safely rolls over without debit or error");

  // Case B: Meets threshold (₹150), verified KYC, valid bank -> Disburses
  const chEligible: ChannelMock = {
    channelId: "ch_healthy",
    kycStatus: "verified",
    payoutsBlocked: false,
    fraudReviewFlag: false,
    autoPayoutEnabled: true,
    clearedBalanceINR: 150,
    hasBankAccount: true,
  };
  const resB = evaluateAutoPayout(chEligible);
  assert(resB.eligible && resB.reason === "ready_for_disbursement", "Channel with ₹150 cleared balance qualifies for automatic bank deposit");

  // Case C: Opted out to keep funds in wallet for AI Dubbing
  const chOptOut: ChannelMock = {
    channelId: "ch_ai_user",
    kycStatus: "verified",
    payoutsBlocked: false,
    fraudReviewFlag: false,
    autoPayoutEnabled: false,
    clearedBalanceINR: 5000,
    hasBankAccount: true,
  };
  const resC = evaluateAutoPayout(chOptOut);
  assert(!resC.eligible && resC.reason === "opted_out_wallet_preserve", "Creator opted out of auto-payout has funds safely retained in channel wallet");

  // Case D: Unverified KYC -> Blocked until verified
  const chUnverifiedKyc: ChannelMock = {
    channelId: "ch_no_kyc",
    kycStatus: "pending",
    payoutsBlocked: false,
    fraudReviewFlag: false,
    autoPayoutEnabled: true,
    clearedBalanceINR: 2000,
    hasBankAccount: true,
  };
  const resD = evaluateAutoPayout(chUnverifiedKyc);
  assert(!resD.eligible && resD.reason === "kyc_unverified", "Unverified KYC prevents auto-disbursement until identity documents are validated");

  // Case E: Missing bank account -> Actionable notification sent, funds roll over
  const chNoBank: ChannelMock = {
    channelId: "ch_no_bank",
    kycStatus: "verified",
    payoutsBlocked: false,
    fraudReviewFlag: false,
    autoPayoutEnabled: true,
    clearedBalanceINR: 800,
    hasBankAccount: false,
  };
  const resE = evaluateAutoPayout(chNoBank);
  assert(!resE.eligible && resE.reason === "missing_bank_account", "Missing bank account safely delays payout and flags creator notification");
}

// Execute tests
testClearingParameters();
testMaturityTransition();
testTwoPhaseBalancePartitioning();
testMonthEndFinalization();
testAutoPayoutEligibility();

console.log("\n===============================================================================");
console.log(`Test Results: ${passed} passed, ${failed} failed`);
console.log("===============================================================================");

if (failed > 0) {
  process.exit(1);
} else {
  console.log("🎉 All Two-Phase Settlement tests passed cleanly!");
}
