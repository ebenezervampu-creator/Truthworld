const fs = require("fs");
const path = require("path");

console.log("=== REMEDIATING SURFACE 10: ADS, ALGORITHMS, COMMUNITY & USER ACCOUNTS ===");

const normalize = str => str.replace(/\r\n/g, "\n");

// 1. functions/src/utils/auth.ts
{
  const p = path.join(__dirname, "../functions/src/utils/auth.ts");
  let content = fs.readFileSync(p, "utf8");
  content = normalize(content);

  const oldCallableAdmin = `export function isCallableAdmin(auth: any): boolean {
  if (!auth) return false;
  const token = auth.token || {};
  return token.admin === true || token.role === "admin";
}`;

  const newCallableAdmin = `export function isCallableAdmin(auth: any): boolean {
  if (!auth) return false;
  const token = auth.token || {};
  const isEmailVerified = token.email_verified === true;
  const hasAdminClaim = token.admin === true || token.role === "admin";
  return hasAdminClaim && isEmailVerified;
}`;

  content = content.replace(normalize(oldCallableAdmin), normalize(newCallableAdmin));
  fs.writeFileSync(p, content, "utf8");
  console.log("Updated auth.ts: isCallableAdmin now requires email_verified === true");
}

// 2. functions/src/algorithm/remoteConfig.ts
{
  const p = path.join(__dirname, "../functions/src/algorithm/remoteConfig.ts");
  let content = fs.readFileSync(p, "utf8");
  content = normalize(content);

  const oldAdminCheck = `    // Verify admin privileges and recent session
    if (!isCallableRecentAdmin(request.auth, 3600)) {
      const userDoc = await db().collection("users").doc(request.auth.uid).get();
      const role = userDoc.data()?.role;
      if (role !== "admin" && role !== "superadmin") {
        throw new HttpsError(
          "permission-denied",
          "Administrative privileges and recent authentication required."
        );
      }
    }`;

  const newAdminCheck = `    // Verify admin privileges and recent session (strictly requires verified email)
    if (!isCallableRecentAdmin(request.auth, 3600)) {
      throw new HttpsError(
        "permission-denied",
        "Administrative privileges with verified email and recent authentication required."
      );
    }`;

  content = content.replace(normalize(oldAdminCheck), normalize(newAdminCheck));
  fs.writeFileSync(p, content, "utf8");
  console.log("Updated remoteConfig.ts: updateAlgorithmRemoteConfig strictly enforces recent verified admin");
}

// 3. [Decommissioned] functions/src/users/accountMerge.ts (Fully removed)

// 4. functions/src/users/userLifecycle.ts
{
  const p = path.join(__dirname, "../functions/src/users/userLifecycle.ts");
  let content = fs.readFileSync(p, "utf8");
  content = normalize(content);

  const oldPurgeCheck = `      if (user.uid !== targetUid && !user.isAdmin) {
        res.status(403).json({ error: "Forbidden: insufficient permissions" });
        return;
      }

      // Step-up authentication required for admin purging another user
      if (user.uid !== targetUid && user.isAdmin && user.authTime && !isSessionRecent(user.authTime, 3600)) {
        res.status(403).json({
          error: "Step-up authentication required. Please re-authenticate to purge another user's data.",
          code: "AUTH_STEP_UP_REQUIRED",
        });
        return;
      }`;

  const newPurgeCheck = `      if (user.uid !== targetUid && !user.isAdmin) {
        res.status(403).json({ error: "Forbidden: insufficient permissions" });
        return;
      }

      // Step-up authentication and verified email required for admin purging another user
      if (user.uid !== targetUid && user.isAdmin) {
        if (!user.emailVerified) {
          res.status(403).json({ error: "Forbidden: verified email required for administrative actions." });
          return;
        }
        if (!user.authTime || !isSessionRecent(user.authTime, 3600)) {
          res.status(403).json({
            error: "Step-up authentication required. Please re-authenticate to purge another user's data.",
            code: "AUTH_STEP_UP_REQUIRED",
          });
          return;
        }
      }

      // Prohibit purging administrative accounts
      const targetUserDoc = await admin.firestore().collection("users").doc(targetUid).get();
      if (targetUserDoc.exists) {
        const targetData = targetUserDoc.data();
        if (targetData?.role === "admin" || targetData?.role === "superadmin" || targetData?.isAdmin === true) {
          res.status(403).json({
            error: "Administrative accounts cannot be deleted or purged via this endpoint.",
          });
          return;
        }
      }`;

  content = content.replace(normalize(oldPurgeCheck), normalize(newPurgeCheck));
  fs.writeFileSync(p, content, "utf8");
  console.log("Updated userLifecycle.ts: purgeUserAccount protects admin accounts and enforces fail-closed step-up auth");
}

