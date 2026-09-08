import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/services/video_hydration_service.dart';

// Constants for consistent styling
const double kBorderRadius = 16;
const double kSmallPadding = 8;
const double kMediumPadding = 16;
const double kLargePadding = 24;

class VideoLoaderScreen extends StatefulWidget {
  const VideoLoaderScreen({super.key});

  @override
  State<VideoLoaderScreen> createState() => _VideoLoaderScreenState();
}

class _VideoLoaderScreenState extends State<VideoLoaderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideo();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    final videoId = Get.parameters['v'] ?? Get.parameters['videoId'];

    if (videoId == null) {
      _showErrorSnackbar('Error', 'No video ID found in URL');
      return;
    }

    try {
      Video? video;

      // PHASE 2: Check for injected data first (instant load - no Firestore)
      if (VideoHydrationService.hasInjectedData()) {
        debugPrint('✅ Using prerendered video data (instant hydration)');

        final injectedData = VideoHydrationService.getInjectedData();
        if (injectedData != null) {
          // Create Video from injected data
          video = Video(
            id: injectedData['id'] as String? ?? videoId,
            title: injectedData['title'] as String? ?? 'Video',
            description: injectedData['description'] as String? ?? '',
            thumbnailUrl: injectedData['thumbnail'] as String? ?? '',
            videoUrl: injectedData['videoUrl'] as String?,
            hlsUrl: injectedData['hlsUrl'] as String? ?? '',
            dashUrl: injectedData['dashUrl'] as String? ?? '',
            ownerId: injectedData['creatorId'] as String? ?? 'unknown',
            channelId:
                injectedData['channelId'] as String? ??
                (injectedData['creatorId'] as String? ?? 'unknown'),
            channelName: injectedData['creatorName'] as String? ?? 'Creator',
            category: injectedData['category'] as String? ?? 'General',
            tags: List<String>.from(injectedData['tags'] as List? ?? []),
            viewCount: injectedData['viewCount'] as int? ?? 0,
            vDurationValue: Duration(
              seconds: injectedData['duration'] as int? ?? 0,
            ),
            createdAt: Timestamp.now(), // Fallback
          );

          // Clean up injected data after consuming
          VideoHydrationService.clearInjectedData();
        }
      }

      // Fallback: Load from Firestore (for app navigation, not web/SEO)
      if (video == null) {
        debugPrint('⏳ Loading video from Firestore: $videoId');

        final DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(videoId)
            .get();

        if (!doc.exists) {
          _showErrorSnackbar('Error', 'Video not found');
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
      _showErrorSnackbar('Error', 'Something went wrong: $e');
      debugPrint('❌ Error loading video: $e');
    }
  }

  void _showErrorSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.errorContainer,
      colorText: Get.theme.colorScheme.onErrorContainer,
      margin: const EdgeInsets.all(kMediumPadding),
      borderRadius: kBorderRadius,
      icon: Icon(
        Icons.error_rounded,
        color: Get.theme.colorScheme.onErrorContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: const AppLogo(
                size: 80,
                borderRadius: 20,
              ),
            ),
            const SizedBox(height: kLargePadding),
            Text(
              'Loading Video...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kSmallPadding),
            Text(
              'Please wait a moment while we fetch your content.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
