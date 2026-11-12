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
            const isHighlight = video.isHighlight === true;
    const isPersonalizedEligible = isVerified || isFeatured || isHighlight;

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
  const routineVideo = { title: "Routine vlog", isFactChecked: false, featured: false };
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
            const isHighlight = video.isHighlight === true;
    return isVerified || isFeatured || isHighlight;
  }

  assert(isPersonalizedEligible({ factCheckStatus: "verified" }) === true, "Personalized eligible: factCheckStatus verified");
  assert(isPersonalizedEligible({ isFactChecked: true }) === true, "Personalized eligible: isFactChecked true");
  assert(isPersonalizedEligible({ featured: true }) === true, "Personalized eligible: featured true");
      assert(isPersonalizedEligible({ isHighlight: true }) === true, "Personalized eligible: isHighlight true");
  assert(isPersonalizedEligible({ featured: false }) === false, "Routine video is not personalized eligible");

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
// FEATURE 9: Video Publish Gate & Multi-Source Subscriber Fan-Out Union
// ----------------------------------------------------------------------
function testSubscriberNotificationGateAndMultiCollectionFanout() {
  console.log("\n--- [Feature 9] Testing Video Publish Gate & Multi-Source Subscriber Fan-Out ---");

  // Replicates video publish gate logic in onVideoPublished
  function evaluateVideoNotificationGate(beforeData: any, afterData: any) {
    const aiFeatures = afterData?.aiFeatures || {};
    const beforeAiFeatures = beforeData?.aiFeatures || {};

    const isPublishRequested =
      aiFeatures.pipelineStage === "published" ||
      afterData.status === "published" ||
      afterData.targetStatus === "published" ||
      afterData.published === true ||
      (afterData.status === "processing" && !afterData.jobId);

    const wasPublishRequested =
      beforeAiFeatures.pipelineStage === "published" ||
      beforeData?.status === "published" ||
      beforeData?.targetStatus === "published" ||
      beforeData?.published === true;

    const videoUrlBecameReady = !beforeData?.videoUrl && !!afterData.videoUrl;
    const titleBecameReady =
      (beforeData?.title === "Uploading..." || !beforeData?.title) &&
      (afterData.title && afterData.title !== "Uploading...");

    const becamePublished =
      (!wasPublishRequested && isPublishRequested) ||
      (!afterData.jobId && isPublishRequested && (videoUrlBecameReady || titleBecameReady || afterData.status === "processing"));

    const wasApproved = beforeData?.moderation?.status === "approved";
    const isApproved =
      afterData.moderation?.status === "approved" ||
      afterData.isModerated === true ||
      afterData.trustedModerationBypass === true ||
      (afterData.moderation?.status === undefined && afterData.status !== "rejected");
    const becameApproved = !wasApproved && isApproved;

    const isCurrentlyPublished =
      (afterData.status === "published" ||
        afterData.published === true ||
        afterData.isPublished === true ||
        aiFeatures.pipelineStage === "published") &&
      afterData.status !== "processing" &&
      afterData.status !== "uploading" &&
      afterData.status !== "draft" &&
      afterData.status !== "scheduled" &&
      afterData.status !== "rejected";

    const wasPublished =
      beforeData?.status === "published" ||
      beforeData?.published === true ||
      beforeData?.isPublished === true ||
      beforeAiFeatures.pipelineStage === "published";

    const statusJustBecamePublished = !wasPublished && isCurrentlyPublished;
    const notificationsNotSentYet = !afterData.notificationsSent;

    const shouldSendNotifications =
      isCurrentlyPublished &&
      isApproved &&
      notificationsNotSentYet &&
      (statusJustBecamePublished || becameApproved || becamePublished);

    return shouldSendNotifications;
  }

  // 1. Pipeline aggregation finishes: processing -> published (already approved)
  const processingToPublished = evaluateVideoNotificationGate(
    { status: "processing", targetStatus: "published", moderation: { status: "approved" }, notificationsSent: false },
    { status: "published", targetStatus: "published", moderation: { status: "approved" }, notificationsSent: false }
  );
  assert(processingToPublished === true, "Pipeline aggregation transition (processing -> published) triggers notifications");

  // 2. Video published, moderation approves afterward
  const pendingToApprovedWhenPublished = evaluateVideoNotificationGate(
    { status: "published", moderation: { status: "pending" }, notificationsSent: false },
    { status: "published", moderation: { status: "approved" }, notificationsSent: false }
  );
  assert(pendingToApprovedWhenPublished === true, "Moderation approval for published video triggers notifications");

  // 3. Video still processing: must NOT trigger notifications prematurely
  const stillProcessingApproved = evaluateVideoNotificationGate(
    { status: "processing", moderation: { status: "pending" }, notificationsSent: false },
    { status: "processing", moderation: { status: "approved" }, notificationsSent: false }
  );
  assert(stillProcessingApproved === false, "Video still processing does not trigger notifications prematurely");

  // 4. Notifications already sent: must NOT re-send
  const alreadySent = evaluateVideoNotificationGate(
    { status: "processing", moderation: { status: "approved" }, notificationsSent: true },
    { status: "published", moderation: { status: "approved" }, notificationsSent: true }
  );
  assert(alreadySent === false, "Does not re-send notifications if notificationsSent is true");

  // 5. Rejected video: must NOT send
  const rejectedVideo = evaluateVideoNotificationGate(
    { status: "processing", moderation: { status: "pending" }, notificationsSent: false },
    { status: "rejected", moderation: { status: "rejected" }, notificationsSent: false }
  );
  assert(rejectedVideo === false, "Rejected video does not trigger subscriber notifications");

  // 6. Multi-collection subscriber union resolution
  function resolveSubscribersFromSources(
    primarySubDocs: Array<{ id: string; data: any }>,
    legacySubDocs: Array<{ id: string; data: any }>,
    creatorId: string,
    isPersonalizedEligible: boolean
  ) {
    const notifiedUserIds = new Set<string>();
    notifiedUserIds.add(creatorId);
    const notifications: Array<{ userId: string; option: string }> = [];

    const processDocs = (docs: Array<{ id: string; data: any }>) => {
      docs.forEach(doc => {
        const data = doc.data;
        const userId = data.userId || doc.id;
        if (!userId || notifiedUserIds.has(userId) || userId === creatorId) return;

        notifiedUserIds.add(userId);

        const notificationsEnabled = data.notificationsEnabled !== false;
        const effectiveOption = (
          data.notificationOption ||
          data.notificationPreference ||
          (!notificationsEnabled ? "none" : "personalized")
        ).toLowerCase();

        if (notificationsEnabled && effectiveOption !== "none" && (effectiveOption === "all" || isPersonalizedEligible)) {
          notifications.push({ userId, option: effectiveOption });
        }
      });
    };

    processDocs(primarySubDocs);
    processDocs(legacySubDocs);

    return { totalNotified: notifications.length, notifications, uniqueUsersCount: notifiedUserIds.size - 1 };
  }

  // Channel with subscribers across channels/{id}/subscribers and legacy subscriptions
  const primarySubs = [
    { id: "user_all_1", data: { notificationOption: "all", notificationsEnabled: true } },
    { id: "user_pers_1", data: { notificationOption: "personalized", notificationsEnabled: true } },
    { id: "user_none_1", data: { notificationOption: "none", notificationsEnabled: false } },
    { id: "user_both", data: { userId: "user_both", notificationOption: "all", notificationsEnabled: true } },
  ];

  const legacySubs = [
    { id: "ch_user_both", data: { userId: "user_both", notificationOption: "all", notificationsEnabled: true } },
    { id: "ch_user_legacy_only", data: { userId: "user_legacy_only", notificationOption: "all", notificationsEnabled: true } },
  ];

  // Routine video (isPersonalizedEligible = false)
  const routineResult = resolveSubscribersFromSources(primarySubs, legacySubs, "creator_1", false);
  assert(routineResult.uniqueUsersCount === 5, "Resolves all 5 unique subscribers across both collections");
  assert(routineResult.totalNotified === 3, "Notifies exactly the 3 users with option 'all' for routine video (including legacy-only)");
  assert(routineResult.notifications.some(n => n.userId === "user_legacy_only"), "Includes subscriber present only in legacy collection");
  assert(routineResult.notifications.some(n => n.userId === "user_all_1"), "Includes subscriber present only in primary channel subcollection");
  assert(routineResult.notifications.filter(n => n.userId === "user_both").length === 1, "Deduplicates subscriber present in both collections");

  // Highlight video (isPersonalizedEligible = true)
  const highlightResult = resolveSubscribersFromSources(primarySubs, legacySubs, "creator_1", true);
  assert(highlightResult.totalNotified === 4, "Notifies 4 users (3 'all' + 1 'personalized') for highlight video");
  assert(!highlightResult.notifications.some(n => n.userId === "user_none_1"), "Strictly respects 'none' mute setting even on highlight");
}