// 5. [Decommissioned] functions/src/livechat/liveChat.ts (Fully removed)

// 6. functions/src/community/comments.ts
{
  const p = path.join(__dirname, "../functions/src/community/comments.ts");
  let content = fs.readFileSync(p, "utf8");
  content = normalize(content);

  // Replace all 9 raw error interpolations
  content = content.replace(
    'throw new HttpsError("internal", `Failed to create comment: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to create comment at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to create reply: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to create reply at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to update interaction: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to update interaction at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to update reply interaction: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to update interaction at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to delete comment: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to delete comment at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to delete reply: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to delete reply at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to file report: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to file report at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to create topic comment: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to add topic comment at this time. Please try again.");'
  );

  content = content.replace(
    'throw new HttpsError("internal", `Failed to create topic reply: ${(err as Error)?.message || String(err)}`);',
    'if (err instanceof HttpsError) throw err;\n      throw new HttpsError("internal", "Unable to add topic reply at this time. Please try again.");'
  );

  // In deleteCommentNested and deleteReplyNested, also permit verified admins
  content = content.replace(
    'if (data?.userId !== userId && videoOwnerId !== userId) {\n        throw new HttpsError("permission-denied", "Unauthorized to delete this comment.");\n      }',
    'const isAdmin = request.auth?.token?.admin === true && request.auth?.token?.email_verified === true;\n      if (data?.userId !== userId && videoOwnerId !== userId && !isAdmin) {\n        throw new HttpsError("permission-denied", "Unauthorized to delete this comment.");\n      }'
  );

  content = content.replace(
    'if (data?.userId !== userId && videoOwnerId !== userId) {\n        throw new HttpsError("permission-denied", "Unauthorized to delete this reply.");\n      }',
    'const isAdmin = request.auth?.token?.admin === true && request.auth?.token?.email_verified === true;\n      if (data?.userId !== userId && videoOwnerId !== userId && !isAdmin) {\n        throw new HttpsError("permission-denied", "Unauthorized to delete this reply.");\n      }'
  );

  fs.writeFileSync(p, content, "utf8");
  console.log("Updated comments.ts: Sanitized all 9 raw developer error leaks and added admin moderation authority");
}

// 7. functions/src/ads/ads.ts
{
  const p = path.join(__dirname, "../functions/src/ads/ads.ts");
  let content = fs.readFileSync(p, "utf8");
  content = normalize(content);

  if (!content.includes('import { applySecurityHeaders } from "../utils/securityHeaders";')) {
    content = 'import { applySecurityHeaders } from "../utils/securityHeaders";\n' + content;
  }

  // In triggerAdAIFeatures: applySecurityHeaders and sanitize error
  const oldTriggerAI = `  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;`;

  const newTriggerAI = `  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;`;
  content = content.replace(normalize(oldTriggerAI), normalize(newTriggerAI));

  const oldTriggerErr = `    } catch (error) {
      console.error("[triggerAdAIFeatures] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal server error",
      });
    }`;

  const newTriggerErr = `    } catch (error) {
      console.error("[triggerAdAIFeatures] Error:", error);
      res.status(500).json({
        error: "Unable to process ad AI features. Please try again.",
      });
    }`;
  content = content.replace(normalize(oldTriggerErr), normalize(newTriggerErr));

  // In generateAllVideoAdsAIFeatures: applySecurityHeaders and sanitize error
  const oldBatchAI = `  async (req, res) => {
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
      if (!adminUser) return;`;

  const newBatchAI = `  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
      if (!adminUser) return;`;
  content = content.replace(normalize(oldBatchAI), normalize(newBatchAI));

  const oldBatchErr = `    } catch (error) {
      console.error("[generateAllVideoAdsAIFeatures] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal server error",
      });
    }`;

  const newBatchErr = `    } catch (error) {
      console.error("[generateAllVideoAdsAIFeatures] Error:", error);
      res.status(500).json({
        error: "Unable to complete batch AI features job. Please try again.",
      });
    }`;
  content = content.replace(normalize(oldBatchErr), normalize(newBatchErr));

  fs.writeFileSync(p, content, "utf8");
  console.log("Updated ads.ts: Injected security headers and eliminated raw error message leaks");
}

