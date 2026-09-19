import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/services/video_hydration_service.dart';

/// Dedicated controller managing video hydration, Firestore query fallback,
/// clip argument resolution, animation lifecycle, and navigation for VideoLoaderScreen.
class VideoLoaderController extends BaseController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> animation;

  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!Get.testMode) {
      animationController.repeat(reverse: true);
    }
    animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadVideo();
    });
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }

  Future<void> loadVideo() async {
    final videoId = Get.parameters['v'] ?? Get.parameters['videoId'];

    if (videoId == null) {
      _showErrorSnackbar('Video Unavailable', 'No video ID was found in the URL.');
      return;
    }

    try {
      Video? video;

      // Check for injected data first (instant load - no Firestore)
      if (VideoHydrationService.hasInjectedData()) {
        debugPrint('✅ Using prerendered video data (instant hydration)');

        final injectedData = VideoHydrationService.getInjectedData();
        if (injectedData != null) {
          video = Video(
            id: injectedData['id'] as String? ?? videoId,
            title: injectedData['title'] as String? ?? 'Video',
            description: injectedData['description'] as String? ?? '',
            thumbnailUrl: injectedData['thumbnail'] as String? ?? '',
            videoUrl: injectedData['videoUrl'] as String?,
            hlsUrl: injectedData['hlsUrl'] as String? ?? '',
            dashUrl: injectedData['dashUrl'] as String? ?? '',
            ownerId: injectedData['creatorId'] as String? ?? 'unknown',
            channelId: injectedData['channelId'] as String? ??
                (injectedData['creatorId'] as String? ?? 'unknown'),
            channelName: injectedData['creatorName'] as String? ?? 'Creator',
            category: injectedData['category'] as String? ?? 'General',
            tags: List<String>.from(injectedData['tags'] as List? ?? []),
            viewCount: injectedData['viewCount'] as int? ?? 0,
            vDurationValue: Duration(
              seconds: injectedData['duration'] as int? ?? 0,
            ),
            createdAt: Timestamp.now(),
          );

          VideoHydrationService.clearInjectedData();
        }
      }

      // Fallback: Load from Firestore
      if (video == null) {
        debugPrint('⏳ Loading video from Firestore: $videoId');

        final DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(videoId)
            .get();

        if (!doc.exists) {
          _showErrorSnackbar('Video Unavailable', 'This video is currently unavailable.');
          return;
        }

        video = Video.fromDocumentSnapshot(doc);
      }

      // Navigate with loaded video
      final args = <String, dynamic>{'video': video};
      final rawArgs = Get.arguments;
      if (rawArgs is Map && rawArgs['clip'] != null) {
        args['clip'] = rawArgs['clip'];
      } else {
        final startStr = Get.parameters['start'] ??
            Get.parameters['clipStart'] ??
            (kIsWeb
                ? (Uri.base.queryParameters['start'] ??
                    Uri.base.queryParameters['clipStart'])
                : null);
        final endStr = Get.parameters['end'] ??
            Get.parameters['clipEnd'] ??
            (kIsWeb
                ? (Uri.base.queryParameters['end'] ??
                    Uri.base.queryParameters['clipEnd'])
                : null);
        final clipTitleParam = Get.parameters['clipTitle'] ??
            Get.parameters['title'] ??
            (kIsWeb
                ? (Uri.base.queryParameters['clipTitle'] ??
                    Uri.base.queryParameters['title'])
                : null);
        if (startStr != null && endStr != null) {
          final start = double.tryParse(startStr);
          final end = double.tryParse(endStr);
          if (start != null && end != null && end > start) {
            args['clip'] = VideoClip(
              id: Get.parameters['clipId'] ??
                  (kIsWeb ? Uri.base.queryParameters['clipId'] : null) ??
                  'temp_${DateTime.now().millisecondsSinceEpoch}',
              videoId: video.id,
              userId: '',
              title: clipTitleParam != null
                  ? Uri.decodeComponent(clipTitleParam)
                  : '${video.title} Clip',
              startTime: start,
              endTime: end,
              thumbnailUrl: video.thumbnailUrl,
              videoTitle: video.title,
              channelName: video.channelName,
              createdAt: DateTime.now(),
            );
          }
        }
      }
      Get.offNamed<void>('/watch?v=${video.id}', arguments: args);
      debugPrint('🧭 Video loaded and navigating to video screen');
    } catch (e) {
      ErrorHandler.log(e, context: 'VideoLoaderController.loadVideo');
      _showErrorSnackbar('Unable to load video', 'Unable to load video. Please try again.');
    }
  }

  void _showErrorSnackbar(String title, String message) {
    if (Get.testMode) {
      debugPrint('[$title] $message');
      return;
    }
    AppSnackbar.error(message);
  }
}
