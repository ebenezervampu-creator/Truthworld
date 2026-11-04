import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated full-page screen displaying comprehensive Truth Intelligence & Credibility Analysis.
///
/// Replaces the bottom sheet with a first-class route containing an application bar,
/// responsive desktop/mobile layout, video context overview, and multi-tab analysis.
class VideoAnalysisScreen extends StatelessWidget {
  const VideoAnalysisScreen({
    this.video,
    this.controller,
    this.initialTabIndex = 0,
    super.key,
  });

  final Video? video;
  final VideoController? controller;
  final int initialTabIndex;

  /// Seamlessly navigates to the Truth Intelligence & Credibility page.
  static Future<T?>? open<T>(
    BuildContext context, {
    required Video video,
    VideoController? controller,
    int initialTabIndex = 0,
  }) {
    // 1. Pre-initialize analysis controller and selected tab to eliminate first-frame latency
    final tag = video.id;
    if (!Get.isRegistered<VideoAnalysisController>(tag: tag)) {
      Get.put(VideoAnalysisController(), tag: tag);
    }
    Get.find<VideoAnalysisController>(tag: tag).setSelectedTab(initialTabIndex);

    // 2. Pre-fetch fact-check data ahead of route transition
    final effectiveVideoCtrl = controller ??
        (Get.isRegistered<VideoController>(tag: tag)
            ? Get.find<VideoController>(tag: tag)
            : (Get.isRegistered<VideoController>()
                ? Get.find<VideoController>()
                : null));

    if (effectiveVideoCtrl != null &&
        effectiveVideoCtrl.factCheckData.isEmpty &&
        !effectiveVideoCtrl.hasAttemptedFactCheck.value &&
        video.factCheckUrl.isNotEmpty) {
      effectiveVideoCtrl.loadFactCheckData(video.factCheckUrl);
    }

    return Get.to<T>(
          () => VideoAnalysisScreen(
            video: video,
            controller: controller,
            initialTabIndex: initialTabIndex,
          ),
          routeName: AppRoutes.videoAnalysis,
          arguments: {
            'video': video,
            'controller': controller,
            'initialTabIndex': initialTabIndex,
            'videoId': video.id,
          },
          transition: Transition.rightToLeftWithFade,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 320),
        ) ??
        Future.value();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve Video instance from parameters or route arguments
    var resolvedVideo = video;
    var resolvedController = controller;
    var resolvedTabIndex = initialTabIndex;

    final args = Get.arguments;
    if (resolvedVideo == null && args is Video) {
      resolvedVideo = args;
    } else if (args is Map) {
      if (resolvedVideo == null && args['video'] is Video) {
        resolvedVideo = args['video'] as Video;
      }
      if (resolvedController == null && args['controller'] is VideoController) {
        resolvedController = args['controller'] as VideoController;
      }
      if (args['initialTabIndex'] is int) {
        resolvedTabIndex = args['initialTabIndex'] as int;
      }
    }

    final routeVideoId = resolvedVideo?.id ??
        (args is Map ? args['videoId']?.toString() : null) ??
        Get.parameters['videoId'] ??
        Get.parameters['v'] ??
        Get.parameters['id'];

    if (resolvedVideo == null && routeVideoId != null && routeVideoId.isNotEmpty) {
      if (Get.isRegistered<VideoController>(tag: routeVideoId)) {
        final existingCtrl = Get.find<VideoController>(tag: routeVideoId);
        resolvedVideo = existingCtrl.video;
        resolvedController ??= existingCtrl;
      }
    }

    // 2. If video is still not available (e.g. direct deep link), load from Firestore
    if (resolvedVideo == null) {
      if (routeVideoId == null || routeVideoId.isEmpty) {
        return _buildErrorScaffold('Video reference not found.');
      }
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('videos').doc(routeVideoId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold();
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorScaffold('Unable to load video details.');
          }
          final loadedVideo = Video.fromDocumentSnapshot(snapshot.data!);
          return _buildAnalysisScaffold(
            context,
            video: loadedVideo,
            controller: resolvedController,
            initialTab: resolvedTabIndex,
          );
        },
      );
    }

    return _buildAnalysisScaffold(
      context,
      video: resolvedVideo,
      controller: resolvedController,
      initialTab: resolvedTabIndex,
    );
  }

  Widget _buildAnalysisScaffold(
    BuildContext context, {
    required Video video,
    required int initialTab,
    VideoController? controller,
  }) {
    // 3. Resolve or initialize VideoController
    final VideoController effectiveVideoCtrl;
    if (controller != null) {
      effectiveVideoCtrl = controller;
    } else {
      final tag = video.id;
      if (Get.isRegistered<VideoController>(tag: tag)) {
        effectiveVideoCtrl = Get.find<VideoController>(tag: tag);
      } else if (Get.isRegistered<VideoController>()) {
        effectiveVideoCtrl = Get.find<VideoController>();
      } else {
        effectiveVideoCtrl = Get.put(VideoController(), tag: tag);
      }
    }

    // 4. Resolve or initialize VideoAnalysisController
    final tag = video.id;
    final VideoAnalysisController effectiveAnalysisCtrl;
    if (Get.isRegistered<VideoAnalysisController>(tag: tag)) {
      effectiveAnalysisCtrl = Get.find<VideoAnalysisController>(tag: tag);
    } else {
      effectiveAnalysisCtrl = Get.put(VideoAnalysisController(), tag: tag);
    }
    effectiveAnalysisCtrl.setSelectedTab(initialTab);

    // 5. Trigger fact-check data retrieval if needed
    if (effectiveVideoCtrl.factCheckData.isEmpty &&
        !effectiveVideoCtrl.hasAttemptedFactCheck.value &&
        video.factCheckUrl.isNotEmpty) {
      effectiveVideoCtrl.loadFactCheckData(video.factCheckUrl);
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 19,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.back();
            }
          },
        ),
        title: Text(
          'Ai Check',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Ask AI',
            onPressed: () {
              AskAiScreen.open(
                context,
                video: video,
                controller: effectiveVideoCtrl,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.bgDivider),
        ),
      ),
      body: SafeArea(
        child: ResponsiveBuilder(
          builder: (context, device) {
            final isDesktop = device.isDesktop ||
                device.isLargeDesktop ||
                device.isUltraWide ||
                MediaQuery.sizeOf(context).width >= TWBreakpoints.desktop;

            if (isDesktop) {
              return VideoAnalysisDesktopLayout(
                video: video,
                videoCtrl: effectiveVideoCtrl,
                analysisCtrl: effectiveAnalysisCtrl,
              );
            }

            return _buildMobileLayout(
              context,
              video: video,
              videoCtrl: effectiveVideoCtrl,
              analysisCtrl: effectiveAnalysisCtrl,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context, {
    required Video video,
    required VideoController videoCtrl,
    required VideoAnalysisController analysisCtrl,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: VideoAnalysisView(
          video: video,
          videoCtrl: videoCtrl,
          analysisCtrl: analysisCtrl,
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19),
          onPressed: Get.back,
        ),
        title: const Text('Ai Check', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Retrieving analysis...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19),
          onPressed: Get.back,
        ),
        title: const Text('Ai Check', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: Get.back,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
