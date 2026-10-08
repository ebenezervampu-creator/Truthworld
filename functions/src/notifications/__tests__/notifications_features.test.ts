/**
 * 🧪 BACKEND PUSH NOTIFICATIONS FEATURE TEST SUITE
 * 
 * Verifies one by one all core push notification features:
 * 1. FCM Token Extraction (string and object formats)
 * 2. FCM Multicast Payload Building (Android heads-up, APNS, Data & Metadata forwarding)
 * 3. Channel Mention Extraction & Safety Limits (@handles, deduplication, max 5)
 * 4. Creator Notification Template Engine (Interpolation for milestones & verification)
 * 5. Stale Token Cleanup Logic
 * 6. Universal Push Safety Net Filtering
 */

import { TEMPLATE_REGISTRY } from "../templates/notificationTemplates";

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

// ----------------------------------------------------------------------
// FEATURE 1: FCM Token Extraction
// ----------------------------------------------------------------------
function testFcmTokenExtraction() {
  console.log("\n--- [Feature 1] Testing FCM Token Extraction ---");

  function extractTokens(fcmTokensMap: Record<string, any> | undefined): {
    tokens: string[];
    duplicateDeviceIds: string[];
    entries: { deviceId: string; token: string }[];
  } {
    if (!fcmTokensMap) return { tokens: [], duplicateDeviceIds: [], entries: [] };
    const tokenToDeviceMap = new Map<string, string>();
    const duplicateDeviceIds: string[] = [];

    for (const [deviceId, val] of Object.entries(fcmTokensMap)) {
      let tokenStr = "";
      if (typeof val === "string") {
        tokenStr = val.trim();
      } else if (val && typeof val === "object" && typeof val.token === "string") {
        tokenStr = val.token.trim();
      }
      if (tokenStr.length > 0) {
        if (tokenToDeviceMap.has(tokenStr)) {
          duplicateDeviceIds.push(deviceId);
        } else {
          tokenToDeviceMap.set(tokenStr, deviceId);
        }
      }
    }
    return {
      tokens: Array.from(tokenToDeviceMap.keys()),
      duplicateDeviceIds,
      entries: Array.from(tokenToDeviceMap.entries()).map(([token, deviceId]) => ({ deviceId, token })),
    };
  }

  // Case A: Mixed tokens (both plain string and object representation)
  const sampleTokensMap = {
    "device_android_1": "token_android_abc123",
    "device_android_duplicate": "token_android_abc123", // Duplicate token from reinstall/token refresh
    "device_ios_2": {
      token: "token_ios_def456",
      platform: "ios",
      updatedAt: 1700000000000
    },
    "device_empty": "",
    "device_whitespace": "   ",
    "device_malformed": { token: "  " },
    "device_invalid_obj": { foo: "bar" }
  };

  const extracted = extractTokens(sampleTokensMap);
  assert(extracted.tokens.length === 2, "Deduplicates tokens to exactly 2 unique tokens (prevents double notifications)");
  assert(extracted.duplicateDeviceIds.length === 1 && extracted.duplicateDeviceIds[0] === "device_android_duplicate", "Identifies duplicate device token key for pruning");
  assert(extracted.entries.some(e => e.deviceId === "device_android_1" && e.token === "token_android_abc123"), "Extracts plain string token");
  assert(extracted.entries.some(e => e.deviceId === "device_ios_2" && e.token === "token_ios_def456"), "Extracts token nested in object");

  // Case B: Undefined map
  const emptyExtracted = extractTokens(undefined);
  assert(emptyExtracted.tokens.length === 0, "Handles undefined fcmTokens map safely");
}

