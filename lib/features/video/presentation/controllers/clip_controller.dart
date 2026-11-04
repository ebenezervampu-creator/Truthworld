import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:uuid/uuid.dart';

class ClipController extends BaseController {
  ClipController({required this.video});
  final Video video;

  final RxDouble startSeconds = 0.0.obs;
  final RxDouble endSeconds = 15.0.obs; // Default 15s clip
  final RxDouble totalDuration = 300.0.obs;
  final RxDouble currentVideoPosition = 0.0.obs;
  final RxString clipTitle = ''.obs;
  final RxString titleError = ''.obs;
  final RxBool isSaving = false.obs;
  final RxBool isPreviewPlaying = false.obs;

  VideoController? videoControllerRef;
  Timer? _previewTimer;

  // Industry standard duration bounds
  double get minDuration => 5.0; // Minimum 5 seconds to prevent micro-spam & glitches
  double get maxDuration => 30.0; // Maximum 30 seconds to prevent piracy

  static const int maxLibraryClips = 50; // Quota per user to prevent database abuse
  static const int actionCooldownSeconds = 10; // 10s cooldown to throttle automated spam
  static DateTime? _lastClipActionTime;

  /// Initialize state for the clip creation dialog
  void initialize({
    required double totalDur,
    required double currentPos,
    VideoController? videoCtrl,
  }) {
    totalDuration.value = totalDur > 0 ? totalDur : 300.0;
    currentVideoPosition.value = currentPos;
    videoControllerRef = videoCtrl;

    final maxDur = totalDuration.value;
    final initialStart = currentPos.clamp(0.0, (maxDur - minDuration).clamp(0.0, maxDur));
    final initialEnd = (initialStart + 15.0).clamp(
      (initialStart + minDuration).clamp(0.0, maxDur),
      maxDur,
    );

    startSeconds.value = initialStart;
    endSeconds.value = initialEnd;
    titleError.value = '';
    clipTitle.value = '';
    isPreviewPlaying.value = false;
  }

  /// Check if the video is eligible for clipping based on creator preferences and safety guidelines
  String? getClippingRestrictionReason() {
    if (!video.allowClipping) {
      return 'The creator has disabled clipping for this video.';
    }
    if (video.isKidFriendly) {
      return 'Clipping is not available on content made for kids.';
    }
    if (video.durationValue.inSeconds > 0 && video.durationValue.inSeconds < 15) {
      return 'This video is too short to create clips from (minimum 15 seconds required).';
    }
    return null;
  }