// ----------------------------------------------------------------------
// FEATURE 10: Triple Notification Prevention & Per-Platform Deduplication
// ----------------------------------------------------------------------
function testTripleNotificationPrevention() {
  console.log("\n--- [Feature 10] Testing Triple Notification Prevention & Platform Pruning ---");

  interface CandidateTokenEntry {
    deviceId: string;
    token: string;
    app: string;
    platform: string;
    updatedAt: number;
  }

  function resolveTokensToPush(fcmTokensMap: Record<string, any>, targetApp: string): {
    tokensToSend: string[];
    prunedDeviceIds: string[];
  } {
    const candidateEntries: CandidateTokenEntry[] = [];
    const duplicateDeviceIdsToRemove: string[] = [];
    const seenTokenStrings = new Set<string>();

    for (const [deviceId, val] of Object.entries(fcmTokensMap)) {
      let tokenStr = "";
      let tokenApp = "";
      let platform = "android";
      let updatedAt = 0;

      if (typeof val === "string") {
        tokenStr = val.trim();
      } else if (val && typeof val === "object") {
        if (typeof val.token === "string") tokenStr = val.token.trim();
        if (typeof val.app === "string") tokenApp = val.app.trim().toLowerCase();
        else if (typeof val.appFlavor === "string") tokenApp = val.appFlavor.trim().toLowerCase();
        if (typeof val.platform === "string") platform = val.platform.trim().toLowerCase();
        if (typeof val.updatedAt === "number") updatedAt = val.updatedAt;
      }

      if (!tokenApp) {
        if (deviceId.startsWith("studio_")) tokenApp = "studio";
        else if (deviceId.startsWith("admin_")) tokenApp = "admin";
        else if (deviceId.startsWith("advertiser_")) tokenApp = "advertiser";
        else if (deviceId.startsWith("app_")) tokenApp = "app";
      }

      if (tokenStr.length === 0) continue;

      if (targetApp !== "all") {
        if (tokenApp) {
          if (tokenApp !== targetApp) continue;
        } else {
          if (targetApp !== "app") continue;
        }
      }

      if (seenTokenStrings.has(tokenStr)) {
        duplicateDeviceIdsToRemove.push(deviceId);
        continue;
      }
      seenTokenStrings.add(tokenStr);

      candidateEntries.push({
        deviceId,
        token: tokenStr,
        app: tokenApp || "app",
        platform: platform || "android",
        updatedAt,
      });
    }

    const groupMap = new Map<string, CandidateTokenEntry[]>();
    for (const entry of candidateEntries) {
      const groupKey = `${entry.platform}_${entry.app}`;
      const group = groupMap.get(groupKey) || [];
      group.push(entry);
      groupMap.set(groupKey, group);
    }

    const tokensToSend: string[] = [];
    for (const [, entries] of groupMap.entries()) {
      entries.sort((a, b) => b.updatedAt - a.updatedAt);
      tokensToSend.push(entries[0].token);
      for (let i = 1; i < entries.length; i++) {
        duplicateDeviceIdsToRemove.push(entries[i].deviceId);
      }
    }

    return { tokensToSend, prunedDeviceIds: duplicateDeviceIdsToRemove };
  }

  // Case 1: Exactly 3 Android tokens accumulated on consumer app (e.g. 3 reinstalls on user device)
  const threeAccumulatedTokens = {
    "app_uuid_old_1": { token: "fcm_token_day1", platform: "android", app: "app", updatedAt: 1000 },
    "app_uuid_old_2": { token: "fcm_token_day2", platform: "android", app: "app", updatedAt: 2000 },
    "app_uuid_active": { token: "fcm_token_day3", platform: "android", app: "app", updatedAt: 3000 },
  };

  const res1 = resolveTokensToPush(threeAccumulatedTokens, "app");
  assert(res1.tokensToSend.length === 1, "Reduces 3 accumulated Android app tokens to exactly 1 active token");
  assert(res1.tokensToSend[0] === "fcm_token_day3", "Selects the newest active token (fcm_token_day3)");
  assert(res1.prunedDeviceIds.length === 2, "Prunes the 2 superseded stale tokens from Firestore");
  assert(res1.prunedDeviceIds.includes("app_uuid_old_1"), "Pruned app_uuid_old_1");
  assert(res1.prunedDeviceIds.includes("app_uuid_old_2"), "Pruned app_uuid_old_2");

  // Case 2: Exactly 3 Android tokens accumulated on Creator Studio
  const threeStudioTokens = {
    "studio_uuid_v1": { token: "studio_tok_v1", platform: "android", app: "studio", updatedAt: 100 },
    "studio_uuid_v2": { token: "studio_tok_v2", platform: "android", app: "studio", updatedAt: 200 },
    "studio_uuid_v3": { token: "studio_tok_v3", platform: "android", app: "studio", updatedAt: 300 },
  };

  const resStudio = resolveTokensToPush(threeStudioTokens, "studio");
  assert(resStudio.tokensToSend.length === 1, "Reduces 3 accumulated Studio tokens to exactly 1 active token");
  assert(resStudio.tokensToSend[0] === "studio_tok_v3", "Selects newest Studio token (studio_tok_v3)");
  assert(resStudio.prunedDeviceIds.length === 2, "Prunes the 2 older Studio tokens");

  // Case 3: Distinct platforms (Android + iOS + Web) remain active simultaneously
  const multiPlatform = {
    "app_android": { token: "tok_android", platform: "android", app: "app", updatedAt: 500 },
    "app_ios": { token: "tok_ios", platform: "ios", app: "app", updatedAt: 500 },
    "app_web": { token: "tok_web", platform: "web", app: "app", updatedAt: 500 },
  };

  const resMulti = resolveTokensToPush(multiPlatform, "app");
  assert(resMulti.tokensToSend.length === 3, "Keeps active token across distinct platforms (Android, iOS, Web)");
  assert(resMulti.prunedDeviceIds.length === 0, "Does not prune tokens on different platforms");

  // Case 4: Entity collapse key resolution
  function resolveEntityCollapseKey(type: string, metadata?: Record<string, any>, fallbackId = "notif_123"): string {
    if (type === "new_follower" || type === "new_subscriber") {
      const chId = metadata?.channelId || "";
      const subId = metadata?.subscriberId || "";
      if (chId && subId) return `sub_${chId}_${subId}`;
    }
    if (metadata?.videoId) return `video_${metadata.videoId}`;
    if (metadata?.postId) return `post_${metadata.postId}`;
    if (metadata?.commentId) return `comment_${metadata.commentId}`;
    return fallbackId;
  }

  assert(
    resolveEntityCollapseKey("new_follower", { channelId: "ch_99", subscriberId: "user_vicky" }) === "sub_ch_99_user_vicky",
    "Resolves deterministic collapse tag sub_ch_99_user_vicky for new_follower"
  );
  assert(
    resolveEntityCollapseKey("comment", { commentId: "comm_77" }) === "comment_comm_77",
    "Resolves deterministic collapse tag comment_comm_77 for comment"
  );
  assert(
    resolveEntityCollapseKey("new_community_post", { postId: "post_55" }) === "post_post_55",
    "Resolves deterministic collapse tag post_post_55 for community post"
  );
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
testSubscriberNotificationGateAndMultiCollectionFanout();
testTripleNotificationPrevention();

console.log("\n==================================================");
console.log(`TOTAL RESULTS: ${passed} PASSED, ${failed} FAILED`);
console.log("==================================================");

if (failed > 0) {
  process.exit(1);
} else {
  process.exit(0);
}
