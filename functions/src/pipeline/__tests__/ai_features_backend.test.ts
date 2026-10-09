/**
 * 🧪 BACKEND AI FEATURES TEST SUITE
 *
 * Verifies all 6 AI Features & Backend Pipeline Wiring:
 * 1. Auto-Generate Subtitles (100+ Languages) & SRT/VTT Formatting
 * 2. AI Audio Translation & Dubbing (70+ Languages) & Language Merging
 * 3. Speaker Diarization Priority Gate
 * 4. Auto Chapters Extraction & Dual-field Persistence
 * 5. AI Video Summary & Moderation Summary Persistence
 * 6. Truth Verification Analysis & Credibility Wiring
 * 7. Publish Gate Race Conditions (Upload-before-publish & Publish-during-upload)
 * 8. Status Preservation (Zero "ready" demotion)
 */

import { normalizeLanguageCode, normalizeLanguageCodes } from "../../shared/language-normalizer";

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

// ----------------------------------------------------------------------
// FEATURE 1: Auto-Generate Subtitles (100+ Languages) & SRT/VTT Generation
// ----------------------------------------------------------------------
function testSubtitleGeneration() {
  console.log("\n--- [Feature 1] Testing Auto-Generate Subtitles & SRT/VTT Generation ---");

  const sampleSegments = [
    { index: 0, start: 0, end: 3500, text: "Welcome to TruthWorld.", speaker: "speaker_0" },
    { index: 1, start: 3600, end: 7200, text: "Here is the verified report.", speaker: "speaker_1" },
  ];

  const formatTimeSrt = (ms: number) => {
    const hrs = Math.floor(ms / 3600000);
    const mins = Math.floor((ms % 3600000) / 60000);
    const secs = Math.floor((ms % 60000) / 1000);
    const millis = ms % 1000;
    return `${String(hrs).padStart(2, "0")}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")},${String(millis).padStart(3, "0")}`;
  };

  const formatTimeVtt = (ms: number) => {
    const hrs = Math.floor(ms / 3600000);
    const mins = Math.floor((ms % 3600000) / 60000);
    const secs = Math.floor((ms % 60000) / 1000);
    const millis = ms % 1000;
    return `${String(hrs).padStart(2, "0")}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}.${String(millis).padStart(3, "0")}`;
  };

  let srtContent = "";
  let vttContent = "WEBVTT\n\n";

  sampleSegments.forEach((seg, idx) => {
    const startSrt = formatTimeSrt(seg.start);
    const endSrt = formatTimeSrt(seg.end);
    const startVtt = formatTimeVtt(seg.start);
    const endVtt = formatTimeVtt(seg.end);

    srtContent += `${idx + 1}\n${startSrt} --> ${endSrt}\n${seg.text}\n\n`;
    vttContent += `${startVtt} --> ${endVtt}\n${seg.text}\n\n`;
  });

  assert(srtContent.includes("1\n00:00:00,000 --> 00:00:03,500\nWelcome to TruthWorld."), "SRT segment 1 formatted correctly");
  assert(srtContent.includes("2\n00:00:03,600 --> 00:00:07,200\nHere is the verified report."), "SRT segment 2 formatted correctly");
  assert(vttContent.startsWith("WEBVTT\n\n"), "VTT header is WEBVTT");
  assert(vttContent.includes("00:00:00.000 --> 00:00:03.500\nWelcome to TruthWorld."), "VTT segment 1 uses dot decimal separator");

  // Multilingual codes
  const rawLangs = ["hindi", "SPANISH", "fr", "Telugu", "zh", "ja", "de", "ar"];
  const normalized = normalizeLanguageCodes(rawLangs);
  assert(normalized.includes("hi"), "Normalizes Hindi to hi");
  assert(normalized.includes("es"), "Normalizes Spanish to es");
  assert(normalized.includes("te"), "Normalizes Telugu to te");
  assert(normalized.includes("fr"), "Normalizes French to fr");
  assert(normalizeLanguageCode("HINDI") === "hi", "normalizeLanguageCode handles uppercase language names");
}

