/**
 * 🚀 PUBLISH-GATED PIPELINE TRIGGER
 *
 * Feature: Video Processing begins ONLY when Creator clicks "Publish"
 *
 * Scenarios:
 *   A. First-time publish (becamePublished) → Create job + start full speculative pipeline
 *   B. Re-language (languagesChanged)      → Trigger Path 2 for additional languages
 *   C. Re-publish (job already exists)     → Idempotent skip
 *   D. Approved & Published                → Fan-out subscriber notifications
 *   E. Fact-Check Dispute Submitted        → Dispatch credibility re-evaluation via Pub/Sub
 */

import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { v4 as uuidv4 } from "uuid";
import { notifyUser } from "../notifications/notifications";
import { notifyMentions } from "../notifications/triggers";
import { ExecutionPlan } from "../pipeline/types";
import { logger } from "../pipeline/utils/logger";
import { normalizeLanguageCode, normalizeLanguageCodes } from "../shared/language-normalizer";

export const onVideoPublished = onDocumentUpdated(
  {
    document: "videos/{videoId}",
    region: "asia-south1",
    retry: true,
    memory: "512MiB",
    maxInstances: 20,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const videoId = event.params.videoId;
    if (!videoId || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
      logger.error("[PublishGate] Invalid videoId detected:", { videoId });
      return;
    }

    if (!afterData) return;

    const aiFeatures = afterData.aiFeatures || {};
    const beforeAiFeatures = beforeData?.aiFeatures || {};

    // ─── GATE 1: Detect if video is requested to be published or ready for pipeline ───
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

    // ─── GATE 2: Detect language changes on already-published video ──────────
    const getTranslationLangs = (data: any): string[] => {
      const transLangs = Array.isArray(data?.aiFeatures?.translationLanguages) ? data.aiFeatures.translationLanguages : [];
      const dubLangs = Array.isArray(data?.aiFeatures?.dubbingLanguages) ? data.aiFeatures.dubbingLanguages : [];
      const topLangs = Array.isArray(data?.languages) ? data.languages : [];
      return Array.from(new Set([...transLangs, ...dubLangs, ...topLangs]));
    };
    const isAlreadyPublished = isPublishRequested;
    const languagesChanged =
      isAlreadyPublished &&
      JSON.stringify(getTranslationLangs(beforeData)) !== JSON.stringify(getTranslationLangs(afterData));

    // ─── GATE 2.5: Detect if moderation status just became approved ──────────
    const wasApproved = beforeData?.moderation?.status === "approved";
    const isApproved = afterData.moderation?.status === "approved";
    const becameApproved = !wasApproved && isApproved;
    const isPublished = aiFeatures.pipelineStage === "published";
    const notificationsNotSentYet = !afterData.notificationsSent;

    const shouldSendNotifications = isPublished && isApproved && notificationsNotSentYet && (becamePublished || becameApproved);

    // ─── GATE 2.6: Detect if status or moderation status became rejected ─────
    const wasRejected = beforeData?.status === "rejected" || beforeData?.moderation?.status === "rejected";
    const isRejected = afterData.status === "rejected" || afterData.moderation?.status === "rejected";
    const becameRejected = !wasRejected && isRejected;

    if (becameRejected && !afterData.rejectionNotified) {
      const uploaderId = afterData.userId || afterData.ownerId || afterData.uploaderId;
      if (uploaderId) {
        const reason = afterData.rejectionReason || afterData.moderation?.reason || "Content violates Community Guidelines";
        const title = afterData.title && afterData.title !== "Uploading..." ? afterData.title : "Untitled Video";
        const channelId = afterData.channelId || `channel_${uploaderId}`;
        notifyUser({
          userId: uploaderId,
          type: "verification_result",
          severity: "priority",
          title: `Video Moderation Rejected: "${title}"`,
          message: `Your video "${title}" was rejected: ${reason}. Please update or replace your video in Studio to comply with Truthworld guidelines.`,
          actionUrl: "/studio",
          metadata: {
            videoId,
            channelId,
            videoTitle: title,
            thumbnailUrl: afterData.thumbnailUrl || "",
            reason,
            itemType: "video",
            status: "rejected",
            priority: "critical",
            category: "verification",
          },
        }).catch((err: any) =>
          logger.warn("[PublishGate] Rejection notification failed (non-critical)", { videoId, err: String(err) })
        );
      }
    }

    // ─── GATE 2.7: Detect if channel fact-check dispute transitioned to pending_review ───
    const beforeDisputeStatus = beforeData?.factCheckDispute?.status;
    const afterDisputeStatus = afterData?.factCheckDispute?.status;
    const disputeSubmitted = afterDisputeStatus === "pending_review" && beforeDisputeStatus !== "pending_review";

    if (disputeSubmitted) {
      const db = admin.firestore();
      const disputeAttempts = Number(afterData.factCheckDispute?.disputeAttempts || 0);
      if (disputeAttempts >= 2) {
        logger.warn("[DisputeTrigger] Maximum dispute attempts reached for video", { videoId, disputeAttempts });
        await db.collection("videos").doc(videoId).set(
          {
            "factCheckDispute.status": "rejected_max_attempts",
            "factCheckDispute.resolvedAt": admin.firestore.FieldValue.serverTimestamp(),
            "factCheckDispute.rejectReason": "Maximum dispute attempts (2) reached for this video.",
          },
          { merge: true }
        );
        return;
      }

      logger.info("[DisputeTrigger] Dispatching credibility re-evaluation for disputed video via PubSub", {
        videoId,
        reason: afterData.factCheckDispute.reason,
        disputeAttempts,
      });

      const { DistributionLayer } = require("../pipeline/layers/04-distribution");
      const distributionLayer = new DistributionLayer();

      const executionPlan: ExecutionPlan = {
        jobId: videoId,
        languages: [],
        enablePath1: true,
        enablePath2: false,
        enableTruthEngine: true,
        enableReachEngine: false,
        enableAuxiliary: false,
        dubbingMode: "none",
        generateDubbing: false,
        genLangSubs: false,
        channelType: "standard",
        maxClaims: 200,
        priority: "high",
        skipCache: true,
        synthesisTier: "deep",
      };

      const eventId = `dispute_re_eval_${videoId}_${Date.now()}`;
      await distributionLayer.publish("fact-processing", {
        eventId,
        eventType: "fact-processing",
        jobId: videoId,
        userId: afterData.userId || afterData.creatorId || "unknown",
        timestamp: Date.now(),
        data: {
          videoUrl: afterData.videoUrl || "",
          executionPlan,
        },
        retryCount: 0,
        source: "dispute-gate",
      });

      await db.collection("videos").doc(videoId).set(
        {
          "factCheckDispute.status": "processing",
          "factCheckDispute.disputeAttempts": admin.firestore.FieldValue.increment(1),
          "factCheckDispute.dispatchedAt": admin.firestore.FieldValue.serverTimestamp(),
          credibilityStatus: "re_evaluating_with_channel_sources",
        },
        { merge: true }
      );
      return;
    }

    if (!becamePublished && !languagesChanged && !shouldSendNotifications) {
      return; // No relevant pipeline action needed — exit silently
    }

    // ─── GATE 3: Metadata completeness check ────────────────────────────────
    const title = afterData.title || "";
    const videoUrl = afterData.videoUrl || "";

    if (!title || title === "Uploading..." || !videoUrl) {
      logger.warn("[PublishGate] Incomplete metadata — skipping pipeline", {
        videoId,
        hasTitle: !!title && title !== "Uploading...",
        hasVideoUrl: !!videoUrl,
      });
      return;
    }

    const db = admin.firestore();
    const { EdgeLayer } = require("../pipeline/layers/01-edge");
    const { DistributionLayer } = require("../pipeline/layers/04-distribution");
    const distributionLayer = new DistributionLayer();

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO D: Trigger Subscriber Notifications once video is approved & published
    // ═══════════════════════════════════════════════════════════════════════════
    if (shouldSendNotifications) {
      logger.info("[PublishGate] Video approved & published. Triggering subscriber notifications.", { videoId });
      await db.collection("videos").doc(videoId).update({
        notificationsSent: true,
      });
      _fanOutSubscriberNotifications(afterData, videoId).catch(err =>
        logger.warn("[PublishGate] Subscriber notification fan-out failed (non-critical)", { videoId, err: String(err) })
      );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO A: First-time publish → Create video_job + trigger full pipeline
    // ═══════════════════════════════════════════════════════════════════════════
    if (becamePublished && !afterData.jobId) {
      const existingJobSnap = await db.collection("video_jobs")
        .where("videoId", "==", videoId)
        .limit(1)
        .get();
      if (!existingJobSnap.empty) {
        logger.info("[PublishGate] Job already exists for this video — skipping (retry idempotency)", {
          videoId,
          existingJobId: existingJobSnap.docs[0].id,
        });
        return;
      }

      const moderationStatus = afterData.moderation?.status;
      if (moderationStatus === "rejected") {
        logger.warn("[PublishGate] Video already REJECTED by moderation — blocking pipeline", {
          videoId,
          reason: afterData.moderation?.reason,
        });
        await db.collection("videos").doc(videoId).update({
          status: "rejected",
          rejectionReason: afterData.moderation?.reason || "Content violates Community Guidelines",
        });
        return;
      }
      logger.info("[PublishGate] First publish — SPECULATIVE pipeline start (moderation runs in parallel)", {
        videoId,
        moderationStatus: moderationStatus || "pending",
        features: {
          factChecking: aiFeatures.factChecking,
          genLangSubs: aiFeatures.genLangSubs,
          generateDubbing: aiFeatures.generateDubbing,
          diarization: aiFeatures.diarization,
          summary: aiFeatures.summary,
          translationLanguages: getTranslationLangs(afterData),
          speakerCount: aiFeatures.speakerCount,
          ttsEnabled: aiFeatures.tts?.enabled,
        },
      });

      const userId = afterData.userId || afterData.ownerId;
      if (!userId) {
        logger.error("[PublishGate] No userId/ownerId on video doc", { videoId });
        return;
      }

      const jobId = `job_${Date.now()}_${uuidv4().substring(0, 8)}`;
      const eventId = uuidv4();

      // Map ALL aiFeatures → ExecutionPlan
      const rawRequestedLanguages: string[] = getTranslationLangs(afterData);
      const requestedLanguages: string[] = normalizeLanguageCodes(rawRequestedLanguages);
      const hasTargetLanguages = requestedLanguages.length > 0;
      const enableFactChecking = Boolean(
        aiFeatures.factChecking === true ||
        aiFeatures.enableFactCheck === true ||
        aiFeatures.factCheck === true ||
        aiFeatures.truthVerification === true ||
        afterData.enableFactCheck === true ||
        afterData.factChecking === true ||
        afterData.factCheck === true ||
        afterData.truthVerification === true ||
        afterData.isFactChecked === true ||
        (afterData.factCheckTier && afterData.factCheckTier !== "none" && afterData.factCheckTier !== "off" && afterData.factCheckTier !== "") ||
        (aiFeatures.factCheckTier && aiFeatures.factCheckTier !== "none" && aiFeatures.factCheckTier !== "off" && aiFeatures.factCheckTier !== "")
      );
      // TruthWorld Unified Standard: All fact-checked content receives Complete Ground-Truth Verification
      const factCheckTier: "short" | "standard" | "full_ground" = enableFactChecking ? "full_ground" : "standard";

      const enableGenLangSubs = aiFeatures.genLangSubs ?? (hasTargetLanguages || (aiFeatures.generateSubtitles ?? false));
      const enableDubbing = Boolean(
        aiFeatures.generateDubbing === true ||
        aiFeatures.dubbing === true ||
        afterData.generateDubbing === true ||
        afterData.dubbing === true ||
        (Array.isArray(aiFeatures.dubbingLanguages) && aiFeatures.dubbingLanguages.length > 0) ||
        (Array.isArray(afterData.dubbingLanguages) && afterData.dubbingLanguages.length > 0) ||
        (aiFeatures.dubbingMode && aiFeatures.dubbingMode !== "none") ||
        (afterData.dubbingMode && afterData.dubbingMode !== "none")
      );
      const enableSummary = aiFeatures.summary ?? false;
      const enableDiarization = (aiFeatures.diarization ?? aiFeatures.enableDiarization) ?? false;
      const enableAutoChapters = (aiFeatures.autoChapters ?? aiFeatures.chapters) ?? false;
      const enablePath2 = enableDubbing || enableGenLangSubs || hasTargetLanguages;

      // Resolve the channel's designated source language directly from the channel doc (established at channel creation)
      let channelLang = "";
      const channelId = afterData.channelId || "";
      if (channelId) {
        try {
          const chSnap = await db.collection("channels").doc(channelId).get();
          if (chSnap.exists) {
            const chData = chSnap.data();
            const chLang = chData?.language || chData?.channelLanguage;
            if (chLang) {
              channelLang = normalizeLanguageCode(chLang);
            }
          }
        } catch (err) {
          logger.warn("[PublishGate] Failed to fetch channel language for channel", { channelId, err });
        }
      }
      if (!channelLang) {
        channelLang = normalizeLanguageCode(afterData.language || "en");
      }

      const ttsConfig = aiFeatures.tts || {};
      const voiceType = ttsConfig.voiceType || "standard";
      const speakerCount = aiFeatures.speakerCount || "not_sure";

      const maxClaims = !enableFactChecking ? 0 : 200;

      const synthesisTier: "standard" | "deep" | "podcast" =
        enableFactChecking ? "deep" : "standard";

      const executionPlan: ExecutionPlan = {
        jobId,
        videoId,
        title: afterData.title || "",
        description: afterData.description || "",
        thumbnailUrl: afterData.thumbnailUrl || "",
        channelId: afterData.channelId || "",
        channelName: afterData.channelName || "",
        channelAvatarUrl: afterData.channelImage || afterData.channelAvatarUrl || "",
        category: afterData.category || afterData.videoCategory || "Other",
        tags: afterData.tags || [],
        topics: afterData.topics || [],
        providedSources: afterData.providedSources || [],
        visibility: afterData.visibility || "public",
        enablePath1: enableFactChecking,
        enablePath2,
        enableTruthEngine: enableFactChecking,
        enableReachEngine: enablePath2,
        enableAuxiliary: enableSummary || enableFactChecking,
        enableDiarization,
        diarization: enableDiarization,
        factCheckEnabled: enableFactChecking,
        dubbingLanguages: Array.isArray(aiFeatures.dubbingLanguages) ? normalizeLanguageCodes(aiFeatures.dubbingLanguages) : [],
        primaryLanguage: channelLang,
        languages: Array.from(new Set([channelLang, ...requestedLanguages])),
        dubbingMode: voiceType === "voice_clone" ? "voice_clone" : (enableDubbing ? "standard" : "none"),
        generateDubbing: enableDubbing,
        genLangSubs: enableGenLangSubs,
        channelType: afterData.channelType || "standard",
        autoChapters: enableAutoChapters,
        maxClaims,
        synthesisTier,
        factCheckTier,
        priority: "normal",
        skipCache: false,
        expectedSpeakerCount: speakerCount as '1' | '2-3' | '4+' | 'not_sure',
        contentFormat: enableDiarization ? "general" : "solo",
        translationModel: "standard",
        toneMode: "formal",
        localeStyle: requestedLanguages.includes("hi") ? "hinglish" : "neutral",
        targetPlatform: afterData.targetPlatform || "youtube",
        duration: afterData.duration ? parseInt(String(afterData.duration)) : undefined,
        videoCategory: afterData.category || afterData.videoCategory || "Other",
      };
      (executionPlan as any).enableFactChecking = enableFactChecking;

      const now = Date.now();
      const shard = EdgeLayer.shardKey(userId);

      const modStageStatus = moderationStatus === "approved"
        ? { status: "completed", progress: 100, completedAt: now }
        : { status: "running", progress: 50, startedAt: now };

      const stages: Record<string, any> = {
        moderation: modStageStatus,
        upload: { status: "completed", progress: 100, completedAt: now },
        validation: { status: "completed", progress: 100, completedAt: now },
        queue: { status: "running", progress: 50, startedAt: now },
        transcription: { status: "pending", progress: 0 },
        copyright: { status: "pending", progress: 0 },
        credibility: enableFactChecking ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 },
        dubbing: enableDubbing ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 },
        rendering: { status: "pending", progress: 0 },
        finalizing: { status: "pending", progress: 0 },
        aggregation: { status: "pending", progress: 0 },
      };

      if (enablePath2) {
        const targetLangs = (requestedLanguages || []).filter(l => normalizeLanguageCode(l) !== channelLang);
        for (const lang of targetLangs) {
          const normLang = normalizeLanguageCode(lang);
          stages[`translating_${normLang}`] = { status: "pending", progress: 0 };
          if (lang !== normLang) stages[`translating_${lang}`] = { status: "pending", progress: 0 };
          if (enableDubbing) {
            stages[`dubbing_${normLang}`] = { status: "pending", progress: 0 };
            if (lang !== normLang) stages[`dubbing_${lang}`] = { status: "pending", progress: 0 };
          }
        }
      }

      const jobData = {
        jobId,
        videoId,
        userId,
        videoUrl,
        fileName: afterData.fileName || "video.mp4",
        filePath: afterData.storage?.videoPath || `videos/${videoId}/original.mp4`,
        status: "accepted",
        eventId,
        shard,
        executionPlan,
        config: {
          userId,
          channelType: executionPlan.channelType,
          languages: executionPlan.languages,
          dubbingMode: executionPlan.dubbingMode,
          genLangSubs: enableGenLangSubs,
          generateDubbing: enableDubbing,
          enableFactCheck: enableFactChecking,
          factCheckTier,
          priority: executionPlan.priority,
        },
        channelId: afterData.channelId || null,
        linkedVideoIds: [videoId],
        linkedVideoCount: 1,
        estimatedCostUsd: 0,
        stages,
        createdAt: now,
        updatedAt: now,
        version: 1,
      };

      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const batch = db.batch();
          batch.set(db.collection("video_jobs").doc(jobId), jobData);
          batch.update(db.collection("videos").doc(videoId), {
            jobId,
            language: channelLang,
            factCheckTier,
            enableFactCheck: enableFactChecking,
            factChecking: enableFactChecking,
            status: "processing",
            updatedAt: now,
          });
          await batch.commit();
          break;
        } catch (commitErr) {
          if (attempt < 3) {
            await new Promise(r => setTimeout(r, 50 * attempt + Math.floor(Math.random() * 50)));
            continue;
          }
          throw commitErr;
        }
      }

      logger.info("[PublishGate] Video job created from publish", {
        jobId,
        videoId,
        enableFactChecking,
        enableDubbing,
        enableGenLangSubs,
        enableSummary,
        enableDiarization,
        languages: executionPlan.languages,
        speakerCount,
      });

      await distributionLayer.publish("video-uploaded", {
        eventId,
        eventType: "video-uploaded",
        jobId,
        userId,
        timestamp: now,
        data: {
          videoUrl,
          fileName: afterData.fileName || "video.mp4",
          executionPlan,
        },
        retryCount: 0,
        source: "publish-gate",
      });

      const resolvedChannelId = afterData.channelId || `channel_${userId}`;
      notifyUser({
        userId,
        type: "verification_result",
        severity: "info",
        title: `Video Processing Started: "${title}"`,
        message: `Your video "${title}" is now undergoing Truthworld AI transcription, processing, and safety checks.`,
        actionUrl: "/studio",
        metadata: {
          videoId,
          jobId,
          channelId: resolvedChannelId,
          videoTitle: title,
          thumbnailUrl: afterData.thumbnailUrl || "",
          itemType: "video",
          status: "processing",
          priority: "normal",
          category: "verification",
        },
      }).catch((err: any) =>
        logger.warn("[PublishGate] Processing started notification failed (non-critical)", { videoId, err: String(err) })
      );

      // ⚡ FAST MULTIMODAL TRIAGE (Sub-60s provisional credibility & OCR check)
      if (enableFactChecking || aiFeatures.factChecking !== false) {
        try {
          const { fastMultimodalTriageService } = require("../pipeline/services/fastMultimodalTriageService");
          fastMultimodalTriageService
            .triageVideo(videoId, videoUrl, title)
            .catch((err: any) =>
              logger.warn("[PublishGate] Fast multimodal triage non-fatal error", { videoId, err: String(err) })
            );
        } catch (err: any) {
          logger.warn("[PublishGate] Failed to invoke fast triage service", { videoId, err: String(err) });
        }
      }

      return;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO B: Already published, job exists → Re-trigger Path 2 for new languages
    // ═══════════════════════════════════════════════════════════════════════════
    if (languagesChanged && afterData.jobId) {
      const jobId = afterData.jobId;
      logger.info("[PublishGate] Language change detected on published video", {
        videoId,
        jobId,
        newLanguages: getTranslationLangs(afterData),
      });

      const jobDoc = await db.collection("video_jobs").doc(jobId).get();
      if (!jobDoc.exists) {
        logger.warn("[PublishGate] Linked video_job not found", { videoId, jobId });
        return;
      }

      const jobData = jobDoc.data()!;

      const stages = jobData.stages || {};
      if (stages.transcription?.status !== "completed") {
        logger.info("[PublishGate] Transcription not yet complete — deferring language trigger", { videoId, jobId });
        return;
      }

      const localizationVersion = (getTranslationLangs(afterData) as string[]).sort().join(",");
      const processedVersions = jobData.processedLocalizationVersions || [];
      if (processedVersions.includes(localizationVersion)) {
        logger.info("[PublishGate] Language version already processed", { videoId, jobId, version: localizationVersion });
        return;
      }

      const rawRelangs = getTranslationLangs(afterData);
      const normRelangs = normalizeLanguageCodes(rawRelangs);
      let scenarioBChannelLang = "";
      if (afterData.channelId) {
        try {
          const chSnap = await db.collection("channels").doc(afterData.channelId).get();
          if (chSnap.exists) {
            const chLang = chSnap.data()?.language || chSnap.data()?.channelLanguage;
            if (chLang) {
              scenarioBChannelLang = normalizeLanguageCode(chLang);
            }
          }
        } catch (err) {
          logger.warn("[PublishGate] Failed to fetch channel language in Scenario B", { channelId: afterData.channelId, err });
        }
      }
      if (!scenarioBChannelLang) {
        scenarioBChannelLang = normalizeLanguageCode(afterData.language || jobData.executionPlan?.primaryLanguage || "en");
      }
      const updatedPlan: ExecutionPlan = {
        ...jobData.executionPlan,
        languages: Array.from(new Set([scenarioBChannelLang, ...normRelangs])),
        generateDubbing: aiFeatures.generateDubbing ?? jobData.executionPlan.generateDubbing,
        genLangSubs: aiFeatures.genLangSubs ?? jobData.executionPlan.genLangSubs,
        enablePath2: true,
        enableReachEngine: true,
        jobId,
      };

      await distributionLayer.publish("dubbing-processing", {
        eventId: uuidv4(),
        eventType: "dubbing-processing",
        jobId,
        userId: jobData.userId,
        timestamp: Date.now(),
        data: {
          videoUrl: jobData.videoUrl,
          executionPlan: updatedPlan,
        },
        retryCount: 0,
        source: "publish-gate-relang",
      });

      const updatePayload: Record<string, any> = {
        executionPlan: updatedPlan,
        "stages.dubbing": updatedPlan.generateDubbing
          ? { status: "pending", progress: 0, startedAt: Date.now() }
          : { status: "skipped", progress: 100 },
        processedLocalizationVersions: admin.firestore.FieldValue.arrayUnion(localizationVersion),
        updatedAt: Date.now(),
      };

      const targetLangs = (normRelangs || []).filter((l: string) => normalizeLanguageCode(l) !== scenarioBChannelLang);
      for (const lang of targetLangs) {
        updatePayload[`stages.translating_${lang}`] = { status: "pending", progress: 0 };
        if (updatedPlan.generateDubbing) {
          updatePayload[`stages.dubbing_${lang}`] = { status: "pending", progress: 0 };
        }
      }

      await jobDoc.ref.update(updatePayload);
      return;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO C: Re-publish / Metadata Update (job already exists)
    // Reconcile Truth Verification and Dubbing if requested/skipped by creator
    // ═══════════════════════════════════════════════════════════════════════════
    if (afterData.jobId) {
      const existingJobId = afterData.jobId;
      const enableFactCheckingOnReconcile = Boolean(
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

      const enableDubbingOnReconcile = Boolean(
        aiFeatures.generateDubbing === true ||
        aiFeatures.dubbing === true ||
        afterData.generateDubbing === true ||
        afterData.dubbing === true ||
        (Array.isArray(aiFeatures.dubbingLanguages) && aiFeatures.dubbingLanguages.length > 0) ||
        (Array.isArray(afterData.dubbingLanguages) && afterData.dubbingLanguages.length > 0) ||
        (aiFeatures.dubbingMode && aiFeatures.dubbingMode !== "none") ||
        (afterData.dubbingMode && afterData.dubbingMode !== "none")
      );

      const jobSnap = await db.collection("video_jobs").doc(existingJobId).get();
      if (jobSnap.exists) {
        const jobData = jobSnap.data()!;
        const existingCredStatus = jobData.stages?.credibility?.status;
        const existingTruthEngine = jobData.executionPlan?.enableTruthEngine;
        const existingDubStatus = jobData.stages?.dubbing?.status;

        // Reconcile Dubbing if creator skipped dubbing but job has it pending or completed
        if (!enableDubbingOnReconcile && existingDubStatus !== "skipped") {
          logger.info("[PublishGate] Creator skipped dubbing — reconciling stages.dubbing to skipped on existing job", {
            videoId,
            jobId: existingJobId,
            previousStatus: existingDubStatus,
          });
          await jobSnap.ref.update({
            "stages.dubbing": { status: "skipped", progress: 100 },
            "config.generateDubbing": false,
            "config.dubbingMode": "none",
            "executionPlan.generateDubbing": false,
            "executionPlan.dubbingMode": "none",
            updatedAt: Date.now(),
          });
        }

        if (enableFactCheckingOnReconcile && (existingCredStatus === "skipped" || !existingTruthEngine)) {
          logger.info("[PublishGate] Reconciling Truth Verification on existing job", {
            videoId,
            jobId: existingJobId,
            previousStatus: existingCredStatus,
          });

          const reconciledPlan: ExecutionPlan = {
            ...jobData.executionPlan,
            enablePath1: true,
            enableTruthEngine: true,
            factCheckEnabled: true,
            factCheckTier: "full_ground",
            maxClaims: 200,
            synthesisTier: "deep",
            jobId: existingJobId,
          };
          (reconciledPlan as any).enableFactChecking = true;

          const jobUpdates: Record<string, any> = {
            executionPlan: reconciledPlan,
            "stages.credibility": { status: "pending", progress: 0, startedAt: Date.now() },
            "config.enableFactCheck": true,
            "config.factCheckTier": "full_ground",
            updatedAt: Date.now(),
          };
          await jobSnap.ref.update(jobUpdates);

          if (jobData.stages?.transcription?.status === "completed") {
            logger.info("[PublishGate] Transcription already completed — launching fact-processing immediately for reconciled job", { videoId, jobId: existingJobId });
            await distributionLayer.publish("fact-processing", {
              eventId: `fact_reconcile_${existingJobId}_${Date.now()}`,
              eventType: "fact-processing",
              jobId: existingJobId,
              userId: jobData.userId || afterData.userId || afterData.ownerId || "unknown",
              timestamp: Date.now(),
              data: {
                executionPlan: reconciledPlan,
                videoUrl: jobData.videoUrl || afterData.videoUrl || "",
              },
              retryCount: 0,
              source: "publish-gate-reconcile",
            });
          }

          try {
            const { fastMultimodalTriageService } = require("../pipeline/services/fastMultimodalTriageService");
            fastMultimodalTriageService
              .triageVideo(videoId, jobData.videoUrl || afterData.videoUrl || "", afterData.title || title)
              .catch((err: any) =>
                logger.warn("[PublishGate] Fast multimodal triage non-fatal error", { videoId, err: String(err) })
              );
          } catch (err: any) {
            logger.warn("[PublishGate] Failed to invoke fast triage service", { videoId, err: String(err) });
          }

          await db.collection("videos").doc(videoId).set(
            {
              factCheckTier: "full_ground",
              enableFactCheck: true,
              factChecking: true,
              isFactChecked: true,
              credibilityStatus: "processing",
              updatedAt: Date.now(),
            },
            { merge: true }
          );

          return;
        }
      }

      if (becamePublished) {
        logger.info("[PublishGate] Re-publish detected but job already exists — skipping", {
          videoId,
          jobId: afterData.jobId,
        });
        return;
      }
    }
  }
);