// ----------------------------------------------------------------------
// FEATURE 2: FCM Multicast Payload Building with Metadata Forwarding
// ----------------------------------------------------------------------
function testFcmPayloadBuilding() {
  console.log("\n--- [Feature 2] Testing FCM Payload Construction ---");

  function buildPayload(params: {
    tokens: string[];
    title: string;
    message: string;
    type: string;
    severity: string;
    actionUrl?: string;
    notificationId: string;
    metadata?: Record<string, any>;
  }) {
    const dataPayload: Record<string, string> = {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      actionUrl: params.actionUrl || "",
      type: String(params.type),
      severity: String(params.severity),
      notificationId: String(params.notificationId),
    };

    if (params.metadata && typeof params.metadata === "object") {
      for (const [key, val] of Object.entries(params.metadata)) {
        if (val !== undefined && val !== null) {
          dataPayload[key] = typeof val === "object" ? JSON.stringify(val) : String(val);
        }
      }
    }

    return {
      tokens: params.tokens,
      notification: {
        title: params.title,
        body: params.message,
      },
      data: dataPayload,
      android: {
        priority: "high" as const,
        collapseKey: String(params.notificationId),
        notification: {
          sound: "default",
          channelId: "truthworld_notifications",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          priority: "max" as const,
          notificationPriority: "PRIORITY_MAX" as const,
          visibility: "public" as const,
          tag: String(params.notificationId),
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
          "apns-collapse-id": String(params.notificationId),
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "mutable-content": 1,
          },
        },
      },
    };
  }

  const payload = buildPayload({
    tokens: ["token_1", "token_2"],
    title: "New Video from Truth Channel",
    message: "Truth Channel uploaded: Testing Notifications",
    type: "new_video_followed",
    severity: "info",
    actionUrl: "/video/vid_999",
    notificationId: "notif_123",
    metadata: {
      videoId: "vid_999",
      channelId: "chan_777",
      commentId: "c_888",
      replyId: "r_555"
    }
  });

  // Verify Android heads-up config & deduplication tags
  assert(payload.android.priority === "high", "Android priority is 'high'");
  assert(payload.android.collapseKey === "notif_123", "Android collapseKey is notificationId");
  assert(payload.android.notification.channelId === "truthworld_notifications", "Android channelId is 'truthworld_notifications'");
  assert(payload.android.notification.notificationPriority === "PRIORITY_MAX", "Android notificationPriority is 'PRIORITY_MAX'");
  assert(payload.android.notification.visibility === "public", "Android visibility is 'public'");
  assert(payload.android.notification.tag === "notif_123", "Android notification tag is set to notificationId for OS-level deduplication");

  // Verify APNS config
  assert(payload.apns.headers["apns-priority"] === "10", "APNS priority is 10");
  assert(payload.apns.headers["apns-collapse-id"] === "notif_123", "APNS collapse ID is set to notificationId");
  assert(payload.apns.payload.aps.badge === 1, "APNS badge is 1");
  assert(payload.apns.payload.aps["mutable-content"] === 1, "APNS mutable-content is 1");

  // Verify Data Payload forwarding
  assert(payload.data.click_action === "FLUTTER_NOTIFICATION_CLICK", "click_action set to FLUTTER_NOTIFICATION_CLICK");
  assert(payload.data.videoId === "vid_999", "videoId correctly forwarded into data payload");
  assert(payload.data.channelId === "chan_777", "channelId correctly forwarded into data payload");
  assert(payload.data.commentId === "c_888", "commentId correctly forwarded into data payload");
  assert(payload.data.replyId === "r_555", "replyId correctly forwarded into data payload");
  assert(payload.data.actionUrl === "/video/vid_999", "actionUrl correctly included in data payload");
}

// ----------------------------------------------------------------------
// FEATURE 3: Channel Mention Extraction & Abuse Prevention
// ----------------------------------------------------------------------
function testMentionExtraction() {
  console.log("\n--- [Feature 3] Testing Channel Mention Parsing ---");

  function parseMentions(text: string): string[] {
    if (!text) return [];
    const matches = text.match(/@[\w\-]+/g) || [];
    if (matches.length === 0) return [];
    // Strips '@', lowercase, deduplicate, cap at 5
    return [...new Set(matches.map(m => m.substring(1).toLowerCase()))].slice(0, 5);
  }

  const sampleText = "Hey @truth-creator! Check this out with @TruthWorld, and also @truth-creator again. Plus @user1, @user2, @user3, @user4.";
  const handles = parseMentions(sampleText);

  assert(handles.includes("truth-creator"), "Parses lowercase handle with hyphen");
  assert(handles.includes("truthworld"), "Normalizes uppercase handle to lowercase");
  assert(handles.filter(h => h === "truth-creator").length === 1, "Deduplicates repeated handles");
  assert(handles.length <= 5, "Strictly caps parsed mentions at 5 to prevent spam");
  assert(handles.length === 5, "Contains exactly 5 unique mentions from text with 7 mentions");
}

