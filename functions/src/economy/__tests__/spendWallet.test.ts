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
console.log("🧪 TRANSACTIONAL CHANNEL WALLET SPEND ENGINE TEST SUITE");
console.log("===============================================================================");

interface SpendBreakdown {
  spendAmount: number;
  rolloverCredit: number;
  fundedBalance: number;
  availableRevUSD: number;
}

function calculateDeductions(input: SpendBreakdown) {
  const totalSpendable = input.rolloverCredit + input.fundedBalance + input.availableRevUSD;
  if (input.spendAmount > totalSpendable) {
    throw new Error(`Insufficient spendable balance. Required: $${input.spendAmount.toFixed(2)}, Available: $${totalSpendable.toFixed(2)}`);
  }

  const balanceBefore = totalSpendable;
  let remaining = input.spendAmount;

  let rolloverDeducted = 0;
  if (remaining > 0 && input.rolloverCredit > 0) {
    rolloverDeducted = Number(Math.min(input.rolloverCredit, remaining).toFixed(2));
    remaining = Number((remaining - rolloverDeducted).toFixed(2));
  }

  let fundedDeducted = 0;
  if (remaining > 0 && input.fundedBalance > 0) {
    fundedDeducted = Number(Math.min(input.fundedBalance, remaining).toFixed(2));
    remaining = Number((remaining - fundedDeducted).toFixed(2));
  }

  const revenueDeductedUSD = Number(remaining.toFixed(2));
  const revenueDeductedINR = Number((revenueDeductedUSD * 84.0).toFixed(2));

  const newRollover = Math.max(0, Number((input.rolloverCredit - rolloverDeducted).toFixed(2)));
  const newFundedBalance = Math.max(0, Number((input.fundedBalance - fundedDeducted).toFixed(2)));
  const balanceAfter = Number((balanceBefore - input.spendAmount).toFixed(2));

  return {
    balanceBefore,
    balanceAfter,
    rolloverDeducted,
    fundedDeducted,
    revenueDeductedUSD,
    revenueDeductedINR,
    newRollover,
    newFundedBalance,
  };
}

// ----------------------------------------------------------------------
// TEST 1: Zero-Waste Priority Order (Rollover -> Funded -> Revenue)
// ----------------------------------------------------------------------
function testZeroWasteDeductionPriority() {
  console.log("\n--- [Test 1] Zero-Waste Deduction Priority (Rollover -> Funded -> Revenue) ---");

  // Rollover has $10, Funded has $20, Revenue has $50 ($80 total).
  // Spending $15 should take $10 from rollover, $5 from funded, and $0 from revenue.
  const res1 = calculateDeductions({
    spendAmount: 15.0,
    rolloverCredit: 10.0,
    fundedBalance: 20.0,
    availableRevUSD: 50.0,
  });

  assert(res1.rolloverDeducted === 10.0, "Deducted full $10 from rollover credits first");
  assert(res1.fundedDeducted === 5.0, "Deducted $5 from funded balance second");
  assert(res1.revenueDeductedUSD === 0.0, "Deducted $0 from creator revenue");
  assert(res1.newRollover === 0.0, "New rollover balance is $0");
  assert(res1.newFundedBalance === 15.0, "New funded balance is $15 ($20 - $5)");
  assert(res1.balanceAfter === 65.0, "Total spendable after is $65 ($80 - $15)");

  // Spending $35 should take $10 from rollover, $20 from funded, and $5 from revenue.
  const res2 = calculateDeductions({
    spendAmount: 35.0,
    rolloverCredit: 10.0,
    fundedBalance: 20.0,
    availableRevUSD: 50.0,
  });

  assert(res2.rolloverDeducted === 10.0, "Deducted full $10 from rollover credits");
  assert(res2.fundedDeducted === 20.0, "Deducted full $20 from funded balance");
  assert(res2.revenueDeductedUSD === 5.0, "Deducted remaining $5 from creator revenue");
  assert(res2.revenueDeductedINR === 420.0, "Accounted revenue deduction as ₹420 ($5 × 84) in withdrawnRevenueTotal");
  assert(res2.newRollover === 0.0, "Rollover balance is $0");
  assert(res2.newFundedBalance === 0.0, "Funded balance is $0");
  assert(res2.balanceAfter === 45.0, "Total spendable after is $45 ($80 - $35)");
}

// ----------------------------------------------------------------------
// TEST 2: Overdraft & Double-Spend Defense
// ----------------------------------------------------------------------
function testOverdraftPrevention() {
  console.log("\n--- [Test 2] Overdraft & Double-Spend Defense ---");

  let threw = false;
  try {
    calculateDeductions({
      spendAmount: 100.0,
      rolloverCredit: 10.0,
      fundedBalance: 20.0,
      availableRevUSD: 50.0, // Total $80
    });
  } catch (err: any) {
    threw = true;
    assert(err.message.includes("Insufficient spendable balance"), "Threw Insufficient spendable balance error");
  }
  assert(threw, "Blocked overdraw attempt when requested amount > total spendable");
}

// ----------------------------------------------------------------------
// TEST 3: Exact Cent Precision
// ----------------------------------------------------------------------
function testExactCentPrecision() {
  console.log("\n--- [Test 3] Exact Cent Precision & Floating Point Safety ---");

  const res = calculateDeductions({
    spendAmount: 0.15, // 3 subtitles languages @ $0.05
    rolloverCredit: 0.07,
    fundedBalance: 1.00,
    availableRevUSD: 0.00,
  });

  assert(res.rolloverDeducted === 0.07, "Rollover deducted $0.07");
  assert(res.fundedDeducted === 0.08, "Funded balance deducted $0.08 ($0.15 - $0.07)");
  assert(res.newFundedBalance === 0.92, "New funded balance is exact $0.92");
  assert(res.balanceAfter === 0.92, "Spendable balance after is exact $0.92");
}

// Execute tests
testZeroWasteDeductionPriority();
testOverdraftPrevention();
testExactCentPrecision();

console.log("\n===============================================================================");
console.log(`📊 RESULTS: ${passed} Passed, ${failed} Failed`);
console.log("===============================================================================");

if (failed > 0) {
  process.exit(1);
}