  /// Real-time content validation for clip titles using ContentValidator
  String? validateClipTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a title for your clip';
    }
    if (trimmed.length < 3) {
      return 'Clip title must be at least 3 characters long';
    }
    if (trimmed.length > 100) {
      return 'Clip title cannot exceed 100 characters';
    }

    final validation = ContentValidator.validate(
      trimmed,
      fieldName: 'Clip title',
      minLength: 3,
      maxLength: 100,
      checkPhoneNumbers: true,
    );

    if (!validation.isValid) {
      return validation.message;
    }
    return null;
  }

  void onTitleChanged(String value) {
    clipTitle.value = value;
    if (value.isNotEmpty) {
      titleError.value = validateClipTitle(value) ?? '';
    } else {
      titleError.value = '';
    }
  }

  void updateStart(double value) {
    if (value <= endSeconds.value - minDuration) {
      if (endSeconds.value - value <= maxDuration) {
        startSeconds.value = value;
      } else {
        startSeconds.value = value;
        endSeconds.value = value + maxDuration;
      }
    }
  }

  void updateEnd(double value) {
    if (value >= startSeconds.value + minDuration) {
      if (value - startSeconds.value <= maxDuration) {
        endSeconds.value = value;
      } else {
        endSeconds.value = startSeconds.value + maxDuration;
      }
    }
  }

  /// Quickly set duration preset (5s, 10s, 15s, 30s)
  void setDurationPreset(double durationSeconds) {
    final targetSpan = durationSeconds.clamp(minDuration, maxDuration);
    final total = totalDuration.value;

    if (startSeconds.value + targetSpan <= total) {
      endSeconds.value = startSeconds.value + targetSpan;
    } else {
      endSeconds.value = total;
      startSeconds.value = (total - targetSpan).clamp(0.0, total);
    }
  }

  /// Fine-tune start time by +1s, -1s, etc.
  void stepStart(double delta) {
    final total = totalDuration.value;
    final targetStart = (startSeconds.value + delta).clamp(0.0, (total - minDuration).clamp(0.0, total));

    if (targetStart <= endSeconds.value - minDuration) {
      if (endSeconds.value - targetStart <= maxDuration) {
        startSeconds.value = targetStart;
      } else {
        startSeconds.value = targetStart;
        endSeconds.value = (targetStart + maxDuration).clamp(targetStart + minDuration, total);
      }
    } else {
      startSeconds.value = targetStart;
      endSeconds.value = (targetStart + minDuration).clamp(targetStart + minDuration, total);
    }

    videoControllerRef?.videoPlayerController?.seekTo(
      Duration(milliseconds: (startSeconds.value * 1000).toInt()),
    );
  }

  /// Fine-tune end time by +1s, -1s, etc.
  void stepEnd(double delta) {
    final total = totalDuration.value;
    final targetEnd = (endSeconds.value + delta).clamp(minDuration, total);

    if (targetEnd >= startSeconds.value + minDuration) {
      if (targetEnd - startSeconds.value <= maxDuration) {
        endSeconds.value = targetEnd;
      } else {
        endSeconds.value = targetEnd;
        startSeconds.value = (targetEnd - maxDuration).clamp(0.0, total);
      }
    } else {
      endSeconds.value = targetEnd;
      startSeconds.value = (targetEnd - minDuration).clamp(0.0, total);
    }

    videoControllerRef?.videoPlayerController?.seekTo(
      Duration(milliseconds: (endSeconds.value * 1000).toInt()),
    );
  }

  /// Shift entire segment window left or right preserving length
  void shiftSegment(double delta) {
    final total = totalDuration.value;
    final span = endSeconds.value - startSeconds.value;

    var newStart = (startSeconds.value + delta).clamp(0.0, (total - span).clamp(0.0, total));
    var newEnd = newStart + span;

    if (newEnd > total) {
      newEnd = total;
      newStart = (total - span).clamp(0.0, total);
    }

    startSeconds.value = newStart;
    endSeconds.value = newEnd;

    videoControllerRef?.videoPlayerController?.seekTo(
      Duration(milliseconds: (startSeconds.value * 1000).toInt()),
    );
  }

  /// Set start time to current player position
  void setStartToPlayhead() {
    final vpc = videoControllerRef?.videoPlayerController;
    final currentPos = vpc != null && vpc.value.isInitialized
        ? vpc.value.position.inMilliseconds / 1000.0
        : currentVideoPosition.value;

    final total = totalDuration.value;
    final newStart = currentPos.clamp(0.0, (total - minDuration).clamp(0.0, total));
    final span = (endSeconds.value - startSeconds.value).clamp(minDuration, maxDuration);

    var newEnd = (newStart + span).clamp(newStart + minDuration, total);
    if (newEnd - newStart > maxDuration) {
      newEnd = newStart + maxDuration;
    }

    startSeconds.value = newStart;
    endSeconds.value = newEnd;

    vpc?.seekTo(Duration(milliseconds: (newStart * 1000).toInt()));
  }

  /// Set end time to current player position
  void setEndToPlayhead() {
    final vpc = videoControllerRef?.videoPlayerController;
    final currentPos = vpc != null && vpc.value.isInitialized
        ? vpc.value.position.inMilliseconds / 1000.0
        : currentVideoPosition.value;

    final total = totalDuration.value;
    final newEnd = currentPos.clamp(minDuration, total);
    final span = (endSeconds.value - startSeconds.value).clamp(minDuration, maxDuration);

    var newStart = (newEnd - span).clamp(0.0, (newEnd - minDuration).clamp(0.0, total));
    if (newEnd - newStart > maxDuration) {
      newStart = newEnd - maxDuration;
    }

    startSeconds.value = newStart;
    endSeconds.value = newEnd;

    vpc?.seekTo(Duration(milliseconds: (newEnd * 1000).toInt()));
  }

  /// Toggle preview loop playback for the selected segment
  void togglePreview() {
    if (isPreviewPlaying.value) {
      stopPreview();
    } else {
      startPreview();
    }
  }

  void startPreview() {
    final vpc = videoControllerRef?.videoPlayerController;
    if (vpc == null || !vpc.value.isInitialized) return;

    isPreviewPlaying.value = true;
    vpc.seekTo(Duration(milliseconds: (startSeconds.value * 1000).toInt())).then((_) {
      if (isPreviewPlaying.value) {
        vpc.play();
      }
    });

    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!isPreviewPlaying.value) {
        _previewTimer?.cancel();
        return;
      }
      final currentPosSec = vpc.value.position.inMilliseconds / 1000.0;
      if (currentPosSec >= endSeconds.value || currentPosSec < startSeconds.value - 0.5) {
        vpc.seekTo(Duration(milliseconds: (startSeconds.value * 1000).toInt()));
      }
    });
  }

  void stopPreview() {
    isPreviewPlaying.value = false;
    _previewTimer?.cancel();
    _previewTimer = null;
    videoControllerRef?.videoPlayerController?.pause();
  }

  @override
  void onClose() {
    stopPreview();
    super.onClose();
  }

  bool _isRateLimited() {
    if (_lastClipActionTime != null) {
      final elapsed = DateTime.now().difference(_lastClipActionTime!).inSeconds;
      if (elapsed < actionCooldownSeconds) {
        final remaining = actionCooldownSeconds - elapsed;
        AppSnackbar.warning(
          'Please wait $remaining seconds before creating another clip.',
          title: 'Slow Down',
        );
        return true;
      }
    }
    return false;
  }

  Future<void> saveClip() async {
    // 1. Creator permission / video eligibility check
    final restriction = getClippingRestrictionReason();
    if (restriction != null) {
      AppSnackbar.warning(
        restriction,
        title: 'Clipping Unavailable',
      );
      return;
    }

    // 2. Anti-spam rate limiting check
    if (_isRateLimited()) return;

    // 3. Title content moderation check
    final titleValidation = validateClipTitle(clipTitle.value);
    if (titleValidation != null) {
      titleError.value = titleValidation;
      AppSnackbar.warning(
        titleValidation,
        title: 'Invalid Title',
      );
      return;
    }

    // 4. Duration bounds check
    final duration = endSeconds.value - startSeconds.value;
    if (duration < minDuration) {
      AppSnackbar.warning(
        'Clips must be at least ${minDuration.toInt()} seconds long',
        title: 'Clip Too Short',
      );
      return;
    }
    if (duration > maxDuration + 0.5) {
      AppSnackbar.warning(
        'Clips cannot exceed ${maxDuration.toInt()} seconds',
        title: 'Clip Too Long',
      );
      return;
    }

    // 5. Authentication check
    if (!AuthService.to.isAuthenticated.value) {
      AppSnackbar.warning(
        'Please sign in with your Google account to save clips.',
        title: 'Sign In Required',
        duration: const Duration(seconds: 4),
        actionLabel: 'SIGN IN',
        onAction: () => AuthService.to.triggerPlatformSignIn(),
      );
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    isSaving.value = true;
    try {
      // 6. Library quota anti-abuse check (limit to max 50 saved clips)
      try {
        final countSnapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection('clips')
            .count()
            .get();

        if ((countSnapshot.count ?? 0) >= maxLibraryClips) {
          AppSnackbar.warning(
            'You have reached the maximum limit of $maxLibraryClips saved clips. Please delete some old clips before saving new ones.',
            title: 'Library Full',
          );
          return;
        }
      } catch (countError, countStack) {
        ErrorHandler.log(countError, stackTrace: countStack, tag: 'ClipController.quotaCheck');
      }

      final clipId = const Uuid().v4();
      final clip = VideoClip(
        id: clipId,
        videoId: video.id,
        userId: uid,
        title: clipTitle.value.trim(),
        startTime: startSeconds.value,
        endTime: endSeconds.value,
        thumbnailUrl: video.thumbnailUrl,
        videoTitle: video.title,
        channelName: video.channelName,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('clips')
          .doc(clipId)
          .set(clip.toMap());

      _lastClipActionTime = DateTime.now();

      Get.back(); // Close dialog
      AppSnackbar.success('Clip saved to your library');
    } catch (e) {
      ErrorHandler.log(e, context: 'ClipController.saveClip');
      AppSnackbar.error('Unable to save clip. Please try again.');
    } finally {
      isSaving.value = false;
    }
  }

  void shareClipWithWatermark(BuildContext context, {VideoClip? existingClip}) {
    // 1. Creator permission / video eligibility check
    final restriction = getClippingRestrictionReason();
    if (restriction != null) {
      AppSnackbar.warning(
        restriction,
        title: 'Clipping Unavailable',
      );
      return;
    }

    // 2. Anti-spam rate limiting check
    if (_isRateLimited()) return;

    final start = existingClip?.startTime ?? startSeconds.value;
    final end = existingClip?.endTime ?? endSeconds.value;
    final title = (existingClip?.title.isNotEmpty ?? false)
        ? existingClip!.title
        : (clipTitle.value.isNotEmpty ? clipTitle.value.trim() : video.title);
    final duration = end - start;

    // 3. Title content moderation check
    final titleValidation = validateClipTitle(title);
    if (titleValidation != null) {
      titleError.value = titleValidation;
      AppSnackbar.warning(
        titleValidation,
        title: 'Invalid Title',
      );
      return;
    }

    // 4. Duration bounds check
    if (duration < minDuration) {
      AppSnackbar.warning(
        'Clips must be at least ${minDuration.toInt()} seconds long',
        title: 'Clip Too Short',
      );
      return;
    }
    if (duration > maxDuration + 0.5) {
      AppSnackbar.warning(
        'Clips can only be shared up to ${maxDuration.toInt()} seconds',
        title: 'Clip Too Long',
      );
      return;
    }

    _lastClipActionTime = DateTime.now();

    final encodedTitle = Uri.encodeComponent(title);
    final clipUrl =
        'https://www.truthworld.in/watch?v=${video.id}&start=${start.toInt()}&end=${end.toInt()}&clipTitle=$encodedTitle';

    final durationText =
        '${start.toInt()}s - ${end.toInt()}s (${duration.toInt()}s)';
    final watermarkText =
        '🎬 Watch clip: "$title" [$durationText]\n'
        '✨ Truthworld\n'
        '👇 Tap to watch in Truthworld App:\n'
        '$clipUrl';

    // Close current clip creation sheet if open
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }

    var videoSourceUrl = video.originalUrl.isNotEmpty
        ? video.originalUrl
        : (video.adaptiveResolutions.isNotEmpty
            ? video.adaptiveResolutions.first.url
            : (video.videoUrl.isNotEmpty ? video.videoUrl : video.hlsUrl));

    if (videoSourceUrl.isEmpty && Get.isRegistered<VideoController>()) {
      final vc = Get.find<VideoController>();
      videoSourceUrl = vc.currentResolution.value?.url ?? vc.video.hlsUrl;
    }

    if (videoSourceUrl.isNotEmpty) {
      final fast = StorageUtils.getFastDownloadUrl(videoSourceUrl);
      if (fast.isNotEmpty) videoSourceUrl = fast;
    }

    ShareBottomSheet.show(
      title: title,
      url: clipUrl,
      thumbnailUrl: video.thumbnailUrl,
      subtitle: watermarkText,
      channelName: video.channelName,
      durationMs: (duration * 1000).toInt(),
      type: 'clip',
      clipStartTime: start,
      clipEndTime: end,
      videoUrl: videoSourceUrl,
      videoId: video.id,
      videoTitle: video.title,
    );
  }
}
