import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Centralized single source of truth for video visibility policy and rules.
class VideoVisibilityPolicy {
  static const VideoStatus publicStatus = VideoStatus.ready;
  static const String publicVisibilityString = 'Public';

  /// Returns true if video visibility is set to Private.
  static bool isPrivate(Video video) {
    final vis = video.visibility.trim().toLowerCase();
    return vis == 'private' || vis == 'private_draft';
  }

  /// Returns true if the viewer is authenticated and owns the video or channel.
  static bool isOwner(Video video, {String? viewerUid, String? viewerChannelId}) {
    var uid = viewerUid;
    if (uid == null) {
      try {
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        uid = null;
      }
    }
    final activeChannel =
        Get.isRegistered<AuthService>() ? AuthService.to.userChannel : null;
    final chId =
        viewerChannelId ?? activeChannel?.channelId ?? activeChannel?.id;

    if ((uid == null || uid.isEmpty) && (chId == null || chId.isEmpty)) {
      return false;
    }

    // Check direct ownerId / uploader match
    if (uid != null && uid.isNotEmpty && video.ownerId.isNotEmpty && video.ownerId == uid) {
      return true;
    }

    // Check active channel match
    if (chId != null && chId.isNotEmpty && video.channelId.isNotEmpty && chId == video.channelId) {
      return true;
    }
    if (activeChannel != null &&
        uid != null &&
        activeChannel.ownerId.isNotEmpty &&
        activeChannel.ownerId == uid &&
        activeChannel.channelId == video.channelId) {
      return true;
    }

    return false;
  }

  /// Authoritative check: can this viewer view this video?
  /// When a video is Private, ONLY the channel/video owner can view it.
  static bool canViewVideo(Video video, {String? viewerUid, String? viewerChannelId}) {
    if (isPrivate(video)) {
      return isOwner(video, viewerUid: viewerUid, viewerChannelId: viewerChannelId);
    }
    return isValidVideo(video);
  }

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
    if (hasPlayableMedia(video)) return true;
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
        statusName == 'uploaded') {
      return false;
    }
    if (statusName == 'processing' && !hasPlayableMedia(video)) {
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
        visibilityStr == 'draft' ||
        visibilityStr == 'private' ||
        visibilityStr == 'private_draft') {
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
    if (isPrivate(video)) return false;
    final vis = video.visibility.trim().toLowerCase();
    if (vis.isNotEmpty &&
        vis != 'public' &&
        vis != publicVisibilityString.toLowerCase()) {
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
    if (isPrivate(video)) return false;
    final vis = video.visibility.trim().toLowerCase();
    if (vis.isNotEmpty &&
        vis != 'public' &&
        vis != publicVisibilityString.toLowerCase()) {
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


