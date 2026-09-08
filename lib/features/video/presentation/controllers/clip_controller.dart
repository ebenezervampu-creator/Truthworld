import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class ClipController extends BaseController {
  ClipController({required this.video});
  final Video video;

  final RxDouble startSeconds = 0.0.obs;
  final RxDouble endSeconds = 15.0.obs; // Default 15s clip
  final RxString clipTitle = ''.obs;
  final RxString titleError = ''.obs;
  final RxBool isSaving = false.obs;

  // Industry standard duration bounds (YouTube / Twitch / TikTok standard)
  double get minDuration => 5.0; // Minimum 5 seconds to prevent micro-spam & glitches
  double get maxDuration => 30.0; // Maximum 30 seconds to prevent piracy

  static const int maxLibraryClips = 50; // Quota per user to prevent database abuse
  static const int actionCooldownSeconds = 10; // 10s cooldown to throttle automated spam
  static DateTime? _lastClipActionTime;

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

  bool _isRateLimited() {
    if (_lastClipActionTime != null) {
      final elapsed = DateTime.now().difference(_lastClipActionTime!).inSeconds;
      if (elapsed < actionCooldownSeconds) {
        final remaining = actionCooldownSeconds - elapsed;
        Get.snackbar(
          'Slow Down',
          'Please wait $remaining seconds before creating another clip.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
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
      Get.snackbar(
        'Clipping Unavailable',
        restriction,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    // 2. Anti-spam rate limiting check
    if (_isRateLimited()) return;

    // 3. Title content moderation check
    final titleValidation = validateClipTitle(clipTitle.value);
    if (titleValidation != null) {
      titleError.value = titleValidation;
      Get.snackbar(
        'Invalid Title',
        titleValidation,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    // 4. Duration bounds check
    final duration = endSeconds.value - startSeconds.value;
    if (duration < minDuration) {
      Get.snackbar(
        'Clip Too Short',
        'Clips must be at least ${minDuration.toInt()} seconds long',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (duration > maxDuration + 0.5) {
      Get.snackbar(
        'Clip Too Long',
        'Clips cannot exceed ${maxDuration.toInt()} seconds',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // 5. Authentication check
    if (!AuthService.to.isAuthenticated.value) {
      Get.snackbar(
        'Sign in required',
        'Please sign in with your Google account to save clips.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () {
            AuthService.to.signInWithGoogle();
          },
          child: const Text(
            'SIGN IN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
          Get.snackbar(
            'Library Full',
            'You have reached the maximum limit of $maxLibraryClips saved clips. Please delete some old clips before saving new ones.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error.withValues(alpha: 0.9),
            colorText: Colors.white,
          );
          return;
        }
      } catch (countError) {
        debugPrint('[ClipController] Quota check note: $countError');
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
      Get.snackbar(
        'Success',
        'Clip saved to your library',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withValues(alpha: 0.8),
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to save clip: $e');
    } finally {
      isSaving.value = false;
    }
  }

  void shareClipWithWatermark(BuildContext context, {VideoClip? existingClip}) {
    // 1. Creator permission / video eligibility check
    final restriction = getClippingRestrictionReason();
    if (restriction != null) {
      Get.snackbar(
        'Clipping Unavailable',
        restriction,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
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
      Get.snackbar(
        'Invalid Title',
        titleValidation,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    // 4. Duration bounds check
    if (duration < minDuration) {
      Get.snackbar(
        'Clip Too Short',
        'Clips must be at least ${minDuration.toInt()} seconds long',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (duration > maxDuration + 0.5) {
      Get.snackbar(
        'Clip Too Long',
        'Clips can only be shared up to ${maxDuration.toInt()} seconds',
        snackPosition: SnackPosition.BOTTOM,
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
        '✨ Truthworld Watermark\n'
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
