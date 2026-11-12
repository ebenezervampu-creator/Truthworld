import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

// Re-exports for 100% backward compatibility
export 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
export 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';

/// Modal bottom sheet representation of Truth Intelligence & Credibility Analysis.
///
/// Kept for 100% backward compatibility, delegating its contents to [VideoAnalysisView]
/// and offering [open] to navigate to the full [VideoAnalysisScreen] route.
class VideoAnalysisBottomSheet extends StatelessWidget {
  VideoAnalysisBottomSheet({
    required this.video,
    this.initialTabIndex = 0,
    VideoController? controller,
    super.key,
  }) {
    if (controller != null) {
      videoCtrl = controller;
    } else {
      final tag = video.id;
      if (Get.isRegistered<VideoController>(tag: tag)) {
        videoCtrl = Get.find<VideoController>(tag: tag);
      } else if (Get.isRegistered<VideoController>()) {
        videoCtrl = Get.find<VideoController>();
      } else {
        videoCtrl = Get.put(VideoController());
      }
    }

    final tag = video.id;
    if (Get.isRegistered<VideoAnalysisController>(tag: tag)) {
      analysisCtrl = Get.find<VideoAnalysisController>(tag: tag);
    } else {
      analysisCtrl = Get.put(VideoAnalysisController(), tag: tag);
    }
    analysisCtrl.setSelectedTab(initialTabIndex);

    if (videoCtrl.factCheckData.isEmpty &&
        !videoCtrl.hasAttemptedFactCheck.value) {
      videoCtrl.loadFactCheckData(video.factCheckUrl);
    }
  }

  final Video video;
  final int initialTabIndex;
  late final VideoController videoCtrl;
  late final VideoAnalysisController analysisCtrl;
  BuildContext get context => Get.context!;

  /// Opens the Truth Intelligence & Credibility as a dedicated full-page screen.
  static Future<T?>? open<T>(
    BuildContext context, {
    required Video video,
    VideoController? controller,
    int initialTabIndex = 0,
  }) {
    return VideoAnalysisScreen.open<T>(
      context,
      video: video,
      controller: controller,
      initialTabIndex: initialTabIndex,
    );
  }

  /// Opens the Ask AI conversation as a dedicated full-page screen.
  static Future<T?>? openAskAi<T>(
    BuildContext context, {
    required Video video,
    VideoController? controller,
    String scope = 'video',
    int? claimIndex,
    String? claimText,
    String? verdict,
    List<dynamic>? allSources,
    List<dynamic>? allClaims,
    String? summary,
    String? claimExplanation,
  }) {
    return AskAiScreen.open<T>(
      context,
      video: video,
      controller: controller,
      scope: scope,
      claimIndex: claimIndex,
      claimText: claimText,
      verdict: verdict,
      allSources: allSources,
      allClaims: allClaims,
      summary: summary,
      claimExplanation: claimExplanation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        width: isDesktop ? 760 : double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.bgDivider),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.5),
              blurRadius: 32,
              spreadRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(context),
              const Divider(height: 1, color: AppColors.bgDivider),
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
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TruthLottieAnimation.verifiedShield(size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'TRUTH INTELLIGENCE & CREDIBILITY',
                      style: context.twTypography.overline.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brand,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.twTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.open_in_full_rounded,
              color: Colors.white70,
              size: 18,
            ),
            tooltip: 'Open as separate page',
            onPressed: () {
              Get.back();
              open(
                context,
                video: video,
                controller: videoCtrl,
                initialTabIndex: analysisCtrl.selectedTab.value,
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
            onPressed: Get.back,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
