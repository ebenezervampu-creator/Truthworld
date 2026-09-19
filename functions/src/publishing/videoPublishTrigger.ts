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
    memory: "256MiB",
    maxInstances: 2,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const videoId = event.params.videoId;

    if (!afterData) return;

    const aiFeatures = afterData.aiFeatures || {};
    const beforeAiFeatures = beforeData?.aiFeatures || {};

    // ─── GATE 1: Detect if pipelineStage just became 'published' ────────────
    const becamePublished =
      beforeAiFeatures.pipelineStage !== "published" &&
      aiFeatures.pipelineStage === "published";

    // ─── GATE 2: Detect language changes on already-published video ──────────
    const getTranslationLangs = (data: any) => data?.aiFeatures?.translationLanguages || data?.languages || [];
    const isAlreadyPublished = aiFeatures.pipelineStage === "published";
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

    if (becameRejected) {
      const uploaderId = afterData.userId || afterData.ownerId || afterData.uploaderId;
      if (uploaderId) {
        const reason = afterData.rejectionReason || afterData.moderation?.reason || "Content violates Community Guidelines";
        const title = afterData.title && afterData.title !== "Uploading..." ? afterData.title : "your video";
        notifyUser({
          userId: uploaderId,
          type: "verification_result",
          severity: "priority",
          title: "Video Moderation Rejected",
          message: `Your video "${title}" was rejected: ${reason}. Please update or replace your video to comply with guidelines.`,
          actionUrl: "/studio",
          metadata: {
            videoId,
            reason,
            itemType: "video",
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
        maxClaims: 20,
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
      const enableFactChecking = aiFeatures.factChecking ?? false;
      const enableGenLangSubs = aiFeatures.genLangSubs ?? (hasTargetLanguages || (aiFeatures.generateSubtitles ?? false));
      const enableDubbing = aiFeatures.generateDubbing ?? false;
      const enableSummary = aiFeatures.summary ?? false;
      const enableDiarization = aiFeatures.diarization ?? false;
      const enablePath2 = enableDubbing || enableGenLangSubs || hasTargetLanguages;

      const ttsConfig = aiFeatures.tts || {};
      const voiceType = ttsConfig.voiceType || "standard";
      const speakerCount = aiFeatures.speakerCount || "not_sure";

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
        enableAuxiliary: enableSummary,
        languages: Array.from(new Set(["en", ...requestedLanguages])),
        dubbingMode: voiceType === "voice_clone" ? "voice_clone" : (enableDubbing ? "standard" : "none"),
        generateDubbing: enableDubbing,
        genLangSubs: enableGenLangSubs,
        channelType: afterData.channelType || "standard",
        autoChapters: aiFeatures.autoChapters ?? false,
        maxClaims: enableFactChecking ? 100 : 0,
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
        dubbing: enablePath2 ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 },
        rendering: { status: "pending", progress: 0 },
        finalizing: { status: "pending", progress: 0 },
        aggregation: { status: "pending", progress: 0 },
      };

      if (enablePath2) {
        const targetLangs = (requestedLanguages || []).filter(l => normalizeLanguageCode(l) !== "en");
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

      const batch = db.batch();
      batch.set(db.collection("video_jobs").doc(jobId), jobData);
      batch.update(db.collection("videos").doc(videoId), {
        jobId,
        status: "processing",
        updatedAt: now,
      });
      await batch.commit();

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
      const updatedPlan: ExecutionPlan = {
        ...jobData.executionPlan,
        languages: Array.from(new Set(["en", ...normRelangs])),
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
        "stages.dubbing": { status: "pending", progress: 0, startedAt: Date.now() },
        processedLocalizationVersions: admin.firestore.FieldValue.arrayUnion(localizationVersion),
        updatedAt: Date.now(),
      };

      const targetLangs = (normRelangs || []).filter((l: string) => l !== "en");
      for (const lang of targetLangs) {
        updatePayload[`stages.translating_${lang}`] = { status: "pending", progress: 0 };
        updatePayload[`stages.dubbing_${lang}`] = { status: "pending", progress: 0 };
      }

      await jobDoc.ref.update(updatePayload);
      return;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO C: Re-publish (job already exists) → Skip (idempotent)
    // ═══════════════════════════════════════════════════════════════════════════
    if (becamePublished && afterData.jobId) {
      logger.info("[PublishGate] Re-publish detected but job already exists — skipping", {
        videoId,
        jobId: afterData.jobId,
      });
      return;
    }
  }
);

// ─── MERGED HELPER: Subscriber Notification Fan-Out ──────────────────────────
async function _fanOutSubscriberNotifications(video: any, videoId: string): Promise<void> {
  const db = admin.firestore();
  const { channelId, title, creatorName } = video;
  const channelNameStr = creatorName || video.channelName || "Unknown Channel";
  const creatorId = video.ownerId || video.userId;

  const BATCH_SIZE = 400;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let totalNotified = 0;

  while (true) {
    let query = db.collection("subscriptions")
      .where("channelId", "==", channelId)
      .limit(BATCH_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    const notifications: Promise<any>[] = [];

    snap.docs.forEach(doc => {
      const { userId, notificationsEnabled } = doc.data();
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

      if (notificationsEnabled !== false) {
        notifications.push(
          notifyUser({
            userId,
            type: "new_video_followed",
            severity: "info",
            title: `New Video from ${channelNameStr}`,
            message: `${channelNameStr} just uploaded: ${title}`,
            actionUrl: `/video/${videoId}`,
            metadata: { channelId, videoId, thumbnailUrl: video.thumbnailUrl, avatarUrl: video.channelImage || "" }
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
  const topicId = video.topicId || (video.topics?.length > 0 ? video.topics[0] : null);
  if (topicId) {
    const topicSnap = await db.collection("topics").where("slug", "==", topicId).limit(1).get();
    if (!topicSnap.empty) {
      const topicDoc = topicSnap.docs[0];
      const topicTitle = topicDoc.data().title || "Followed Topic";
      const savedSnap = await db.collectionGroup("savedTopics").where("topicId", "==", topicDoc.id).limit(500).get();
      const topicNotifs = savedSnap.docs
        .filter(d => d.data()?.notificationSetting !== "none")
        .map(d => d.ref.path.split("/")[1])
        .filter(uid => uid && uid !== creatorId)
        .map(uid => notifyUser({
          userId: uid,
          type: "new_video_topic",
          severity: "info",
          title: `New Video in Topic: ${topicTitle}`,
          message: `A new video was added to ${topicTitle}: ${title}`,
          actionUrl: `/video/${videoId}`,
          metadata: { 
            topicId: topicDoc.id, 
            videoId, 
            thumbnailUrl: video.thumbnailUrl,
            avatarUrl: video.channelImage || ""
          }
        }));
      await Promise.allSettled(topicNotifs);
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
