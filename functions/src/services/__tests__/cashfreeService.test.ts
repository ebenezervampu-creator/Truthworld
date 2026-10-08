import * as crypto from "crypto";
import { CashfreeService } from "../cashfreeService";

function assert(condition: boolean, message: string) {
  if (!condition) {
    throw new Error(`Assertion Failed: ${message}`);
  }
}

async function runTests() {
  console.log("==================================================");
  console.log(" Running Cashfree Backend Service Tests ");
  console.log("==================================================");

  // Test 1: Environment switching via CASHFREE_ENV
  process.env.CASHFREE_ENV = "SANDBOX";
  assert(
    CashfreeService.PublicEnvironment === "SANDBOX",
    "Environment should be SANDBOX when CASHFREE_ENV=SANDBOX"
  );
  console.log("✔ Test 1 passed: Environment resolves to SANDBOX via env var");

  process.env.CASHFREE_ENV = "PRODUCTION";
  assert(
    CashfreeService.PublicEnvironment === "PRODUCTION",
    "Environment should resolve to PRODUCTION when CASHFREE_ENV=PRODUCTION"
  );
  console.log("✔ Test 2 passed: Environment resolves to PRODUCTION via env var");

  // Test 2b: Auto-detection when CASHFREE_ENV is unset
  delete process.env.CASHFREE_ENV;

  process.env.CASHFREE_APP_ID = "TEST1023456789";
  assert(
    CashfreeService.PublicEnvironment === "SANDBOX",
    "Environment should auto-detect as SANDBOX when App ID starts with TEST"
  );
  console.log("✔ Test 2b passed: Auto-detected SANDBOX for TEST-prefixed App ID");

  process.env.CASHFREE_APP_ID = "PROD_MERCHANT_APP_ID_MOCK";
  assert(
    CashfreeService.PublicEnvironment === "PRODUCTION",
    "Environment should auto-detect as PRODUCTION for non-TEST App ID"
  );
  console.log("✔ Test 2c passed: Auto-detected PRODUCTION for non-TEST App ID");

  // Test 3: Webhook HMAC-SHA256 signature verification
  const testSecret = "test_secret_key_truthworld_12345";
  process.env.CASHFREE_SECRET_KEY = testSecret;

  const rawBody = JSON.stringify({
    data: {
      order: {
        order_id: "cf_premium_12345",
        order_amount: 149.0,
      },
      payment: {
        payment_status: "SUCCESS",
      },
    },
  });
  const timestamp = String(Date.now());

  // Generate valid signature
  const validSignature = crypto
    .createHmac("sha256", testSecret)
    .update(timestamp + rawBody)
    .digest("base64");

  const isVerified = CashfreeService.verifyWebhookSignature(
    validSignature,
    rawBody,
    timestamp
  );
  assert(isVerified === true, "Valid webhook signature must be verified successfully");
  console.log("✔ Test 3 passed: Valid webhook HMAC signature verified");

  // Test 4: Tampered body must fail verification
  const tamperedBody = rawBody.replace("cf_premium_12345", "cf_premium_99999");
  const isTamperedVerified = CashfreeService.verifyWebhookSignature(
    validSignature,
    tamperedBody,
    timestamp
  );
  assert(
    isTamperedVerified === false,
    "Tampered body must fail webhook signature verification"
  );
  console.log("✔ Test 4 passed: Tampered payload rejected");

  // Test 5: Wrong signature format / length handles gracefully without crashing
  const isInvalidSignatureVerified = CashfreeService.verifyWebhookSignature(
    "invalid_length_sig",
    rawBody,
    timestamp
  );
  assert(
    isInvalidSignatureVerified === false,
    "Invalid signature string must fail gracefully"
  );
  console.log("✔ Test 5 passed: Malformed signature safely rejected");

  // Test 6: Customer data sanitization
  assert(
    CashfreeService.cleanPhoneNumber("+91 98765 43210") === "9876543210",
    "Should extract last 10 digits from formatted phone"
  );
  assert(
    CashfreeService.cleanPhoneNumber(undefined) === "9999999999",
    "Should provide fallback for undefined phone"
  );
  assert(
    CashfreeService.cleanEmail("  CREATOR@TruthWorld.in  ") === "creator@truthworld.in",
    "Should trim and lowercase valid emails"
  );
  assert(
    CashfreeService.cleanCustomerId("user-uid_123$#@") === "user-uid_123",
    "Should sanitize customer ID characters"
  );
  console.log("✔ Test 6 passed: Customer data sanitizers clean phone, email, and customer ID");

  // Test 7: Subscription order tags sanitization
  const tags = CashfreeService.sanitizeOrderTags({
    purpose: "premium_subscription",
    planId: "4k_factchecked_monthly",
    autoPay: "true",
    price: 249,
  });
  assert(tags.purpose === "premium_subscription", "Tag purpose preserved");
  assert(tags.autoPay === "true", "Tag autoPay preserved");
  assert(tags.price === "249", "Numeric tag serialized to string");
  console.log("✔ Test 7 passed: Order and subscription tags sanitized properly");

  // Test 8: Subscription webhook HMAC signature verification
  const subWebhookPayload = JSON.stringify({
    data: {
      subscription: {
        subscription_id: "sub_prem_12345_user",
        sub_reference_id: "cf_sub_ref_67890",
        subscription_status: "ACTIVE",
      },
    },
    event: "SUBSCRIPTION_ACTIVATED",
  });
  const subTimestamp = String(Date.now());
  const subSignature = crypto
    .createHmac("sha256", testSecret)
    .update(subTimestamp + subWebhookPayload)
    .digest("base64");

  const isSubVerified = CashfreeService.verifyWebhookSignature(
    subSignature,
    subWebhookPayload,
    subTimestamp
  );
  assert(isSubVerified === true, "Subscription webhook payload must be verified with HMAC signature");
  console.log("✔ Test 8 passed: Subscription webhook HMAC signature verified");

  console.log("\nAll Cashfree backend unit tests completed successfully!");
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
