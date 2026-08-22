import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class ClipController extends BaseController {
  ClipController({required this.video});
  final Video video;

  final RxDouble startSeconds = 0.0.obs;
  final RxDouble endSeconds = 15.0.obs; // Default 15s clip
  final RxString clipTitle = ''.obs;
  final RxBool isSaving = false.obs;

  double get maxDuration => 30; // Max shareable clip duration: 30s

  void updateStart(double value) {
    if (value < endSeconds.value - 1) {
      startSeconds.value = value;
    }
  }

  void updateEnd(double value) {
    if (value > startSeconds.value + 1) {
      if (value - startSeconds.value <= maxDuration) {
        endSeconds.value = value;
      }
    }
  }

  Future<void> saveClip() async {
    if (clipTitle.value.isEmpty) {
      Get.snackbar('Error', 'Please enter a title for your clip');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'You must be signed in to save clips');
      return;
    }

    isSaving.value = true;
    try {
      final clipId = const Uuid().v4();
      final clip = VideoClip(
        id: clipId,
        videoId: video.id,
        userId: user.uid,
        title: clipTitle.value,
        startTime: startSeconds.value,
        endTime: endSeconds.value,
        thumbnailUrl: video.thumbnailUrl,
        videoTitle: video.title,
        channelName: video.channelName,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .collection('clips')
          .doc(clipId)
          .set(clip.toMap());

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
    final start = existingClip?.startTime ?? startSeconds.value;
    final end = existingClip?.endTime ?? endSeconds.value;
    final title = (existingClip?.title.isNotEmpty ?? false)
        ? existingClip!.title
        : (clipTitle.value.isNotEmpty ? clipTitle.value : video.title);
    final duration = end - start;

    if (duration > maxDuration + 1) {
      Get.snackbar(
        'Clip too long',
        'Clips can only be shared up to 30 seconds',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

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

    final videoSourceUrl = video.originalUrl.isNotEmpty
        ? video.originalUrl
        : (video.adaptiveResolutions.isNotEmpty
            ? video.adaptiveResolutions.first.url
            : video.videoUrl);

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
