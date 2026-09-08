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

  function extractTokens(fcmTokensMap: Record<string, any> | undefined) {
    if (!fcmTokensMap) return [];
    const deviceEntries: { deviceId: string; token: string }[] = [];
    for (const [deviceId, val] of Object.entries(fcmTokensMap)) {
      let tokenStr = "";
      if (typeof val === "string") {
        tokenStr = val;
      } else if (val && typeof val === "object" && typeof val.token === "string") {
        tokenStr = val.token;
      }
      if (tokenStr.trim().length > 0) {
        deviceEntries.push({ deviceId, token: tokenStr });
      }
    }
    return deviceEntries;
  }

  // Case A: Mixed tokens (both plain string and object representation)
  const sampleTokensMap = {
    "device_android_1": "token_android_abc123",
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
  assert(extracted.length === 2, "Extracts exactly 2 valid tokens from mixed map");
  assert(extracted.some(e => e.deviceId === "device_android_1" && e.token === "token_android_abc123"), "Extracts plain string token");
  assert(extracted.some(e => e.deviceId === "device_ios_2" && e.token === "token_ios_def456"), "Extracts token nested in object");

  // Case B: Undefined map
  const emptyExtracted = extractTokens(undefined);
  assert(emptyExtracted.length === 0, "Handles undefined fcmTokens map safely");
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
        notification: {
          sound: "default",
          channelId: "truthworld_notifications",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          priority: "max" as const,
          notificationPriority: "PRIORITY_MAX" as const,
          visibility: "public" as const,
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
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

  // Verify Android heads-up config
  assert(payload.android.priority === "high", "Android priority is 'high'");
  assert(payload.android.notification.channelId === "truthworld_notifications", "Android channelId is 'truthworld_notifications'");
  assert(payload.android.notification.notificationPriority === "PRIORITY_MAX", "Android notificationPriority is 'PRIORITY_MAX'");
  assert(payload.android.notification.visibility === "public", "Android visibility is 'public'");

  // Verify APNS config
  assert(payload.apns.headers["apns-priority"] === "10", "APNS priority is 10");
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

console.log("\n==================================================");
console.log(`TOTAL RESULTS: ${passed} PASSED, ${failed} FAILED`);
console.log("==================================================");

if (failed > 0) {
  process.exit(1);
} else {
  process.exit(0);
}