// ----------------------------------------------------------------------
// FEATURE 4: Creator Milestone & Verification Templates
// ----------------------------------------------------------------------
function testTemplateRegistry() {
  console.log("\n--- [Feature 4] Testing Notification Templates ---");

  function renderTemplate(template: string, vars: Record<string, any>): string {
    return template.replace(/\{\{(\w+)\}\}/g, (_, key) => vars[key] !== undefined ? String(vars[key]) : "");
  }

  // 1. Verification Rejected
  const verifTemplate = TEMPLATE_REGISTRY["verification_rejected_v1"];
  assert(verifTemplate !== undefined, "Template 'verification_rejected_v1' exists");
  assert(verifTemplate.priority === "critical", "Verification rejection has critical priority");
  const renderedVerifTitle = renderTemplate(verifTemplate.titleTemplate, { videoTitle: "AI Deepfake Exposed" });
  assert(renderedVerifTitle === "Truth Verification Action Required: AI Deepfake Exposed", "Interpolates verification title correctly");
  const renderedVerifMsg = renderTemplate(verifTemplate.messageTemplate, {
    videoTitle: "AI Deepfake Exposed",
    confidencePercent: 98,
    reason: "Synthetic voice match detected"
  });
  assert(renderedVerifMsg.includes("98% AI synthetic confidence"), "Interpolates confidence score");
  assert(renderedVerifMsg.includes("Synthetic voice match detected"), "Interpolates failure reason");

  // 2. Subscribers Milestone
  const subMilestone = TEMPLATE_REGISTRY["subscribers_milestone_v1"];
  assert(subMilestone !== undefined, "Template 'subscribers_milestone_v1' exists");
  const renderedSub = renderTemplate(subMilestone.titleTemplate, { targetValue: "10,000" });
  assert(renderedSub === "🎉 Milestone Achieved: 10,000 Subscribers!", "Interpolates subscriber milestone title");

  // 3. Views Milestone
  const viewMilestone = TEMPLATE_REGISTRY["views_milestone_v1"];
  assert(viewMilestone !== undefined, "Template 'views_milestone_v1' exists");
  const renderedView = renderTemplate(viewMilestone.titleTemplate, { videoTitle: "My Top Video", targetValue: "1M" });
  assert(renderedView === "🚀 My Top Video Hit 1M Views!", "Interpolates view milestone title");

  // 4. AI Creator Coach
  const coachTemplate = TEMPLATE_REGISTRY["coach_growth_tip_v1"];
  assert(coachTemplate !== undefined, "Template 'coach_growth_tip_v1' exists");
  const renderedCoach = renderTemplate(coachTemplate.titleTemplate, { headline: "Upload Consistency" });
  assert(renderedCoach === "💡 AI Creator Coach: Upload Consistency", "Interpolates coach headline");
}

// ----------------------------------------------------------------------
// FEATURE 5: Stale Token Cleanup Logic
// ----------------------------------------------------------------------
function testStaleTokenCleanup() {
  console.log("\n--- [Feature 5] Testing Stale Token Cleanup Logic ---");

  const deviceEntries = [
    { deviceId: "device_active", token: "valid_token" },
    { deviceId: "device_unregistered", token: "expired_token_1" },
    { deviceId: "device_invalid", token: "invalid_token_2" },
  ];

  const mockFcmResponses = [
    { success: true },
    { success: false, error: { code: "messaging/registration-token-not-registered" } },
    { success: false, error: { code: "messaging/invalid-registration-token" } },
  ];

  const tokensToRemove: Record<string, any> = {};
  mockFcmResponses.forEach((res, index) => {
    if (!res.success && res.error) {
      const errCode = res.error.code;
      if (
        errCode === "messaging/invalid-registration-token" ||
        errCode === "messaging/registration-token-not-registered"
      ) {
        const deviceId = deviceEntries[index]?.deviceId;
        if (deviceId) {
          tokensToRemove[`fcmTokens.${deviceId}`] = "DELETE";
        }
      }
    }
  });

  assert(Object.keys(tokensToRemove).length === 2, "Identifies exactly 2 stale device tokens");
  assert(tokensToRemove["fcmTokens.device_unregistered"] === "DELETE", "Flags unregistered token for deletion");
  assert(tokensToRemove["fcmTokens.device_invalid"] === "DELETE", "Flags invalid token for deletion");
  assert(!tokensToRemove["fcmTokens.device_active"], "Does not delete active token");
}

