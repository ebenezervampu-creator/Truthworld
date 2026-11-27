/**
 * 🚀 FIREBASE CLOUD FUNCTIONS (2nd Gen) — TRUTHWORLD BACKEND
 *
 * Industry-standard modular entry point for TruthWorld Cloud Functions.
 *
 * Core architectural domains:
 * 1.  AI Video Processing Pipeline (Ingestion, Transcription, Credibility, Dubbing, Aggregation)
 * 2.  Video Resolution & Multi-Bitrate Transcoding (≤ 1040p / 60fps)
 * 3.  Publish-Gated Job Scheduling & Shard Replication
 * 4.  SWR Edge Cache Queues & Storage Maintenance
 * 5.  Content Moderation & Safety Verification
 * 6.  Watchtime, Viewers & Analytics Telemetry
 * 7.  Creator Channels, Social Graph & Discovery
 * 8.  User Notifications & Activity Signals
 * 9.  Community Discussion & Nested Comments
 * 10. Search Engine & Typesense Cluster Sync
 * 11. Payments, Subscriptions & Creator Economy (Cashfree)
 * 12. Automated SEO, Sitemaps & Dynamic Meta Rendering
 * 13. Platform Administration, Unit Economics & Phase Quotas
 * 14. Edge Feed CDN Distribution
 * 15. IFCN Fact-Check Appeals Desk & Credibility AI
 *
 * Global Configuration:
 * - Region: asia-south1
 * - Scale-to-zero (minInstances: 0) for cost efficiency
 * - Default maxInstances: 10
 */

import * as admin from "firebase-admin";

// ─── Initialize Firebase Admin SDK (Single Instance) ─────────────────────────
if (!admin.apps.length) {
  admin.initializeApp({
    databaseURL: "https://truthworld-1-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "truthworld-1.firebasestorage.app",
  });
}
admin.firestore().settings({ ignoreUndefinedProperties: true });

import { setGlobalOptions } from "firebase-functions/v2";

// ─── Global Default Options for 2nd Gen Functions ────────────────────────────
setGlobalOptions({
  region: "asia-south1",
  maxInstances: 10,
  cpu: "gcf_gen1",
});

// ─── Shared Infrastructure & Configuration ───────────────────────────────────
export * from "./config";
export * from "./shared";

// ─── 1. AI Video Processing Pipeline ─────────────────────────────────────────
export * from "./pipeline/pipelineTriggers";

// ─── 2. Video Resolution & Chapter Thumbnails (≤ 1040p) ───────────────────────
export {
  onVideoUploadedForResolution,
  handleResolution,
  onTranscoderJobCompleted,
  getVideoResolutionStatus,
  getResolutionProfiles,
  captureChapterThumbnail,
  generateVideoChapterThumbnails,
  reconcileStuckResolutionJobsScheduled,
  reconcileVideoResolutionManual,
} from "./resolution/resolution";

// ─── 3. Video Publishing Gate & Fan-Out ──────────────────────────────────────
export * from "./publishing/videoPublishTrigger";
export * from "./publishing/videoDeletionTrigger";
export * from "./publishing/shardSync";
export { scheduledVideoPublisher } from "./publishing/scheduledPublishing";

// ─── 4. SWR Edge Cache Queues & Storage Lifecycle Maintenance ────────────────
export * from "./swr/swrQueues";
export * from "./maintenance/storageCleanup";

// ─── 5. Content Moderation & Image Verification ──────────────────────────────
export {
  onContentUploadedForModeration,
  moderateVideoManual,
  scheduledContentModerationRetry,
  resubmitVideoForModeration,
  submitVideoReport,
} from "./moderation/contentModeration";
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

// ─── 6. Watchtime, Analytics & Live Viewers ──────────────────────────────────
export {
  trackWatchEvent,
  aggregateWatchStats,
  cleanupOldEvents,
} from "./watchtime/watchtime";
export {
  checkGuestWatchQuota,
  reportGuestWatchPulse,
} from "./watchtime/guestWatchLimit";
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
export { rollupVideoCounterShards, reconcileChannelMetrics } from "./analytics/counterRollup";
export {
  BigQueryAnalyticsService,
  getBigQueryAnalyticsService,
  setBigQueryAnalyticsService,
} from "./analytics/bigqueryService";

// ─── 7. Creator Channels, Social Graph & Discovery ───────────────────────────
export {
  createChannel,
  getPlatformCapacity,
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
export {
  onChannelWritten,
  onImageVerificationWritten,
  moderateChannelManual,
  setChannelModerationBypass,
  isChannelTrustedModerationBypassed,
} from "./channels/moderation";
export { getLeaderboard } from "./channels/discovery";
export { onTopicWritten, moderateTopicManual } from "./topics/moderation";
export { getHomeFeed } from "./channels/recommendations";
export {
  getAlgorithmRemoteConfig,
  updateAlgorithmRemoteConfig,
} from "./algorithm/remoteConfig";

// ─── 8. User Notifications & Signals ─────────────────────────────────────────
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
  onVideoCommentReplyCreated,
  onNewSubscription,
  onChannelSubscriberWritten,
  onCommunityPostCreated,
  onCommunityPostUpdated,
  onCommunityCommentCreated,
  onCommunityCommentReplyCreated,
  onCommunityCommentUpdated,
  onCommunityReplyUpdated,
  onTopicReplyCreated,
  onTopicCommentLikeCreated,
  onTopicReplyLikeCreated,
  onClaimCommentCreated,
  onClaimCommentUpdated,
  onUserNotificationCreated,
} from "./notifications/triggers";
export { trackActivity } from "./users/signals";
export {
  onUserCreated,
  onUserDeleted,
  purgeUserAccount,
  checkUserRegistrationCapacity,
} from "./users/userLifecycle";