// ─── MERGED HELPER: Subscriber Notification Fan-Out ──────────────────────────
async function _fanOutSubscriberNotifications(video: any, videoId: string): Promise<void> {
  const db = admin.firestore();
  const { channelId, title, creatorName } = video;
  const channelNameStr = creatorName || video.channelName || "Unknown Channel";
  const creatorId = video.ownerId || video.userId;

  // 1. INDUSTRY STANDARD TOPIC BROADCAST (Zero-cost, parallel delivery to 100M+ subscribers)
  // Reaches all subscribed devices in a single call without consuming Firestore write operations or timing out.
  if (channelId) {
    try {
      const sanitizedChannelId = String(channelId).trim().replace(/[^a-zA-Z0-9-_.~%]/g, "_");
      const rawThumb = (video.thumbnailUrl || video.customThumbnailUrl || "").trim();
      const validThumb = (rawThumb.startsWith("http") && !rawThumb.includes("Icon-512") && !rawThumb.includes("play_icon")) ? rawThumb : "";

      await admin.messaging().send({
        topic: `channel_${sanitizedChannelId}`,
        notification: {
          title: `New Video from ${channelNameStr}`,
          body: `${channelNameStr} just uploaded: ${title || "Untitled Video"}`,
          ...(validThumb ? { imageUrl: validThumb } : {}),
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "new_video_followed",
          channelId: String(channelId),
          videoId: String(videoId),
          actionUrl: `/watch?v=${videoId}`,
          thumbnailUrl: validThumb,
          avatarUrl: video.channelImage || "",
          targetApp: "app",
        },
        android: {
          priority: "high" as const,
          notification: {
            channelId: "truthworld_notifications",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            priority: "max" as const,
            visibility: "public" as const,
            icon: "ic_notification",
            color: "#14EAB2",
            ...(validThumb ? { imageUrl: validThumb } : {}),
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
          ...(validThumb ? { fcmOptions: { imageUrl: validThumb } } : {}),
        },
        webpush: {
          headers: {
            Urgency: "high",
          },
          notification: {
            icon: "https://www.truthworld.in/icons/Icon-192.png",
            badge: "https://www.truthworld.in/icons/Icon-192.png",
            ...(validThumb ? { image: validThumb } : {}),
          },
          fcmOptions: {
            link: `/watch?v=${videoId}`,
          },
        },
      });
      logger.info(`[FanOut] Dispatched broadcast topic push for channel_${sanitizedChannelId}`);
    } catch (fcmErr) {
      logger.warn(`[FanOut] FCM broadcast topic error (non-fatal):`, fcmErr);
    }
  }

  // 2. Controlled In-App Inbox Materialization for Active Subscribers
  // Bounded to MAX_FANOUT_BATCHES to strictly adhere to Cloud Function timeout (540s) and memory budgets.
  // Mega channels rely on FCM topic push + dynamic pull-on-read ingestion on app open.
  const BATCH_SIZE = 400;
  const MAX_FANOUT_BATCHES = 5;
  let batchCount = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let totalNotified = 0;
  const notifiedUserIds = new Set<string>();
  if (creatorId) {
    notifiedUserIds.add(creatorId);
  }

  // Determine whether this video qualifies for "personalized" subscriber & topic notifications:
  // Notable highlights: verified fact checks, high truth/trust score (>=75), featured, or explicit highlight.
  const isVerified = video.isFactChecked === true || video.factCheckStatus === "verified";
  const isFeatured = video.featured === true || video.isFeatured === true;
  const isHighTruth = typeof video.truthScore === "number" && video.truthScore >= 75;
  const isHighTrust = typeof video.trustScore === "number" && video.trustScore >= 75;
  const isHighlight = video.isHighlight === true;
  const isPersonalizedEligible = isVerified || isFeatured || isHighTruth || isHighTrust || isHighlight;

  while (batchCount < MAX_FANOUT_BATCHES) {
    let query = db.collection("subscriptions")
      .where("channelId", "==", channelId)
      .limit(BATCH_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    batchCount++;

    const batch = db.batch();
    const notifications: Promise<any>[] = [];

    snap.docs.forEach(doc => {
      const data = doc.data();
      const { userId, notificationsEnabled } = data;
      if (!userId || userId === creatorId) return;

      batch.set(
        db.collection("users").doc(userId).collection("feed_inbox").doc(videoId),
        {
          id: videoId,
          channelId: channelId || "",
          channelName: channelNameStr,
          channelImage: video.channelImage || "",
          title: title || "Untitled Video",
          thumbnailUrl: video.thumbnailUrl || "",
          uploadedAt: video.uploadedAt || video.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          views: video.views || 0,
          duration: video.duration || "0:00",
          category: video.category || "General",
          isSeen: false,
          materializedAt: admin.firestore.FieldValue.serverTimestamp()
        },
        { merge: true }
      );

      // Determine effective notification option: 'all' | 'personalized' (default) | 'none'
      const effectiveOption = (data.notificationOption || data.notificationPreference || (notificationsEnabled === false ? "none" : "personalized")).toLowerCase();

      // Only notify if notifications are not disabled and option is not 'none'.
      // When set to 'personalized', only send for personalized highlights (verified, high truth/trust score >= 75, featured).
      const shouldNotifySubscriber = notificationsEnabled !== false &&
        effectiveOption !== "none" &&
        (effectiveOption === "all" || isPersonalizedEligible);

      if (shouldNotifySubscriber) {
        notifiedUserIds.add(userId);
        notifications.push(
          notifyUser({
            userId,
            type: "new_video_followed",
            severity: "info",
            title: `New Video from ${channelNameStr}`,
            message: `${channelNameStr} just uploaded: ${title}`,
            actionUrl: `/video/${videoId}`,
            metadata: { 
              channelId, 
              videoId, 
              thumbnailUrl: video.thumbnailUrl, 
              avatarUrl: video.channelImage || "",
              notificationOption: effectiveOption,
            }
          })
        );
      }
    });

    await batch.commit();
    await Promise.allSettled(notifications);
    totalNotified += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < BATCH_SIZE) break;
  }

  logger.info(`[FanOut] Notified ${totalNotified} subscribers for video ${videoId}`);

  // Topic follower notifications
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
  const uniqueTopicKeys = Array.from(new Set(rawTopicKeys));

  if (uniqueTopicKeys.length > 0) {

    for (const topicKey of uniqueTopicKeys) {
      let topicDoc: FirebaseFirestore.DocumentSnapshot | null = null;
      const directDoc = await db.collection("topics").doc(topicKey).get();
      if (directDoc.exists) {
        topicDoc = directDoc;
      } else {
        const slugSnap = await db.collection("topics").where("slug", "==", topicKey).limit(1).get();
        if (!slugSnap.empty) {
          topicDoc = slugSnap.docs[0];
        }
      }

      if (!topicDoc || !topicDoc.exists) continue;

      const topicData = topicDoc.data() || {};
      const topicTitle = topicData.title || topicData.name || "Followed Topic";
      const topicDocId = topicDoc.id;
      const topicSlug = topicData.slug || topicDocId;

      // Match followers saved under topic doc ID, slug, or raw topic key
      const topicMatchIds = Array.from(new Set([topicDocId, topicSlug, topicKey].filter(Boolean)));

      let savedDocs: FirebaseFirestore.QueryDocumentSnapshot[] = [];
      if (topicMatchIds.length === 1) {
        const snap = await db.collectionGroup("savedTopics")
          .where("topicId", "==", topicMatchIds[0])
          .limit(500)
          .get();
        savedDocs = snap.docs;
      } else {
        const snap = await db.collectionGroup("savedTopics")
          .where("topicId", "in", topicMatchIds.slice(0, 10))
          .limit(500)
          .get();
        savedDocs = snap.docs;
      }

      const topicNotifs: Promise<any>[] = [];

      for (const d of savedDocs) {
        const savedData = d.data() || {};
        const uid = d.ref.parent?.parent?.id || d.ref.path.split("/")[1];
        if (!uid || notifiedUserIds.has(uid)) continue;

        const setting = (savedData.notificationSetting || "personalized").toLowerCase();

        // 1. "none": user explicitly muted notifications for this topic
        if (setting === "none") continue;

        // 2. "personalized": user only wants notifications for verified/featured/high-truth highlights
        if (setting === "personalized" && !isPersonalizedEligible) continue;

        // 3. Mark user as notified to prevent duplicate notifications across overlapping topics
        notifiedUserIds.add(uid);

        topicNotifs.push(
          notifyUser({
            userId: uid,
            type: "new_video_topic",
            severity: "info",
            title: `New Video in Topic: ${topicTitle}`,
            message: `A new video was added to ${topicTitle}: ${title}`,
            actionUrl: `/video/${videoId}`,
            metadata: {
              topicId: topicDocId,
              topicTitle,
              videoId,
              thumbnailUrl: video.thumbnailUrl,
              avatarUrl: video.channelImage || "",
              notificationSetting: setting,
            },
          })
        );
      }

      if (topicNotifs.length > 0) {
        await Promise.allSettled(topicNotifs);
        logger.info(`[FanOut] Notified ${topicNotifs.length} followers for topic ${topicTitle} (${topicDocId})`);
      }
    }
  }

  // @mention notifications
  const combinedText = `${title || ""} ${video.description || ""}`;
  await notifyMentions({
    text: combinedText,
    senderUserId: creatorId || "",
    senderName: channelNameStr,
    actionUrl: `/video/${videoId}`,
    title: "Mentioned in a Video!",
    message: `${channelNameStr} mentioned your channel in their video: "${title}"`,
    metadata: { videoId, thumbnailUrl: video.thumbnailUrl, avatarUrl: video.channelImage || "" }
  });
}
