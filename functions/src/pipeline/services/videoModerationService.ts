/**
 * 🛡️ VIDEO CONTENT MODERATION SERVICE (Backward Compatibility Wrapper)
 *
 * NOTE: This service has been renamed to ContentModerationService in ./contentModerationService.
 * This file is retained to provide 100% backward compatibility for existing imports and tests.
 */

export * from "./contentModerationService";
export {
  ContentModerationService as VideoModerationService,
  contentModerationService as videoModerationService,
  type ContentModerationResult as VideoModerationResult,
  ContentModerationResponseSchema as VideoModerationResponseSchema,
} from "./contentModerationService";
