import 'package:truthworld/features/video/data/models/video.dart';

/// Centralized single source of truth for video visibility policy and rules.
class VideoVisibilityPolicy {
  static const VideoStatus publicStatus = VideoStatus.ready;
  static const String publicVisibilityString = 'Public';

  /// Standard check for Home Feed, Trending, and Category carousels
  static bool isVisibleForFeed(Video video) {
    if (!_isBasicStatusValid(video)) return false;
    if (video.visibility != publicVisibilityString && video.visibility != 'public') return false;
    if (_isScheduledInFuture(video)) return false;
    if (_isChannelDeleted(video)) return false;
    return true;
  }

  /// Search & Autocomplete visibility check
  static bool isVisibleForSearch(Video video) {
    if (!_isBasicStatusValid(video)) return false;
    if (video.visibility != publicVisibilityString && video.visibility != 'public') return false;
    if (_isScheduledInFuture(video)) return false;
    if (_isChannelDeleted(video)) return false;
    return true;
  }

  /// Recommendation engine visibility check
  static bool isVisibleForRecommendation(Video video) {
    return isVisibleForFeed(video);
  }

  /// Watch History visibility check
  /// Allows rendering history entries, but caller can detect if underlying video is invalid
  static bool isVisibleForHistory(Video video) {
    return video.status != VideoStatus.deleted;
  }

  /// Check basic video status against deleted / pending deletion
  static bool _isBasicStatusValid(Video video) {
    if (video.status == VideoStatus.deleted) return false;
    // Handle string representation if status is pending deletion
    final statusName = video.status.name.toLowerCase();
    if (statusName == 'deleted' || statusName == 'deletion_pending') return false;
    return true;
  }

  /// Check if scheduled video publish timestamp is in the future
  static bool _isScheduledInFuture(Video video) {
    if (video.scheduledPublishAt != null) {
      return video.scheduledPublishAt!.isAfter(DateTime.now());
    }
    return false;
  }

  /// Check if parent channel status is marked deleted or deletion_pending
  static bool _isChannelDeleted(Video video) {
    // Model level denormalized checks
    if (video.channelStatus != null) {
      final chStatus = video.channelStatus!.toLowerCase();
      if (chStatus == 'deleted' || chStatus == 'deletion_pending') return true;
    }
    return false;
  }
}
