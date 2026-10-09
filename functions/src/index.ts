/**
 * 🚀 FIREBASE CLOUD FUNCTIONS — ENTRY POINT
 *
 * Modular deployment entry point for TruthWorld Cloud Functions (2nd Gen).
 *
 * Features exported:
 *   - Video Processing Pipeline (Ingestion, Transcription, Credibility, Dubbing, Aggregation)
 *   - Publish-Gated Job Scheduling & Shard Replication
 *   - Cloud Tasks SWR Cache Queues
 *   - Storage Lifecycle Maintenance & Cleanup
 *   - Moderation, Verification, Watchtime, Notifications, SEO, Admin, Economy
 *
 * ✅ minInstances: 0 (scale-to-zero) for cost optimization
 * ✅ Explicit maxInstances caps per function
 * ✅ Region: asia-south1
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK first
if (!admin.apps.length) {
  admin.initializeApp({
    databaseURL: "https://truthworld-1-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "truthworld-1.firebasestorage.app",
  });
}
admin.firestore().settings({ ignoreUndefinedProperties: true });

import { setGlobalOptions } from "firebase-functions/v2";

// ─── Global options ──────────────────────────────────────────────────────────
setGlobalOptions({
  region: "asia-south1",
  maxInstances: 100,
  cpu: "gcf_gen1",
});

// ─── Pipeline & Processing (Modularized) ──────────────────────────────────────
export * from "./pipeline/pipelineTriggers";

// ─── Video Resolution Processing (≤ 1040p) ───────────────────────────────────
export {
  onVideoUploadedForResolution,
  handleResolution,
  getVideoResolutionStatus,
  getResolutionProfiles,
  reconcileStuckResolutionJobsScheduled,
  reconcileVideoResolutionManual,
} from "./resolution/resolution";

// ─── Publish Gate & Fan-Out (Modularized) ─────────────────────────────────────
export * from "./publishing/videoPublishTrigger";
export * from "./publishing/shardSync";
export { scheduledVideoPublisher } from "./publishing/scheduledPublishing";

// ─── SWR Cache Queues & Storage Lifecycle Maintenance (Modularized) ──────────
export * from "./swr/swrQueues";
export * from "./maintenance/storageCleanup";

export {
  onVideoUploadedForModeration,
  moderateVideoManual,
  scheduledVideoModerationRetry,
} from "./moderation/videoModeration";
export {
  ingestUploadedImage,
  moderationWorkerHigh,
  moderationWorkerMedium,
  moderationWorkerLow,
  prefilterWorker,
  retryQueueProcessor,
  deadLetterHandler,
  scheduledRetryProcessor,
  moderateImageManual,
  setModerationModesManual,
} from "./verification/verification";

// ─── Watchtime, Analytics & Live Viewers ──────────────────────────────────────
export {
  trackWatchEvent,
  aggregateWatchStats,
  cleanupOldEvents,
} from "./watchtime/watchtime";
export { rollupDailyStats } from "./watchtime/rollup";
export {
  onActiveViewerWrite,
  cleanupStaleSessions,
} from "./watchtime/liveViewers";
export {
  aggregateVideoImpressions,
  aggregateVideoViews,
  cleanupOldViews,
} from "./analytics/impressions";
export { rollupVideoCounterShards } from "./analytics/counterRollup";

// ─── Live Chat & Social Features ──────────────────────────────────────────────
export {
  moderateLiveChatUser,
  processSuperchat,
  pruneLiveChatBacklogs,
} from "./livechat/liveChat";
export {
  onChannelCreatedSyncUser,
  dispatchChannelWelcomeEmail,
  cleanupExpiredDeletedChannelsScheduled,
} from "./channels/channels";
export {
  followChannel,
  unfollowChannel,
  updateChannelNotificationSettings,
  getFollowingFeed,
} from "./channels/social";
export { onChannelWritten, onImageVerificationWritten, moderateChannelManual } from "./channels/moderation";
export { onTopicWritten, moderateTopicManual } from "./topics/moderation";
export { getHomeFeed } from "./channels/recommendations";
export {
  getAlgorithmRemoteConfig,
  updateAlgorithmRemoteConfig,
} from "./algorithm/remoteConfig";

// ─── A/B Testing & Experimentation ────────────────────────────────────────
export {
  createExperiment,
  recordExperimentMetric,
  getActiveExperiments,
  analyzeExperiments,
  graduateExperiment,
  manageExperiment,
} from "./experiments/engine";

// ─── Notifications & User Signals ─────────────────────────────────────────────
export {
  getNotifications,
  markNotificationRead,
  updateTopicNotificationSettings,
  followTopic,
  unfollowTopic,
  getTopicNotificationSetting,
} from "./notifications/notifications";
export {
  onCommentCreated,
  onNewSubscription,
  onCommunityPostCreated,
  onCommunityPostUpdated,
  onUserNotificationCreated,
} from "./notifications/triggers";
export { trackActivity } from "./users/signals";
export { onUserCreated, onUserDeleted, purgeUserAccount } from "./users/userLifecycle";

// ─── Comments & Community ─────────────────────────────────────────────────────
export {
  addCommentNested,
  addReplyNested,
  addTopicComment,
  addTopicReply,
  toggleCommentInteraction,
  toggleReplyInteraction,
  deleteCommentNested,
  deleteReplyNested,
  reportCommentNested,
} from "./community/comments";

// ─── Infrastructure Idempotency ──────────────────────────────────────────────
export { cleanupProcessedEvents } from "./shared/idempotency";

// ─── SEO Server & Indexing ───────────────────────────────────────────────────
export { seoServer } from "./seo/seoServer";
export { rebuildDirtySitemapsScheduler } from "./seo/sitemap/sitemapScheduler";
export {
  onVideoSeoWritten,
  onChannelSeoWritten,
  onTopicSeoWritten,
  onCommunityPostSeoWritten,
  onPlaylistSeoWritten,
} from "./seo/indexing/indexingTriggers";

// ─── Monetization & Ads ───────────────────────────────────────────────────────
export { onAdCampaignWritten, triggerAdAIFeatures, generateAllVideoAdsAIFeatures } from "./ads/ads";
export {
  recordAdImpression,
  getAdRevenueBreakdown,
  getAdImpressionAudit,
} from "./ads/adRevenueDistribution";
export { onPublicPlaylistWritten, onPrivatePlaylistWritten } from "./moderation/playlistModeration";

// ─── Admin Portal APIs ───────────────────────────────────────────────────────
export * from "./admin/adminBulkModerate";
export { moderateUser, consolidateUserAccounts } from "./admin/userManagement";
export { getUnitEconomicsDashboard, getUnitEconomicsReport } from "./admin/unitEconomics";

// ─── Search Assistant & In-House Vector Search ───────────────────────────────
export { aiSearchAssistant } from "./search/aiSearch";
export { searchTruthWorld } from "./search/searchBackend";

// ─── Payments & Creator Economy ───────────────────────────────────────────────
export {
  createCashfreeOrder,
  verifyCashfreePayment,
  verifyCashfreeSubscription,
  cancelCashfreeSubscription,
  cashfreeWebhook,
  cashfreeHostedCheckout,
} from "./economy/cashfreeFunctions";
export { onPayoutRequestCreated } from "./economy/payouts";
export { detectRevenueAnomalies, reviewFraudFlag } from "./economy/fraudDetection";
export {
  detectViewFraud,
  cleanupExpiredFraudBlocks,
  rollbackFraudulentViews,
} from "./fraud/viewFraudDetection";
export { onKycDocumentCreatedOrUpdated } from "./economy/kyc";
export {
  distributePremiumRevenue,
  getPremiumRevenueBreakdown,
  triggerPremiumDistributionManual,
} from "./economy/premiumRevenueDistribution";

// ─── Edge Feed CDN Server ───────────────────────────────────────────────────
export { publicFeedServer } from "./feed/publicFeedServer";
