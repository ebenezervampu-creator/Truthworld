import 'package:truthworld/features/video/data/models/video.dart';

/// Centralized single source of truth for video visibility policy and rules.
class VideoVisibilityPolicy {
  static const VideoStatus publicStatus = VideoStatus.ready;
  static const String publicVisibilityString = 'Public';

  /// Industry standard check: video must have at least one valid, non-empty media URL.
  static bool hasPlayableMedia(Video video) {
    if (video.videoUrl.trim().isNotEmpty) return true;
    if (video.originalUrl.trim().isNotEmpty) return true;
    if (video.hlsUrl.trim().isNotEmpty) return true;
    if (video.dashUrl.trim().isNotEmpty) return true;
    if (video.adaptiveResolutions.any((r) => r.url.trim().isNotEmpty)) {
      return true;
    }
    return false;
  }

  /// Industry standard check: video should have a valid thumbnail image or preview source.
  static bool hasValidThumbnail(Video video) {
    if (video.thumbnailUrl.trim().isNotEmpty) return true;
    if (video.thumbnailVariants.any((v) => v.trim().isNotEmpty)) return true;
    if (video.animatedPreviewUrl.trim().isNotEmpty) return true;
    return false;
  }

  /// Primary validity check: video must not be untitled, uploading, processing, draft, deleted, unapproved, or missing media.
  static bool isValidVideo(Video video) {
    if (video.isDraft) return false;
    if (video.isUntitled) return false;
    if (video.isUploadingOrProcessing) return false;
    if (video.visibility.toLowerCase() == 'draft') return false;
    if (video.status == VideoStatus.deleted ||
        video.status == VideoStatus.rejected) {
      return false;
    }
    final statusName = video.status.name.toLowerCase();
    if (statusName == 'deleted' ||
        statusName == 'deletion_pending' ||
        statusName == 'rejected' ||
        statusName == 'draft' ||
        statusName == 'uploading' ||
        statusName == 'uploaded' ||
        statusName == 'processing') {
      return false;
    }

    // Must be approved by Gemini AI moderation or manual review
    if (!video.isApprovedByGeminiOrManual) return false;

    // Must contain playable video stream URL
    if (!hasPlayableMedia(video)) return false;
    return true;
  }

  /// Raw Map validator for queries returning Map structures directly
  static bool isMapValid(Map<String, dynamic> data) {
    final title = (data['title'] as String?)?.trim() ?? '';
    final titleLower = title.toLowerCase();
    if (title.isEmpty ||
        titleLower == 'untitled' ||
        titleLower == 'untitled video' ||
        titleLower == 'untitled draft' ||
        titleLower == 'uploading...' ||
        titleLower.startsWith('untitled') ||
        titleLower.startsWith('uploading')) {
      return false;
    }

    final statusStr = (data['status'] as String?)?.toLowerCase() ?? '';
    final pipelineStage = ((data['aiFeatures'] is Map
                ? data['aiFeatures']['pipelineStage']
                : null) ??
            data['pipelineStage'])
        ?.toString()
        .toLowerCase();
    final visibilityStr = (data['visibility'] as String?)?.toLowerCase() ?? '';

    final isPublished = pipelineStage == 'published' ||
        data['isPublished'] == true ||
        (data['publishedAt'] != null && data['publishedAt'] != 0);

    if (statusStr == 'deleted' ||
        statusStr == 'deletion_pending' ||
        statusStr == 'rejected' ||
        statusStr == 'draft' ||
        statusStr == 'pending_review' ||
        statusStr == 'pending' ||
        pipelineStage == 'draft' ||
        visibilityStr == 'draft') {
      return false;
    }

    if (!isPublished &&
        (statusStr == 'uploading' ||
         statusStr == 'uploaded' ||
         statusStr == 'processing')) {
      return false;
    }

    // Gemini AI / Manual moderation approval check
    final moderationMap = data['moderation'] is Map ? data['moderation'] as Map : null;
    final moderationStatus = moderationMap?['status']?.toString().toLowerCase();
    final policyAction = moderationMap?['policyAction']?.toString().toLowerCase();
    final isModApproved = moderationStatus == 'approved' || policyAction == 'allow';

    final geminiApproved = data['geminiApproved'] as bool? ??
        (moderationMap?['geminiApproved'] as bool?) ??
        (isModApproved ? true : null);
    final isApproved = data['isApproved'] as bool? ??
        (moderationMap?['isApproved'] as bool?) ??
        (isModApproved ? true : null) ??
        (data['gatewayStatus'] == 'APPROVED' ? true : null) ??
        (data['isVerified'] == true ? true : null) ??
        (data['credibilityVerified'] == true ? true : null);
    if (geminiApproved == false || isApproved == false) {
      return false;
    }

    // Media stream validation for raw Maps
    final videoUrl = (data['videoUrl'] as String?)?.trim() ?? '';
    final originalUrl = (data['originalUrl'] as String?)?.trim() ?? '';
    final hlsUrl = (data['hlsUrl'] as String?)?.trim() ?? '';
    final dashUrl = (data['dashUrl'] as String?)?.trim() ?? '';
    final adaptiveResolutions = data['adaptiveResolutions'] as List?;
    final hasAdaptive = adaptiveResolutions != null &&
        adaptiveResolutions.isNotEmpty &&
        adaptiveResolutions.any(
          (r) =>
              r is Map &&
              (r['url'] as String?)?.trim().isNotEmpty == true,
        );

    if (videoUrl.isEmpty &&
        originalUrl.isEmpty &&
        hlsUrl.isEmpty &&
        dashUrl.isEmpty &&
        !hasAdaptive) {
      return false;
    }

    return true;
  }

  /// Standard check for Home Feed, Trending, and Category carousels
  static bool isVisibleForFeed(Video video) {
    if (!isValidVideo(video)) return false;
    if (video.visibility != publicVisibilityString &&
        video.visibility != 'public') {
      return false;
    }
    if (!hasValidThumbnail(video)) return false;
    if (_isScheduledInFuture(video)) return false;
    if (_isChannelDeleted(video)) return false;
    return true;
  }

  /// Search & Autocomplete visibility check
  static bool isVisibleForSearch(Video video) {
    if (!isValidVideo(video)) return false;
    if (video.visibility != publicVisibilityString &&
        video.visibility != 'public') {
      return false;
    }
    if (!hasValidThumbnail(video)) return false;
    if (_isScheduledInFuture(video)) return false;
    if (_isChannelDeleted(video)) return false;
    return true;
  }

  /// Recommendation engine visibility check
  static bool isVisibleForRecommendation(Video video) {
    return isVisibleForFeed(video);
  }

  /// Watch History visibility check
  static bool isVisibleForHistory(Video video) {
    return isValidVideo(video);
  }

  /// Check basic video status against deleted / pending deletion
  static bool _isBasicStatusValid(Video video) {
    return isValidVideo(video);
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


