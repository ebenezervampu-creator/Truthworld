import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
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
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 250),
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
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: TruthLottieAnimation.verifiedShield(size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Truth Intelligence & Credibility',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Independent Empirical Verification',
                    style: GoogleFonts.roboto(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Refresh Analysis',
            onPressed: () {
              if (video.factCheckUrl.isNotEmpty) {
                effectiveVideoCtrl.loadFactCheckData(video.factCheckUrl);
              }
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
        child: Column(
          children: [
            _buildVideoContextCard(context, video),
            Expanded(
              child: VideoAnalysisView(
                video: video,
                videoCtrl: videoCtrl,
                analysisCtrl: analysisCtrl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContextCard(BuildContext context, Video video) {
    // 1. Format duration
    final durationStr = video.durationValue.inSeconds > 0
        ? FormatUtils.formatDuration(video.durationValue)
        : (video.duration.isNotEmpty ? video.duration : '00:00');

    // 2. Resolve title and subtitle
    var mainTitle = video.title.trim();
    var subtitle = '';

    if (mainTitle.contains(' - ')) {
      final parts = mainTitle.split(' - ');
      mainTitle = parts.first.trim();
      subtitle = parts.sublist(1).join(' - ').trim();
    } else if (mainTitle.contains(' | ')) {
      final parts = mainTitle.split(' | ');
      mainTitle = parts.first.trim();
      subtitle = parts.sublist(1).join(' | ').trim();
    } else if (mainTitle.contains('? ') && mainTitle.indexOf('? ') < mainTitle.length - 2) {
      final idx = mainTitle.indexOf('? ');
      subtitle = mainTitle.substring(idx + 2).trim();
      mainTitle = mainTitle.substring(0, idx + 1).trim();
    }

    if (subtitle.isEmpty) {
      if (video.channelName.isNotEmpty) {
        subtitle = video.channelName;
      } else if (video.description.isNotEmpty) {
        subtitle = video.description.split('\n').first.trim();
      } else {
        subtitle = 'The Science & Truth Explained';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          // 1. Video Thumbnail with Duration Pill
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 120,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => ColoredBox(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Center(
                          child: Icon(Icons.image, size: 18, color: AppColors.textTertiary),
                        ),
                      ),
                      errorWidget: (c, u, e) => ColoredBox(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Icon(Icons.broken_image, size: 18, color: AppColors.textTertiary),
                      ),
                    )
                  else
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Icon(Icons.videocam, size: 18, color: AppColors.textTertiary),
                    ),

                  // Duration Pill Overlay on Bottom Right
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durationStr,
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // 2. Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mainTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        title: const Text('Truth Intelligence & Credibility', style: TextStyle(color: Colors.white, fontSize: 16)),
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
        title: const Text('Truth Intelligence & Credibility', style: TextStyle(color: Colors.white, fontSize: 16)),
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