// 8. functions/src/notifications/notifications.ts
{
  const p = path.join(__dirname, "../functions/src/notifications/notifications.ts");
  let content = fs.readFileSync(p, "utf8");
  content = normalize(content);

  // In getNotifications: clamp limit to [1, 50]
  content = content.replace(
    "const limit = Math.min(Number(request.data?.limit) || 20, 50);",
    "const limit = Math.max(1, Math.min(Math.floor(Number(request.data?.limit) || 20), 50));"
  );

  // In sendPushNotificationForUser: sanitize webpush actionUrl
  const oldWebpushLink = `      fcmOptions: {
        link: params.actionUrl || "https://www.truthworld.in",
      },`;

  const newWebpushLink = `      fcmOptions: {
        link: (() => {
          const raw = params.actionUrl;
          if (!raw || typeof raw !== "string") return "https://www.truthworld.in";
          const trimmed = raw.trim();
          if (trimmed.startsWith("/")) return \`https://www.truthworld.in\${trimmed}\`;
          try {
            const p = new URL(trimmed);
            if ((p.protocol === "https:" || p.protocol === "http:") && (p.hostname === "truthworld.in" || p.hostname.endsWith(".truthworld.in"))) {
              return trimmed;
            }
          } catch {}
          return "https://www.truthworld.in";
        })(),
      },`;

  content = content.replace(normalize(oldWebpushLink), normalize(newWebpushLink));
  fs.writeFileSync(p, content, "utf8");
  console.log("Updated notifications.ts: Sanitized webpush URL links and bounded notification limits");
}

// 9. functions/src/feed/publicFeedServer.ts
{
  const p = path.join(__dirname, "../functions/src/feed/publicFeedServer.ts");
  let content = fs.readFileSync(p, "utf8");
  content = normalize(content);

  const helperFunc = `
/**
 * Sanitizes video items returned by public feed endpoints.
 * Strips internal moderation decisions, private storage paths, and raw audio references.
 */
function sanitizePublicVideoItem(data: Record<string, any>, id: string): Record<string, any> | null {
  if (
    data.isDeleted === true ||
    data.status === "suspended" ||
    data.status === "blocked" ||
    data.moderationStatus === "rejected" ||
    data.copyrightStrike === true
  ) {
    return null;
  }
  const clean = { id, ...data };
  delete clean.internalModerationDecision;
  delete clean.internalNotes;
  delete clean.privateStorageBucketUrl;
  delete clean.rawAudioUrl;
  delete clean.storagePath;
  delete clean.moderatorUid;
  return clean;
}
`;

  if (!content.includes("function sanitizePublicVideoItem(")) {
    content = content.replace(
      "export const publicFeedServer = onRequest(",
      helperFunc + "\nexport const publicFeedServer = onRequest("
    );
  }

  // Update trending map
  const oldTrendingMap = `        const scored = trendSnap.docs.map((doc) => {
          const data = doc.data();`;

  const newTrendingMap = `        const scored = trendSnap.docs.map((doc) => {
          const cleanItem = sanitizePublicVideoItem(doc.data(), doc.id);
          if (!cleanItem) return null;
          const data = cleanItem;`;

  content = content.replace(normalize(oldTrendingMap), normalize(newTrendingMap));

  // Filter out nulls in trendingVideos
  content = content.replace(
    "scored.sort((a, b) => b.trendingScore - a.trendingScore);",
    "const validScored = scored.filter((s): s is NonNullable<typeof s> => s !== null);\n        validScored.sort((a, b) => b.trendingScore - a.trendingScore);"
  );
  content = content.replace(
    "const trendingVideos = scored.slice(0, limit);",
    "const trendingVideos = validScored.slice(0, limit);"
  );

  // Update default feed map
  const oldDefaultMap = `        const videos = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));`;

  const newDefaultMap = `        const videos = snapshot.docs
          .map((doc) => sanitizePublicVideoItem(doc.data(), doc.id))
          .filter((v): v is NonNullable<typeof v> => v !== null);`;

  content = content.replace(normalize(oldDefaultMap), normalize(newDefaultMap));
  fs.writeFileSync(p, content, "utf8");
  console.log("Updated publicFeedServer.ts: Sanitized private fields and filtered suspended videos");
}

console.log("=== SURFACE 10 REMEDIATION SCRIPT COMPLETE ===");
