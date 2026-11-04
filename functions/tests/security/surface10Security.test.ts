import * as fs from "fs";
import * as path from "path";
import { isCallableAdmin } from "../../src/utils/auth";

describe("Surface 10 Security Verification: Advertising, Algorithmic Feeds, LiveChat & Account Security", () => {
  const rootDir = path.resolve(__dirname, "../../..");

  // ─── 1. Account Merging Decommissioning Verification (TW-USER-01) ──────────
  describe("TW-USER-01: Account Merge Decommissioning Policy", () => {
    test("verifies mergeDuplicateAccount and accountMerge.ts have been completely removed", () => {
      const mergePath = path.join(rootDir, "functions/src/users/accountMerge.ts");
      expect(fs.existsSync(mergePath)).toBe(false);
    });
  });

  // ─── 2. User Lifecycle & Admin Account Protection (TW-USER-02) ─────────────
  describe("TW-USER-02: Admin Account Protection & Step-up Auth in purgeUserAccount", () => {
    test("verifies purgeUserAccount prohibits purging administrator accounts and enforces verified email", () => {
      const lifecyclePath = path.join(rootDir, "functions/src/users/userLifecycle.ts");
      const content = fs.readFileSync(lifecyclePath, "utf8");

      expect(content).toContain("Administrative accounts cannot be deleted or purged via this endpoint.");
      expect(content).toContain("verified email required for administrative actions.");
      expect(content).toContain("(!user.authTime || !isSessionRecent(user.authTime, 3600))");
    });
  });

  // ─── 3. Callable Admin Auth & Algorithm Remote Config (TW-AUTH-01) ─────────
  describe("TW-AUTH-01: Callable Admin Verification & Algorithm Remote Config", () => {
    test("isCallableAdmin strictly requires email_verified === true", () => {
      expect(isCallableAdmin(null)).toBe(false);
      expect(isCallableAdmin({})).toBe(false);
      expect(isCallableAdmin({ token: { admin: true, email_verified: false } })).toBe(false);
      expect(isCallableAdmin({ token: { role: "admin", email_verified: false } })).toBe(false);
      expect(isCallableAdmin({ token: { admin: true, email_verified: true } })).toBe(true);
      expect(isCallableAdmin({ token: { role: "admin", email_verified: true } })).toBe(true);
    });

    test("updateAlgorithmRemoteConfig enforces recent admin with verified email", () => {
      const rcPath = path.join(rootDir, "functions/src/algorithm/remoteConfig.ts");
      const content = fs.readFileSync(rcPath, "utf8");

      expect(content).toContain("isCallableRecentAdmin(request.auth, 3600)");
      expect(content).not.toContain('const role = userDoc.data()?.role;');
    });
  });

  // ─── 4. LiveChat Decommissioning Verification (TW-LIVE-01) ──────────────
  describe("TW-LIVE-01: LiveChat Entire Decommissioning Policy", () => {
    test("verifies liveChat feature and functions have been completely removed", () => {
      const livePath = path.join(rootDir, "functions/src/livechat/liveChat.ts");
      expect(fs.existsSync(livePath)).toBe(false);
    });
  });

  // ─── 5. Community Comments Raw Error Elimination (TW-COMM-01) ──────────────
  describe("TW-COMM-01: Elimination of Raw Developer Errors in comments.ts", () => {
    test("verifies comments.ts never leaks raw error.message in HttpsError responses", () => {
      const commPath = path.join(rootDir, "functions/src/community/comments.ts");
      const content = fs.readFileSync(commPath, "utf8");

      expect(content).not.toContain("${(err as Error)?.message || String(err)}");
      expect(content).toContain("Unable to create comment at this time. Please try again.");
      expect(content).toContain("Unable to create reply at this time. Please try again.");
      expect(content).toContain("Unable to delete comment at this time. Please try again.");
      expect(content).toContain("Unable to delete reply at this time. Please try again.");
      expect(content).toContain("Unable to file report at this time. Please try again.");
    });
  });

  // ─── 6. Advertising Security & Security Headers (TW-ADS-01) ────────────────
  describe("TW-ADS-01: Advertising AI Endpoints Error Sanitization & Headers", () => {
    test("verifies triggerAdAIFeatures and generateAllVideoAdsAIFeatures apply security headers and sanitize errors", () => {
      const adsPath = path.join(rootDir, "functions/src/ads/ads.ts");
      const content = fs.readFileSync(adsPath, "utf8");

      expect(content).toContain("applySecurityHeaders(res)");
      expect(content).toContain("Unable to process ad AI features. Please try again.");
      expect(content).toContain("Unable to complete batch AI features job. Please try again.");
      expect(content).not.toContain("error: error instanceof Error ? error.message : ");
    });
  });

  // ─── 7. Notifications Webpush Open Redirect Defense (TW-NOTIF-01) ──────────
  describe("TW-NOTIF-01: Notifications WebPush Destination Sanitization & Bounds", () => {
    test("verifies notifications.ts sanitizes webpush action URLs to prevent open redirects", () => {
      const notifPath = path.join(rootDir, "functions/src/notifications/notifications.ts");
      const content = fs.readFileSync(notifPath, "utf8");

      expect(content).toContain("p.hostname === \"truthworld.in\" || p.hostname.endsWith(\".truthworld.in\")");
      expect(content).toContain("Math.max(1, Math.min(Math.floor(Number(request.data?.limit) || 20), 50))");
    });
  });

  // ─── 8. Public Edge Feed Sanitization (TW-FEED-01) ─────────────────────────
  describe("TW-FEED-01: Public Feed Metadata Sanitization & Content Filtering", () => {
    test("verifies publicFeedServer strips internal moderation metadata and filters suspended content", () => {
      const feedPath = path.join(rootDir, "functions/src/feed/publicFeedServer.ts");
      const content = fs.readFileSync(feedPath, "utf8");

      expect(content).toContain("function sanitizePublicVideoItem(");
      expect(content).toContain("delete clean.internalModerationDecision");
      expect(content).toContain("delete clean.privateStorageBucketUrl");
      expect(content).toContain("delete clean.internalNotes");
      expect(content).toContain("data.status === \"suspended\"");
      expect(content).toContain("data.status === \"blocked\"");
      expect(content).toContain("data.isDeleted === true");
    });
  });
});