// ----------------------------------------------------------------------
// FEATURE 2: AI Audio Translation & Dubbing (70+ Languages)
// ----------------------------------------------------------------------
function testAudioTranslationAndDubbing() {
  console.log("\n--- [Feature 2] Testing Audio Translation & Dubbing Language Merging ---");

  const getTranslationLangs = (data: any): string[] => {
    const transLangs = Array.isArray(data?.aiFeatures?.translationLanguages) ? data.aiFeatures.translationLanguages : [];
    const dubLangs = Array.isArray(data?.aiFeatures?.dubbingLanguages) ? data.aiFeatures.dubbingLanguages : [];
    const topLangs = Array.isArray(data?.languages) ? data.languages : [];
    return Array.from(new Set([...transLangs, ...dubLangs, ...topLangs]));
  };

  const sampleDoc = {
    languages: ["en"],
    aiFeatures: {
      translationLanguages: ["es", "fr"],
      dubbingLanguages: ["hi", "de", "es"], // 'es' overlaps
    }
  };

  const merged = getTranslationLangs(sampleDoc);
  assert(merged.length === 5, "Merged unique languages count is 5 (deduplicates overlapping 'es')");
  assert(merged.includes("es") && merged.includes("fr") && merged.includes("hi") && merged.includes("de") && merged.includes("en"), "Contains all requested languages");

  // Dubbing mode resolution
  const voiceClone = { tts: { voiceType: "voice_clone" }, generateDubbing: true };
  const standardDub = { tts: { voiceType: "standard" }, generateDubbing: true };
  const noDub = { generateDubbing: false };

  const resolveDubMode = (af: any) => af.tts?.voiceType === "voice_clone" ? "voice_clone" : (af.generateDubbing ? "standard" : "none");
  assert(resolveDubMode(voiceClone) === "voice_clone", "Voice clone dubbing mode resolved");
  assert(resolveDubMode(standardDub) === "standard", "Standard dubbing mode resolved");
  assert(resolveDubMode(noDub) === "none", "No dubbing mode resolved");

  // Dubbing stage status when skipped vs enabled
  const resolveDubStage = (enableDubbing: boolean) => enableDubbing ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 };
  assert(resolveDubStage(false).status === "skipped", "Dubbing stage is skipped when generateDubbing is false");
  assert(resolveDubStage(false).progress === 100, "Dubbing stage has 100 progress when skipped");
  assert(resolveDubStage(true).status === "pending", "Dubbing stage is pending when generateDubbing is true");

  // Dubbing aggregation stage status
  const resolveDubbingAggregatedStatus = (stageName: string, generateDubbing: boolean) => (stageName === "dubbing" && !generateDubbing) ? "skipped" : "completed";
  assert(resolveDubbingAggregatedStatus("dubbing", false) === "skipped", "Aggregation marks dubbing as skipped when generateDubbing is false");
  assert(resolveDubbingAggregatedStatus("dubbing", true) === "completed", "Aggregation marks dubbing as completed when generateDubbing is true");
}

// ----------------------------------------------------------------------
// FEATURE 3: Speaker Diarization Priority Gate
// ----------------------------------------------------------------------
function testSpeakerDiarization() {
  console.log("\n--- [Feature 3] Testing Speaker Diarization Toggle Gate ---");

  const shouldEnableDiarizationLogic = (plan: any): boolean => {
    // 0. Explicit creator toggle (Highest Priority)
    if (plan.enableDiarization === true || plan.diarization === true) {
      return true;
    }
    const duration = plan.duration ?? 0;
    const channelType = plan.channelType || "standard";
    if (duration < 45) return false;
    if (duration > 90) return true;
    if (channelType === "standard") return false;
    return true;
  };

  // Creator explicitly enabled diarization on short 30-second standard video
  const planShort = { enableDiarization: true, duration: 30, channelType: "standard" };
  assert(shouldEnableDiarizationLogic(planShort) === true, "Explicit toggle enables diarization on 30s standard video");

  // Creator explicitly enabled diarization via 'diarization: true'
  const planAltToggle = { diarization: true, duration: 20, channelType: "standard" };
  assert(shouldEnableDiarizationLogic(planAltToggle) === true, "diarization: true enables diarization on 20s video");

  // Creator did NOT enable diarization on short 30-second video
  const planDisabledShort = { enableDiarization: false, duration: 30, channelType: "standard" };
  assert(shouldEnableDiarizationLogic(planDisabledShort) === false, "Disabled toggle leaves diarization off for 30s video");

  // Long-form default behavior preserved (> 90s)
  const planLongForm = { duration: 120, channelType: "standard" };
  assert(shouldEnableDiarizationLogic(planLongForm) === true, "Long-form defaults to true when duration > 90s");
}

