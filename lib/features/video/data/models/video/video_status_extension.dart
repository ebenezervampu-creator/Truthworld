import 'package:truthworld/features/video/data/models/video.dart';

/// Extension providing lifecycle, draft, and moderation approval status evaluation for [Video].
extension VideoStatusExtension on Video {
  /// Returns true if video is rejected by moderation or admin review.
  bool get isRejected {
    if (status == VideoStatus.pending_review ||
        status == VideoStatus.processing ||
        status == VideoStatus.uploading) {
      return false;
    }
    if (status == VideoStatus.rejected) return true;
    final vis = visibility.trim().toLowerCase();
    if (vis == 'rejected') return true;
    if (geminiApproved == false || isApproved == false) return true;
    return false;
  }

  /// Returns true if video is approved by Gemini AI moderation or manual admin review.
  bool get isApprovedByGeminiOrManual {
    if (isRejected) return false;
    if (status == VideoStatus.flagged ||
        status == VideoStatus.pending_review ||
        status == VideoStatus.draft ||
        status == VideoStatus.uploading) {
      return false;
    }
    final vis = visibility.trim().toLowerCase();
    if (vis == 'rejected' || vis == 'draft' || vis == 'private_draft') return false;
    if (geminiApproved == true || isApproved == true) return true;
    if (status == VideoStatus.ready) return true;
    final hasPlayable = videoUrl.trim().isNotEmpty ||
        originalUrl.trim().isNotEmpty ||
        hlsUrl.trim().isNotEmpty ||
        dashUrl.trim().isNotEmpty ||
        adaptiveResolutions.any((r) => r.url.trim().isNotEmpty);
    return hasPlayable;
  }

  /// Returns true if video visibility is set to Private.
  bool get isPrivate {
    final vis = visibility.trim().toLowerCase();
    return vis == 'private' || vis == 'private_draft';
  }

  /// Returns true if video visibility is set to Unlisted.
  bool get isUnlisted {
    final vis = visibility.trim().toLowerCase();
    return vis == 'unlisted';
  }

  /// Returns true if video visibility is Public.
  bool get isPublic {
    final vis = visibility.trim().toLowerCase();
    return vis == 'public' || vis.isEmpty;
  }

  /// Returns true if video visibility is Members Only.
  bool get isMembersOnly {
    final vis = visibility.trim().toLowerCase();
    return vis == 'members_only' || vis == 'members' || vis == 'members only';
  }

  /// Returns true if video visibility is Subscribers Only.
  bool get isSubscribersOnly {
    final vis = visibility.trim().toLowerCase();
    return vis == 'subscribers_only' || vis == 'subscribers' || vis == 'subscribers only';
  }

  /// Returns true if video is considered a draft or in preliminary stage.
  bool get isDraft {
    if (status == VideoStatus.draft || status == VideoStatus.uploading) {
      return true;
    }
    final vis = visibility.trim().toLowerCase();
    if (vis == 'draft' || vis == 'private_draft') return true;
    final t = title.trim().toLowerCase();
    if (t.isEmpty ||
        t == 'uploading...' ||
        t.startsWith('uploading') ||
        t == 'untitled' ||
        t == 'untitled draft' ||
        t.startsWith('untitled')) {
      return true;
    }
    return false;
  }

  /// Returns true if video title matches common untitled patterns.
  bool get isUntitled {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return true;
    if (t == 'untitled' ||
        t == 'untitled video' ||
        t == 'untitled draft' ||
        t == 'untitled campaign' ||
        t == 'untitled playlist' ||
        t == 'untitled topic' ||
        t.startsWith('untitled') ||
        t == 'uploading...' ||
        t.startsWith('uploading')) {
      return true;
    }
    return false;
  }

  /// Returns true if video is currently uploading, transcoding, or pending review without playable media.
  bool get isUploadingOrProcessing {
    if (isDraft) return true;
    if (status == VideoStatus.uploading ||
        status == VideoStatus.draft ||
        status == VideoStatus.pending_review) {
      return true;
    }
    final hasPlayable = videoUrl.trim().isNotEmpty ||
        originalUrl.trim().isNotEmpty ||
        hlsUrl.trim().isNotEmpty ||
        dashUrl.trim().isNotEmpty ||
        adaptiveResolutions.any((r) => r.url.trim().isNotEmpty);

    if (status == VideoStatus.processing && !hasPlayable) {
      return true;
    }
    final statusName = status.name.toLowerCase();
    if (statusName == 'uploading' ||
        statusName == 'uploaded' ||
        statusName == 'draft' ||
        statusName == 'pending_review' ||
        statusName == 'pending') {
      return true;
    }
    if (statusName == 'processing' && !hasPlayable) {
      return true;
    }
    return false;
  }
}