// ─── 9. Platform Phase Administration & Capacity ─────────────────────────────
export {
  PLATFORM_LIMITS,
  ACTIVE_PHASE,
  PHASE_CONFIGS,
  getPhaseConfig,
  getDynamicPlatformLimits,
  clearLimitsCache,
} from "./config/platformLimits";
export {
  setPlatformPhase,
  getPlatformPhaseConfig,
  admitWaitlistedUsers,
} from "./admin/platformPhaseAdmin";

// ─── 10. Comments & Community Discussion ─────────────────────────────────────
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

// ─── 11. Infrastructure Idempotency ──────────────────────────────────────────
export { cleanupProcessedEvents } from "./shared/idempotency";

// ─── 12. SEO Server, Dynamic Rendering & Sitemaps ────────────────────────────
export { seoServer } from "./seo/seoServer";
export { rebuildDirtySitemapsScheduler } from "./seo/sitemap/sitemapScheduler";
export {
  onVideoSeoWritten,
  onChannelSeoWritten,
  onTopicSeoWritten,
  onCommunityPostSeoWritten,
  onPlaylistSeoWritten,
} from "./seo/indexing/indexingTriggers";

// ─── 13. Monetization, Ads & Playlists ───────────────────────────────────────
export { onAdCampaignWritten, triggerAdAIFeatures, generateAllVideoAdsAIFeatures } from "./ads/ads";
export {
  recordAdImpression,
  getAdRevenueBreakdown,
  getAdImpressionAudit,
} from "./ads/adRevenueDistribution";
export { onPublicPlaylistWritten, onPrivatePlaylistWritten } from "./moderation/playlistModeration";

// ─── 14. Admin Portal APIs ───────────────────────────────────────────────────
export * from "./admin/adminBulkModerate";
export { moderateUser, consolidateUserAccounts } from "./admin/userManagement";
export { getUnitEconomicsDashboard, getUnitEconomicsReport, getChannelSpendingsAndRevenue } from "./admin/unitEconomics";
export {
  sendAdminCredentials,
  verifyAdminUsername,
  changeAdminPassword,
  seedDefaultAdmins,
  updateAdminMember,
  deleteAdminMember,
} from "./admin/adminMemberEndpoints";
export { sendBroadcastPushNotification } from "./admin/broadcastPushNotification";

// ─── 15. Search Assistant & In-House Vector Search ───────────────────────────
export { aiSearchAssistant } from "./search/aiSearch";
export { searchTruthWorld, recordSearchClickthrough } from "./search/searchBackend";
export {
  onVideoWrittenTypesenseSync,
  onChannelWrittenTypesenseSync,
  onTopicWrittenTypesenseSync,
} from "./search/typesense/typesenseTriggers";
export { triggerTypesenseBackfill } from "./search/typesense/backfillTypesense";

// ─── 16. Payments & Creator Economy (Cashfree) ───────────────────────────────
export {
  createCashfreeOrder,
  verifyCashfreePayment,
  verifyCashfreeSubscription,
  cancelCashfreeSubscription,
  cashfreeWebhook,
  cashfreeHostedCheckout,
} from "./economy/cashfreeFunctions";
export {
  onPayoutRequestCreated,
  autoDisburseMonthlyPayoutsScheduler,
  triggerMonthlyAutoDisbursementManual,
} from "./economy/payouts";
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
export { spendChannelWallet } from "./economy/spendWallet";
export { monthlyZeroWasteRollover } from "./economy/monthlyRollover";
export {
  reconcilePendingSettlementsScheduler,
  reconcileChannelSettlementCallable,
} from "./economy/settlementService";

// ─── 17. Edge Feed CDN Server ────────────────────────────────────────────────
export { publicFeedServer } from "./feed/publicFeedServer";

// ─── 18. IFCN Fact-Check Appeals Desk & AI Credibility Assistant ────────────
export {
  submitClaimAppeal,
  submitFactualDispute,
  resolveClaimAppeal,
  verifyGovernanceAuditChain,
  reviewCommunityEvidence,
  sweepPendingAppealsSla,
} from "./pipeline/appealsDeskEndpoints";
export { chatWithCredibilityAi, streamCredibilityAiChat } from "./pipeline/aiCredibilityChat";

// ─── 19. Standalone Dubbing Studio & Multilingual Voice Cloning ───────────
export {
  claimFreeDubbingCredits,
  getDubbingWallet,
  createDubbingJob,
  updateDubbingTranscription,
  regenerateDubbingSegment,
  exportDubbingAssets,
  purchaseDubbingCreditsWithStudioWallet,
} from "./dubbing/standaloneDubbing";
export {
  adminGrantDubbingCredits,
  adminSetDubbingDiscount,
  adminGetDubbingUserDetails,
  adminListDubbingAccounts,
  adminGrantChannelDubbingCredits,
} from "./dubbing/adminDubbing";