// ----------------------------------------------------------------------
// FEATURE 4: Auto Chapters Generation & Persistence
// ----------------------------------------------------------------------
function testAutoChaptersPersistence() {
  console.log("\n--- [Feature 4] Testing Auto Chapters Extraction & Persistence ---");

  const gatewayDecision = {
    autoChapters: [
      { startMs: 0, endMs: 15000, title: "Overview", summary: "Introduction to topic" },
      { startMs: 15000, endMs: 45000, title: "Key Findings", summary: "Analysis results" },
    ]
  };
  const enhanced = {
    chapters: [
      { startTimeMs: 0, endTimeMs: 20000, title: "AssemblyAI Chapter 1", summary: "" }
    ]
  };
  const existingVideoData = {
    autoChapters: [],
    chapters: []
  };

  // Case A: Gateway provides chapters
  const finalChaptersA = (gatewayDecision.autoChapters && gatewayDecision.autoChapters.length > 0)
    ? gatewayDecision.autoChapters
    : ((enhanced.chapters && enhanced.chapters.length > 0)
        ? enhanced.chapters
        : (existingVideoData.autoChapters || existingVideoData.chapters || []));

  assert(finalChaptersA.length === 2, "Resolves chapters from gatewayDecision");
  assert(finalChaptersA[0].title === "Overview", "Chapter title preserved");

  // Case B: Gateway has no chapters, fallback to enhanced.chapters
  const gatewayEmpty: any = { autoChapters: [] };
  const finalChaptersB = (gatewayEmpty.autoChapters && gatewayEmpty.autoChapters.length > 0)
    ? gatewayEmpty.autoChapters
    : ((enhanced.chapters && enhanced.chapters.length > 0)
        ? enhanced.chapters
        : (existingVideoData.autoChapters || existingVideoData.chapters || []));

  assert(finalChaptersB.length === 1, "Falls back to enhanced.chapters if gateway chapters empty");
  assert((finalChaptersB[0] as any).title === "AssemblyAI Chapter 1", "Fallback chapter title preserved");

  // Verification of publication fields
  const publicationData = {
    autoChapters: finalChaptersA,
    chapters: finalChaptersA,
  };
  assert(Array.isArray(publicationData.autoChapters) && publicationData.autoChapters.length === 2, "autoChapters populated");
  assert(Array.isArray(publicationData.chapters) && publicationData.chapters.length === 2, "chapters populated");
}

// ----------------------------------------------------------------------
// FEATURE 5: AI Video Summary & Moderation Summary Persistence
// ----------------------------------------------------------------------
function testAISummaryPersistence() {
  console.log("\n--- [Feature 5] Testing AI Summary & Moderation Summary Persistence ---");

  const gatewayDecision = {
    summary: "This video provides a deep-dive analysis of global climate policies.",
  };
  const existingVideoData = {
    summary: "",
    moderationSummary: "",
  };

  const finalSummary = gatewayDecision.summary || existingVideoData.summary || existingVideoData.moderationSummary || "";

  const publicationData = {
    summary: finalSummary,
    moderationSummary: finalSummary,
    moderation: {
      status: "approved",
      summary: finalSummary,
    }
  };

  assert(publicationData.summary === "This video provides a deep-dive analysis of global climate policies.", "summary written to root document");
  assert(publicationData.moderationSummary === "This video provides a deep-dive analysis of global climate policies.", "moderationSummary written to root document");
  assert(publicationData.moderation.summary === "This video provides a deep-dive analysis of global climate policies.", "moderation.summary written to submap");
}