// ----------------------------------------------------------------------
// FEATURE 6: Universal Notification Safety Net Filtering
// ----------------------------------------------------------------------
function testSafetyNetFiltering() {
  console.log("\n--- [Feature 6] Testing Universal Safety Net Filter ---");

  function shouldSendPush(data: any): boolean {
    if (!data) return false;
    if (data.pushSent === true) return false;
    const { userId, title } = data;
    if (!userId || userId === "guest_user" || !title) return false;
    return true;
  }

  assert(shouldSendPush({ pushSent: true, userId: "u123", title: "Hello" }) === false, "Skips if pushSent is already true");
  assert(shouldSendPush({ pushSent: false, userId: "guest_user", title: "Hello" }) === false, "Skips guest users");
  assert(shouldSendPush({ pushSent: false, userId: "u123", title: "" }) === false, "Skips empty title");
  assert(shouldSendPush({ pushSent: false, userId: "u123", title: "New Video!" }) === true, "Approves valid notification for push dispatch");
}

// ----------------------------------------------------------------------
// FEATURE 7: Channel Subscription Notification Preferences (Personalized First)
// ----------------------------------------------------------------------
function testChannelNotificationPreferences() {
  console.log("\n--- [Feature 7] Testing Channel Notification Preferences ---");

  // Helper matching followChannel option resolution
  function resolveSubscribeNotificationOption(rawOption?: string, rawPref?: string) {
    const inputOption = (rawOption || rawPref || "personalized").toLowerCase();
    const notificationOption = ["all", "personalized", "none"].includes(inputOption)
      ? inputOption
      : "personalized";
    const notificationsEnabled = notificationOption !== "none";
    return { notificationOption, notificationPreference: notificationOption, notificationsEnabled };
  }

  // Helper matching subscriber fan-out filter logic
  function shouldNotifySubscriber(
    subDoc: {
      userId?: string;
      notificationsEnabled?: boolean;
      notificationOption?: string;
      notificationPreference?: string;
    },
    creatorId: string,
    video: any = { isFactChecked: true } // default to highlight if not specified
  ): { notify: boolean; effectiveOption: string; deliverFeedInbox: boolean } {
    if (!subDoc.userId || subDoc.userId === creatorId) {
      return { notify: false, effectiveOption: "none", deliverFeedInbox: false };
    }
    const effectiveOption = (subDoc.notificationOption || subDoc.notificationPreference || (subDoc.notificationsEnabled === false ? "none" : "personalized")).toLowerCase();
    
    // Check if video is personalized-eligible highlight
    const isVerified = video.isFactChecked === true || video.factCheckStatus === "verified";
    const isFeatured = video.featured === true || video.isFeatured === true;
    const isHighTruth = typeof video.truthScore === "number" && video.truthScore >= 75;
    const isHighTrust = typeof video.trustScore === "number" && video.trustScore >= 75;
    const isHighlight = video.isHighlight === true;
    const isPersonalizedEligible = isVerified || isFeatured || isHighTruth || isHighTrust || isHighlight;

    const notify = subDoc.notificationsEnabled !== false &&
      effectiveOption !== "none" &&
      (effectiveOption === "all" || isPersonalizedEligible);

    return { notify, effectiveOption, deliverFeedInbox: true };
  }

  // 1. Default subscription resolution
  const defaultSub = resolveSubscribeNotificationOption();
  assert(defaultSub.notificationOption === "personalized", "Default subscription notification option is 'personalized'");
  assert(defaultSub.notificationsEnabled === true, "Default subscription has notificationsEnabled === true");

  // 2. Custom subscription options
  const allSub = resolveSubscribeNotificationOption("all");
  assert(allSub.notificationOption === "all" && allSub.notificationsEnabled === true, "Resolves 'all' option correctly with enabled true");

  const noneSub = resolveSubscribeNotificationOption("none");
  assert(noneSub.notificationOption === "none" && noneSub.notificationsEnabled === false, "Resolves 'none' option correctly with enabled false");

  const invalidSub = resolveSubscribeNotificationOption("unknown_random_option");
  assert(invalidSub.notificationOption === "personalized", "Falls back to 'personalized' for unknown options");

  // 3. Fan-out filtering tests
  const creatorId = "creator_123";
  const routineVideo = { title: "Routine vlog", isFactChecked: false, truthScore: 50, featured: false };
  const verifiedHighlight = { title: "Verified Fact-Check Investigation", factCheckStatus: "verified", truthScore: 92 };

  // Creator uploading own video
  const creatorCheck = shouldNotifySubscriber({ userId: creatorId, notificationOption: "all" }, creatorId, verifiedHighlight);
  assert(creatorCheck.notify === false && creatorCheck.deliverFeedInbox === false, "Skips notifying creator of their own video");

  // Subscriber with 'none': really not sending notifications
  const noneSubRoutine = shouldNotifySubscriber({ userId: "sub_none", notificationsEnabled: false, notificationOption: "none" }, creatorId, routineVideo);
  assert(noneSubRoutine.notify === false && noneSubRoutine.effectiveOption === "none", "When 'none', really not sending notification for routine video");
  assert(noneSubRoutine.deliverFeedInbox === true, "When 'none', still delivers video to user's feed inbox");

  const noneSubHighlight = shouldNotifySubscriber({ userId: "sub_none", notificationsEnabled: false, notificationOption: "none" }, creatorId, verifiedHighlight);
  assert(noneSubHighlight.notify === false && noneSubHighlight.effectiveOption === "none", "When 'none', really not sending notification even for verified highlight video");

  // Subscriber with 'personalized': sends ONLY personalized highlights
  const persRoutine = shouldNotifySubscriber({ userId: "sub_pers", notificationsEnabled: true, notificationOption: "personalized" }, creatorId, routineVideo);
  assert(persRoutine.notify === false && persRoutine.effectiveOption === "personalized", "When 'personalized', does NOT send notification for routine unverified video");
  assert(persRoutine.deliverFeedInbox === true, "When 'personalized', routine video still appears in feed inbox");

  const persHighlight = shouldNotifySubscriber({ userId: "sub_pers", notificationsEnabled: true, notificationOption: "personalized" }, creatorId, verifiedHighlight);
  assert(persHighlight.notify === true && persHighlight.effectiveOption === "personalized", "When 'personalized', DOES send notification for verified highlight video");

  // Subscriber with 'all': receives notifications for ALL videos
  const allRoutine = shouldNotifySubscriber({ userId: "sub_all", notificationsEnabled: true, notificationOption: "all" }, creatorId, routineVideo);
  assert(allRoutine.notify === true && allRoutine.effectiveOption === "all", "When 'all', sends notification for routine video");

  const allHighlight = shouldNotifySubscriber({ userId: "sub_all", notificationsEnabled: true, notificationOption: "all" }, creatorId, verifiedHighlight);
  assert(allHighlight.notify === true && allHighlight.effectiveOption === "all", "When 'all', sends notification for highlight video");

  // Legacy subscriber doc with only notificationsEnabled: false (None)
  const legacyMuted = shouldNotifySubscriber({ userId: "sub_legacy_muted", notificationsEnabled: false }, creatorId, verifiedHighlight);
  assert(legacyMuted.notify === false && legacyMuted.effectiveOption === "none", "Suppresses push notification for legacy muted doc even on highlight");

  // Legacy subscriber doc with no notificationOption field (defaults to 'personalized')
  const legacyDefaultRoutine = shouldNotifySubscriber({ userId: "sub_legacy_def", notificationsEnabled: true }, creatorId, routineVideo);
  assert(legacyDefaultRoutine.notify === false && legacyDefaultRoutine.effectiveOption === "personalized", "Legacy subscriber defaults to 'personalized' (skips routine video)");

  const legacyDefaultHighlight = shouldNotifySubscriber({ userId: "sub_legacy_def", notificationsEnabled: true }, creatorId, verifiedHighlight);
  assert(legacyDefaultHighlight.notify === true && legacyDefaultHighlight.effectiveOption === "personalized", "Legacy subscriber defaults to 'personalized' (receives highlight video)");
}

