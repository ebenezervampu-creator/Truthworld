import 'package:get/get.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Reusable sanitization pipeline for filtering video lists across feeds,
/// recommendations, search results, and history.
class VideoSanitizer {
  /// Primary sanitization pipeline:
  /// 1. Remove duplicate video IDs
  /// 2. Remove deleted or pending-deletion videos
  /// 3. Remove hidden videos (Not interested) & blocked channel videos
  /// 4. Filter blocked users (Settings -> Blocked Users)
  /// 5. Filter muted keywords (Settings -> Muted Keywords)
  /// 6. Enforce Restricted Mode / Parental PIN content protection
  /// 7. Enforce surface-specific policy
  static List<Video> sanitize(
    List<Video> videos, {
    required bool Function(Video) policyCheck,
    List<String>? blockedChannelIds,
  }) {
    final seenIds = <String>{};
    final sanitized = <Video>[];

    final hasUserPrefs = Get.isRegistered<UserPreferencesService>();
    final userPrefs = hasUserPrefs ? UserPreferencesService.to : null;

    final hasUserSettings = Get.isRegistered<UserSettingsController>();
    final userSettings = hasUserSettings ? UserSettingsController.to : null;

    final blockedUsersList = userSettings?.blockedUsers.map((u) => u.toLowerCase().replaceAll('@', '').trim()).toSet() ?? {};
    final mutedKeywordsList = userSettings?.mutedKeywords.map((k) => k.toLowerCase().trim()).where((k) => k.isNotEmpty).toList() ?? [];
    final isRestrictedModeActive = userSettings?.wellbeing.value.parentalPinEnabled ?? false;

    for (final video in videos) {
      if (video.id.isEmpty) continue;
      if (!VideoVisibilityPolicy.isValidVideo(video)) continue;

      // 1. Deduplicate by video ID
      if (seenIds.contains(video.id)) continue;

      // 2. Filter user preference blocked/hidden videos & channels
      if (userPrefs != null && userPrefs.isVideoBlocked(video)) {
        continue;
      }

      // 3. Filter explicit parameter blocked channels
      if (blockedChannelIds != null &&
          blockedChannelIds.contains(video.channelId)) {
        continue;
      }

      // 4. Filter blocked users by channel name, ID, or owner handle
      if (blockedUsersList.isNotEmpty) {
        final channelLower = video.channelName.toLowerCase().trim();
        final channelIdLower = video.channelId.toLowerCase().trim();
        final ownerLower = video.ownerId.toLowerCase().trim();
        if (blockedUsersList.contains(channelLower) ||
            blockedUsersList.contains(channelIdLower) ||
            blockedUsersList.contains(ownerLower)) {
          continue;
        }
      }

      // 5. Filter muted keywords in title, description, or tags
      if (mutedKeywordsList.isNotEmpty) {
        final titleLower = video.title.toLowerCase();
        final descLower = video.description.toLowerCase();
        final tagsLower = video.tags.map((t) => t.toLowerCase()).join(' ');

        var containsMuted = false;
        for (final kw in mutedKeywordsList) {
          if (titleLower.contains(kw) ||
              descLower.contains(kw) ||
              tagsLower.contains(kw)) {
            containsMuted = true;
            break;
          }
        }
        if (containsMuted) continue;
      }

      // 6. Enforce Restricted Mode (Parental PIN lock)
      if (isRestrictedModeActive) {
        // If restricted mode is enabled, filter videos flagged as not kid friendly
        // or containing mature/adult keywords
        final textToCheck = '${video.title} ${video.description} ${video.tags.join(" ")}'.toLowerCase();
        const sensitiveKeywords = [
          '18+', 'nsfw', 'mature', 'violence', 'explicit', 'adult', 'gore'
        ];
        var isSensitive = false;
        for (final kw in sensitiveKeywords) {
          if (textToCheck.contains(kw)) {
            isSensitive = true;
            break;
          }
        }
        if (isSensitive) continue;
      }

      // 7. Apply surface-aware policy check
      if (!policyCheck(video)) continue;

      seenIds.add(video.id);
      sanitized.add(video);
    }

    return sanitized;
  }

  /// Convenience method for Home, Trending, and Category feeds
  static List<Video> sanitizeForFeed(
    List<Video> videos, {
    List<String>? blockedChannelIds,
  }) {
    return sanitize(
      videos,
      policyCheck: VideoVisibilityPolicy.isVisibleForFeed,
      blockedChannelIds: blockedChannelIds,
    );
  }

  /// Convenience method for Search results
  static List<Video> sanitizeForSearch(
    List<Video> videos, {
    List<String>? blockedChannelIds,
  }) {
    return sanitize(
      videos,
      policyCheck: VideoVisibilityPolicy.isVisibleForSearch,
      blockedChannelIds: blockedChannelIds,
    );
  }

  /// Convenience method for Recommendations
  static List<Video> sanitizeForRecommendation(
    List<Video> videos, {
    List<String>? blockedChannelIds,
  }) {
    return sanitize(
      videos,
      policyCheck: VideoVisibilityPolicy.isVisibleForRecommendation,
      blockedChannelIds: blockedChannelIds,
    );
  }

  /// Convenience method for Watch History
  static List<Video> sanitizeForHistory(List<Video> videos) {
    return sanitize(
      videos,
      policyCheck: VideoVisibilityPolicy.isVisibleForHistory,
    );
  }
}

/// Extension on List<Video> for clean inline filtering in controllers
extension VideoListSanitizerExtension on List<Video> {
  List<Video> sanitizeForFeed({List<String>? blockedChannelIds}) {
    return VideoSanitizer.sanitizeForFeed(
      this,
      blockedChannelIds: blockedChannelIds,
    );
  }

  List<Video> sanitizeForSearch({List<String>? blockedChannelIds}) {
    return VideoSanitizer.sanitizeForSearch(
      this,
      blockedChannelIds: blockedChannelIds,
    );
  }

  List<Video> sanitizeForRecommendation({List<String>? blockedChannelIds}) {
    return VideoSanitizer.sanitizeForRecommendation(
      this,
      blockedChannelIds: blockedChannelIds,
    );
  }
}