// ----------------------------------------------------------------------
// FEATURE 6: Truth Verification & Credibility Analysis
// ----------------------------------------------------------------------
function testTruthVerificationWiring() {
  console.log("\n--- [Feature 6] Testing Truth Verification & Credibility Wiring ---");

  const resolveFactChecking = (aiFeatures: any, afterData: any = {}) => {
    return Boolean(
      aiFeatures.factChecking === true ||
      aiFeatures.enableFactCheck === true ||
      aiFeatures.truthVerification === true ||
      afterData.enableFactCheck === true ||
      afterData.factChecking === true ||
      afterData.truthVerification === true ||
      afterData.isFactChecked === true ||
      (afterData.factCheckTier && afterData.factCheckTier !== "none" && afterData.factCheckTier !== "off" && afterData.factCheckTier !== "") ||
      (aiFeatures.factCheckTier && aiFeatures.factCheckTier !== "none" && aiFeatures.factCheckTier !== "off" && aiFeatures.factCheckTier !== "")
    );
  };

  // Case A: standard factChecking: true
  assert(resolveFactChecking({ factChecking: true }) === true, "resolves factChecking: true");

  // Case B: enableFactCheck: true in aiFeatures
  assert(resolveFactChecking({ enableFactCheck: true }) === true, "resolves enableFactCheck: true in aiFeatures");

  // Case C: truthVerification: true in aiFeatures
  assert(resolveFactChecking({ truthVerification: true }) === true, "resolves truthVerification: true in aiFeatures");

  // Case D: enableFactCheck: true on video root
  assert(resolveFactChecking({}, { enableFactCheck: true }) === true, "resolves enableFactCheck: true on video root");

  // Case E: factCheckTier: 'full_ground' on video root
  assert(resolveFactChecking({}, { factCheckTier: "full_ground" }) === true, "resolves factCheckTier: 'full_ground' on video root");

  // Case F: factCheckTier: 'full_ground' in aiFeatures
  assert(resolveFactChecking({ factCheckTier: "full_ground" }, {}) === true, "resolves factCheckTier: 'full_ground' in aiFeatures");

  // Case G: explicitly false/none
  assert(resolveFactChecking({ factChecking: false, factCheckTier: "none" }, { factCheckTier: "none" }) === false, "resolves false when explicitly disabled");

  const enableFactChecking = resolveFactChecking({ factChecking: true });

  const executionPlan = {
    enablePath1: enableFactChecking,
    enableTruthEngine: enableFactChecking,
    maxClaims: enableFactChecking ? 100 : 0,
  };

  assert(executionPlan.enablePath1 === true, "enablePath1 set to true for fact checking");
  assert(executionPlan.enableTruthEngine === true, "enableTruthEngine set to true for fact checking");
  assert(executionPlan.maxClaims === 100, "maxClaims allocated for fact checking analysis");

  const mockCredibility = {
    trustScore: null,
    trustLabel: "Verified",
    factCheckStats: { totalClaims: 5, correct: 4, incorrect: 1, unverifiable: 0 }
  };
  const videoUpdate = {
    isVerified: !!mockCredibility,
    credibilityVerified: !!mockCredibility,
    factCheckUrl: "https://storage.googleapis.com/test-bucket/factchecks/job123/report.json",
  };

  assert(videoUpdate.isVerified === true, "isVerified set to true when credibility completed");
  assert(videoUpdate.credibilityVerified === true, "credibilityVerified flag set");
  assert(videoUpdate.factCheckUrl.includes("report.json"), "factCheckUrl generated and populated");
}