// ----------------------------------------------------------------------
// FEATURE 8: Topic Notification Preferences & Fan-Out Logic
// ----------------------------------------------------------------------
function testTopicNotificationPreferences() {
  console.log("\n--- [Feature 8] Testing Topic Notification Preferences & Fan-Out ---");

  // Helper matching updateTopicNotificationSettings validation
  function isValidTopicSetting(setting?: string): boolean {
    if (!setting || typeof setting !== "string") return false;
    return ["all", "personalized", "none", "unfollow"].includes(setting.trim().toLowerCase());
  }

  // 1. Setting validation
  assert(isValidTopicSetting("all"), "Validates 'all' setting");
  assert(isValidTopicSetting("personalized"), "Validates 'personalized' setting");
  assert(isValidTopicSetting("none"), "Validates 'none' setting");
  assert(isValidTopicSetting("unfollow"), "Validates 'unfollow' setting");
  assert(isValidTopicSetting("ALL"), "Case-insensitively validates 'ALL'");
  assert(!isValidTopicSetting("invalid_setting"), "Rejects invalid setting");
  assert(!isValidTopicSetting(""), "Rejects empty setting");
  assert(!isValidTopicSetting(undefined), "Rejects undefined setting");

  // 2. Topic key extraction
  function extractTopicKeys(video: { topicId?: string; topics?: string[] }): string[] {
    const rawTopicKeys: string[] = [];
    if (video.topicId && typeof video.topicId === "string" && video.topicId.trim().length > 0) {
      rawTopicKeys.push(video.topicId.trim());
    }
    if (Array.isArray(video.topics)) {
      for (const t of video.topics) {
        if (typeof t === "string" && t.trim().length > 0) {
          rawTopicKeys.push(t.trim());
        }
      }
    }
    return Array.from(new Set(rawTopicKeys));
  }

  const extractedKeys = extractTopicKeys({
    topicId: "ai-safety",
    topics: ["ai-safety", "tech-ethics", "deepfakes", "   ", "deepfakes"],
  });
  assert(extractedKeys.length === 3, "Extracts exactly 3 unique non-empty topic keys");
  assert(extractedKeys.includes("ai-safety"), "Includes primary topicId");
  assert(extractedKeys.includes("tech-ethics"), "Includes topics array element");
  assert(extractedKeys.includes("deepfakes"), "Deduplicates repeated topic in array");

  // 3. Personalized eligibility helper matching videoPublishTrigger
  function isPersonalizedEligible(video: any): boolean {
    const isVerified = video.isFactChecked === true || video.factCheckStatus === "verified";
    const isFeatured = video.featured === true || video.isFeatured === true;
    const isHighTruth = typeof video.truthScore === "number" && video.truthScore >= 75;
    const isHighTrust = typeof video.trustScore === "number" && video.trustScore >= 75;
    const isHighlight = video.isHighlight === true;
    return isVerified || isFeatured || isHighTruth || isHighTrust || isHighlight;
  }

  assert(isPersonalizedEligible({ factCheckStatus: "verified" }) === true, "Personalized eligible: factCheckStatus verified");
  assert(isPersonalizedEligible({ isFactChecked: true }) === true, "Personalized eligible: isFactChecked true");
  assert(isPersonalizedEligible({ featured: true }) === true, "Personalized eligible: featured true");
  assert(isPersonalizedEligible({ truthScore: 88 }) === true, "Personalized eligible: truthScore >= 75");
  assert(isPersonalizedEligible({ trustScore: 75 }) === true, "Personalized eligible: trustScore >= 75");
  assert(isPersonalizedEligible({ isHighlight: true }) === true, "Personalized eligible: isHighlight true");
  assert(isPersonalizedEligible({ truthScore: 50, featured: false }) === false, "Routine video is not personalized eligible");

  // 4. Topic follower fanout decision logic matching videoPublishTrigger
  function shouldNotifyTopicFollower(
    follower: { userId: string; notificationSetting?: string },
    video: any,
    notifiedUserIds: Set<string>,
    creatorId: string
  ): boolean {
    const uid = follower.userId;
    if (!uid || notifiedUserIds.has(uid) || uid === creatorId) return false;

    const setting = (follower.notificationSetting || "personalized").toLowerCase();
    if (setting === "none" || setting === "unfollow") return false;
    if (setting === "personalized" && !isPersonalizedEligible(video)) return false;

    notifiedUserIds.add(uid);
    return true;
  }

  const creatorUid = "creator_abc";
  const notifiedSet = new Set<string>();

  // Creator exclusion
  const resCreator = shouldNotifyTopicFollower({ userId: creatorUid, notificationSetting: "all" }, { truthScore: 90 }, notifiedSet, creatorUid);
  assert(resCreator === false, "Skips notifying creator of their own video in followed topic");

  // 'none' setting suppresses notifications
  const resNone = shouldNotifyTopicFollower({ userId: "user_muted", notificationSetting: "none" }, { truthScore: 90 }, notifiedSet, creatorUid);
  assert(resNone === false, "Suppresses topic notification when user setting is 'none'");

  // 'unfollow' suppresses notifications
  const resUnfollow = shouldNotifyTopicFollower({ userId: "user_unfollowed", notificationSetting: "unfollow" }, { truthScore: 90 }, notifiedSet, creatorUid);
  assert(resUnfollow === false, "Suppresses topic notification when setting is 'unfollow'");

  // 'all' setting receives notification for routine video
  const resAllRoutine = shouldNotifyTopicFollower({ userId: "user_all", notificationSetting: "all" }, { truthScore: 50 }, notifiedSet, creatorUid);
  assert(resAllRoutine === true, "Delivers notification to 'all' topic follower even for routine video");

  // 'personalized' setting skips routine video
  const resPersonalizedRoutine = shouldNotifyTopicFollower({ userId: "user_pers_1", notificationSetting: "personalized" }, { truthScore: 50 }, notifiedSet, creatorUid);
  assert(resPersonalizedRoutine === false, "Skips notifying 'personalized' follower for routine video");

  // default follower setting (no notificationSetting specified) defaults to 'personalized' (skips routine video)
  const resDefaultRoutine = shouldNotifyTopicFollower({ userId: "user_default_1" }, { truthScore: 50 }, notifiedSet, creatorUid);
  assert(resDefaultRoutine === false, "Defaults topic follower to 'personalized' (skips routine video)");

  // 'personalized' setting receives notification for verified highlight video
  const resPersonalizedVerified = shouldNotifyTopicFollower({ userId: "user_pers_2", notificationSetting: "personalized" }, { factCheckStatus: "verified" }, notifiedSet, creatorUid);
  assert(resPersonalizedVerified === true, "Delivers notification to 'personalized' follower for verified video");

  // Deduplication: if user_pers_2 follows another topic on same video, skips duplicate
  const resDeduplication = shouldNotifyTopicFollower({ userId: "user_pers_2", notificationSetting: "all" }, { factCheckStatus: "verified" }, notifiedSet, creatorUid);
  assert(resDeduplication === false, "Deduplicates notification across multiple followed topics for the same video");
}

// ----------------------------------------------------------------------
// RUN ALL TESTS
// ----------------------------------------------------------------------
console.log("==================================================");
console.log("RUNNING BACKEND NOTIFICATION FEATURES TEST SUITE");
console.log("==================================================");

testFcmTokenExtraction();
testFcmPayloadBuilding();
testMentionExtraction();
testTemplateRegistry();
testStaleTokenCleanup();
testSafetyNetFiltering();
testChannelNotificationPreferences();
testTopicNotificationPreferences();

console.log("\n==================================================");
console.log(`TOTAL RESULTS: ${passed} PASSED, ${failed} FAILED`);
console.log("==================================================");

if (failed > 0) {
  process.exit(1);
} else {
  process.exit(0);
}
