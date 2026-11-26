/**
 * 👑 ADMIN DOMAIN BARREL
 *
 * Provides Administrative APIs for TruthWorld operators:
 * - Member management (seed, invite, role updates, credentials)
 * - Platform rollout phase transitions & waitlist admissions
 * - User consolidation & moderation
 * - Unit economics reporting & telemetry
 * - Global push broadcasts
 * - Bulk content moderation
 */

export * from "./adminBulkModerate";
export * from "./userManagement";
export * from "./unitEconomics";
export * from "./adminMemberEndpoints";
export * from "./broadcastPushNotification";
export * from "./platformPhaseAdmin";