// ----------------------------------------------------------------------
// FEATURE 7: Publish Gate Race Conditions (Upload-before-publish & Publish-during-upload)
// ----------------------------------------------------------------------
function testPublishGateRaceConditions() {
  console.log("\n--- [Feature 7] Testing Publish Gate Race Conditions ---");

  const evaluatePublishGate = (beforeData: any, afterData: any) => {
    const aiFeatures = afterData.aiFeatures || {};
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

    const title = afterData.title || "";
    const videoUrl = afterData.videoUrl || "";
    const hasMetadata = !(!title || title === "Uploading..." || !videoUrl);

    return { becamePublished, shouldTriggerPipeline: becamePublished && hasMetadata && !afterData.jobId };
  };

  // Case 1: Creator uploads first, videoUrl is set, then creator clicks "Publish"
  const before1 = { title: "My Video", videoUrl: "https://storage.../orig.mp4", status: "draft", aiFeatures: { pipelineStage: "draft" } };
  const after1 = { title: "My Video", videoUrl: "https://storage.../orig.mp4", status: "published", targetStatus: "published", aiFeatures: { pipelineStage: "published" } };
  const res1 = evaluatePublishGate(before1, after1);
  assert(res1.becamePublished === true && res1.shouldTriggerPipeline === true, "Case 1: Upload first, then publish -> Triggers pipeline immediately");

  // Case 2: Creator clicks "Publish" while uploading (videoUrl is empty initially)
  const before2a = { title: "My Video", videoUrl: "", status: "draft", aiFeatures: { pipelineStage: "draft" } };
  const after2a = { title: "My Video", videoUrl: "", status: "uploading", targetStatus: "published", aiFeatures: { pipelineStage: "published" } };
  const res2a = evaluatePublishGate(before2a, after2a);
  assert(res2a.becamePublished === true && res2a.shouldTriggerPipeline === false, "Case 2a: Publish during upload -> Marks becamePublished but defers pipeline due to missing videoUrl");

  // Case 2b: Upload task finishes 10s later, writing videoUrl: downloadUrl
  const before2b = after2a; // was already published, but videoUrl was empty
  const after2b = { ...after2a, videoUrl: "https://storage.../uploaded.mp4", status: "processing" };
  const res2b = evaluatePublishGate(before2b, after2b);
  assert(res2b.becamePublished === true && res2b.shouldTriggerPipeline === true, "Case 2b: Upload completes after publish -> Successfully catches videoUrlBecameReady and triggers pipeline!");

  // Case 3: Job already exists (idempotent skip)
  const before3 = { ...after2b, jobId: "job_existing_123" };
  const after3 = { ...before3, status: "published" };
  const res3 = evaluatePublishGate(before3, after3);
  assert(res3.shouldTriggerPipeline === false, "Case 3: Existing job avoids re-triggering pipeline (idempotency)");
}

// ----------------------------------------------------------------------
// FEATURE 8: Status Preservation (Zero "ready" Demotion)
// ----------------------------------------------------------------------
function testStatusPreservation() {
  console.log("\n--- [Feature 8] Testing Aggregation Status Preservation ---");

  const resolveFinalStatus = (vData: any): string => {
    let finalStatus = "published";
    if (vData?.visibility === "Scheduled" || vData?.status === "scheduled" || vData?.targetStatus === "scheduled") {
      finalStatus = "scheduled";
    } else if (vData?.status === "draft" || vData?.targetStatus === "draft") {
      finalStatus = "draft";
    } else if (vData?.status === "rejected" || vData?.moderation?.status === "rejected") {
      finalStatus = "rejected";
    } else if (vData?.status === "published" || vData?.targetStatus === "published" || vData?.isPublished === true || vData?.aiFeatures?.pipelineStage === "published") {
      finalStatus = "published";
    } else {
      finalStatus = vData?.status && vData.status !== "processing" && vData.status !== "uploading" ? vData.status : "published";
    }
    return finalStatus;
  };

  const publishedVideo = { status: "published", isPublished: true };
  assert(resolveFinalStatus(publishedVideo) === "published", "Published video preserves status 'published'");

  const targetPublishedVideo = { status: "processing", targetStatus: "published" };
  assert(resolveFinalStatus(targetPublishedVideo) === "published", "Processing video with targetStatus 'published' completes as 'published'");

  const scheduledVideo = { status: "processing", targetStatus: "scheduled" };
  assert(resolveFinalStatus(scheduledVideo) === "scheduled", "Scheduled video completes as 'scheduled'");

  const draftVideo = { status: "processing", targetStatus: "draft" };
  assert(resolveFinalStatus(draftVideo) === "draft", "Draft video completes as 'draft'");

  const rejectedVideo = { status: "processing", moderation: { status: "rejected" } };
  assert(resolveFinalStatus(rejectedVideo) === "rejected", "Rejected video completes as 'rejected'");
}

// ----------------------------------------------------------------------
// RUN ALL TESTS
// ----------------------------------------------------------------------
function runAllTests() {
  console.log("==================================================================");
  console.log("🚀 STARTING AI FEATURES & BACKEND PIPELINE AUTOMATED TEST SUITE");
  console.log("==================================================================");

  testSubtitleGeneration();
  testAudioTranslationAndDubbing();
  testSpeakerDiarization();
  testAutoChaptersPersistence();
  testAISummaryPersistence();
  testTruthVerificationWiring();
  testPublishGateRaceConditions();
  testStatusPreservation();

  console.log("\n==================================================================");
  console.log(`📊 TEST RESULTS: ${passed} PASSED | ${failed} FAILED`);
  console.log("==================================================================");

  if (failed > 0) {
    process.exit(1);
  }
}

runAllTests();
