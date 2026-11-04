import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_card/video_card_avatar.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_description_box.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Target section to focus on when opening [VideoDescriptionScreen].
enum VideoDescriptionSection {
  description,
  summary,
  transcript,
}

/// Dedicated full-page screen displaying complete video description, channel metadata,
/// interactive AI video summary, and timestamped synchronized transcripts for mobile devices.
class VideoDescriptionScreen extends StatelessWidget {
  const VideoDescriptionScreen({
    this.video,
    this.controller,
    this.mainController,
    this.initialSection = VideoDescriptionSection.description,
    super.key,
  });

  final Video? video;
  final VideoController? controller;
  final MainController? mainController;
  final VideoDescriptionSection initialSection;

  /// Navigates to the Video Description full-page screen with smooth transition.
  static Future<T?>? open<T>(
    BuildContext context, {
    required Video video,
    VideoController? controller,
    MainController? mainController,
    VideoDescriptionSection initialSection = VideoDescriptionSection.description,
  }) {
    final effectiveVideoCtrl = controller ??
        (Get.isRegistered<VideoController>(tag: video.id)
            ? Get.find<VideoController>(tag: video.id)
            : (Get.isRegistered<VideoController>()
                ? Get.find<VideoController>()
                : null));

    final effectiveMainCtrl = mainController ??
        (Get.isRegistered<MainController>()
            ? Get.find<MainController>()
            : null);

    return Get.to<T>(
      () => VideoDescriptionScreen(
        video: video,
        controller: effectiveVideoCtrl,
        mainController: effectiveMainCtrl,
        initialSection: initialSection,
      ),
      routeName: '${AppRoutes.videoDescription}?v=${video.id}',
      arguments: {
        'video': video,
        'controller': effectiveVideoCtrl,
        'mainController': effectiveMainCtrl,
        'initialSection': initialSection,
        'videoId': video.id,
      },
      transition: Transition.rightToLeftWithFade,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve Video instance from arguments or parameters
    var resolvedVideo = video;
    var resolvedController = controller;
    var resolvedMainController = mainController;
    var resolvedSection = initialSection;

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
      if (resolvedMainController == null && args['mainController'] is MainController) {
        resolvedMainController = args['mainController'] as MainController;
      }
      if (args['initialSection'] is VideoDescriptionSection) {
        resolvedSection = args['initialSection'] as VideoDescriptionSection;
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
      } else if (Get.isRegistered<VideoController>()) {
        final activeCtrl = Get.find<VideoController>();
        if (activeCtrl.video.id == routeVideoId) {
          resolvedVideo = activeCtrl.video;
          resolvedController ??= activeCtrl;
        }
      }
    }

    // 2. Fallback to Firestore when opened directly via URL
    if (resolvedVideo == null) {
      if (routeVideoId == null || routeVideoId.isEmpty) {
        return _buildErrorScaffold(context, 'Video details not found.');
      }
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('videos').doc(routeVideoId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold(context);
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorScaffold(context, 'Unable to load video details.');
          }
          final loadedVideo = Video.fromDocumentSnapshot(snapshot.data!);
          return _buildDescriptionScaffold(
            context,
            video: loadedVideo,
            controller: resolvedController,
            mainController: resolvedMainController,
            initialSection: resolvedSection,
          );
        },
      );
    }

    return _buildDescriptionScaffold(
      context,
      video: resolvedVideo,
      controller: resolvedController,
      mainController: resolvedMainController,
      initialSection: resolvedSection,
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
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
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message) {
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
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _handleBack(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                label: const Text('Go Back', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionScaffold(
    BuildContext context, {
    required Video video,
    required VideoDescriptionSection initialSection,
    VideoController? controller,
    MainController? mainController,
  }) {
    // Resolve or instantiate controller instances
    final VideoController effectiveVideoCtrl = controller ??
        (Get.isRegistered<VideoController>(tag: video.id)
            ? Get.find<VideoController>(tag: video.id)
            : (Get.isRegistered<VideoController>()
                ? Get.find<VideoController>()
                : Get.put(VideoController(), tag: video.id)));

    final MainController effectiveMainCtrl = mainController ??
        (Get.isRegistered<MainController>()
            ? Get.find<MainController>()
            : Get.put(MainController(), permanent: true));

    // Handle initial section focus (e.g. AI summary or transcript auto-expand)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initialSection == VideoDescriptionSection.summary) {
        if (!effectiveVideoCtrl.isSummaryVisible.value) {
          effectiveVideoCtrl.isSummaryVisible.value = true;
          effectiveVideoCtrl.fetchSummary();
        }
      } else if (initialSection == VideoDescriptionSection.transcript) {
        if (!effectiveVideoCtrl.isTranscriptVisible.value) {
          effectiveVideoCtrl.isTranscriptVisible.value = true;
          final playerCtrl = TowerPlayerController.getForTagOrActive(video.id);
          playerCtrl?.startSubtitleSyncTimer();
          final currentPos = playerCtrl?.videoPlayerController.value.position ??
              effectiveVideoCtrl.currentPosition;
          effectiveVideoCtrl.transcriptController.resumeAutoScroll();
          effectiveVideoCtrl.transcriptController.syncToCurrentPosition(
            currentPos,
            forceScroll: true,
          );
          effectiveVideoCtrl.loadTranscriptForVideo();
        }
      }
    });

    final channelId = video.channelId.isNotEmpty
        ? video.channelId
        : video.ownerId;
    final channel = ChannelMemoryCache.getReactive(channelId) ??
        ChannelMemoryCache.get(channelId);

    final effectiveShowLike = video.showLikeCount &&
        (channel == null || channel.showLikeCount);

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
          onPressed: () => _handleBack(context),
        ),
        titleSpacing: 0,
        title: Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Close',
            onPressed: () => _handleBack(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Video Title
            ClickableUrlText(
              text: video.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            // 2. Channel Overview Card
            _buildChannelCard(context, channel, video),
            const SizedBox(height: 14),

            // 3. Key Metrics Bar (Likes, Views, Uploaded Date)
            _buildMetricsBar(
              context,
              video: video,
              channel: channel,
              mainController: effectiveMainCtrl,
              effectiveShowLike: effectiveShowLike,
            ),
            const SizedBox(height: 16),

            // 4. Quick Action Badges (AI Summary & Transcript Toggles)
            _buildActionToggles(context, effectiveVideoCtrl),
            const SizedBox(height: 16),

            // 5. Reactive AI Summary Section
            Obx(() {
              if (!effectiveVideoCtrl.isSummaryVisible.value) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: VideoDescriptionBox.buildSummaryContent(
                  context,
                  controller: effectiveVideoCtrl,
                ),
              );
            }),

            // 6. Reactive Transcript Section
            Obx(() {
              if (!effectiveVideoCtrl.isTranscriptVisible.value) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: VideoDescriptionBox.buildTranscriptContent(
                    context,
                    controller: effectiveVideoCtrl,
                  ),
                ),
              );
            }),

            // 7. Full Description Text Container
            _buildDescriptionTextContainer(context, video),
            const SizedBox(height: 14),

            // 8. Channel Links & Source References
            VideoDescriptionBox.buildChannelLinksSection(channel, video),

            // Bottom safe padding
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context, Channel? channel, Video video) {
    final effectiveChannelId = video.channelId.isNotEmpty
        ? video.channelId
        : video.ownerId;
    final channelName = channel?.channelName.trim().isNotEmpty == true
        ? channel!.channelName
        : (video.channelName.trim().isNotEmpty
            ? video.channelName
            : 'Creator');
    final avatarUrl = channel?.avatarUrl.trim().isNotEmpty == true
        ? channel!.avatarUrl
        : video.channelAvatarUrl;

    return InkWell(
      onTap: () {
        if (effectiveChannelId.isNotEmpty) {
          Get.toNamed('/channel/$effectiveChannelId');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            VideoCardAvatar(
              radius: 20,
              imageUrl: avatarUrl,
              placeholderText: channelName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channelName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (channel?.isVerified == true) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.brand,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatChannelSubscribers(channel),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsBar(
    BuildContext context, {
    required Video video,
    required Channel? channel,
    required MainController mainController,
    required bool effectiveShowLike,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Likes Count
          if (effectiveShowLike) ...[
            Expanded(
              child: Obx(() {
                final likes = mainController.videoLikes[video.id] ?? video.likeCount;
                return _buildMetricItem(
                  value: FormatUtils.formatCount(likes),
                  label: likes == 1 ? 'Like' : 'Likes',
                );
              }),
            ),
            _buildMetricDivider(),
          ],

          // Views Count
          Expanded(
            child: Obx(() {
              final views = mainController.videoViews[video.id] ?? video.views;
              return _buildMetricItem(
                value: FormatUtils.formatCount(views),
                label: views == 1 ? 'View' : 'Views',
              );
            }),
          ),
          _buildMetricDivider(),

          // Uploaded Date
          Expanded(
            child: _buildMetricItem(
              value: DateFormat('MMM d, yyyy').format(video.uploadedAt.toDate()),
              label: timeago.format(video.uploadedAt.toDate()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }

  Widget _buildActionToggles(
    BuildContext context,
    VideoController videoCtrl,
  ) {
    return Row(
      children: [
        // AI Summary Toggle
        Expanded(
          child: Obx(() {
            final isSummaryActive = videoCtrl.isSummaryVisible.value;
            return InkWell(
              onTap: () {
                final next = !isSummaryActive;
                videoCtrl.isSummaryVisible.value = next;
                if (next) {
                  videoCtrl.fetchSummary();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                decoration: BoxDecoration(
                  color: isSummaryActive
                      ? AppColors.brand.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSummaryActive
                        ? AppColors.brand.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isSummaryActive ? 'Hide AI Summary' : 'AI Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 10),

        // Transcript Toggle
        Expanded(
          child: Obx(() {
            final isTranscriptActive = videoCtrl.isTranscriptVisible.value;
            return InkWell(
              onTap: () {
                final next = !isTranscriptActive;
                videoCtrl.isTranscriptVisible.value = next;
                if (next) {
                  final playerCtrl = TowerPlayerController.getForTagOrActive(videoCtrl.video.id);
                  playerCtrl?.startSubtitleSyncTimer();
                  final currentPos = playerCtrl?.videoPlayerController.value.position ??
                      videoCtrl.currentPosition;
                  videoCtrl.transcriptController.resumeAutoScroll();
                  videoCtrl.transcriptController.syncToCurrentPosition(
                    currentPos,
                    forceScroll: true,
                  );
                  videoCtrl.loadTranscriptForVideo();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                decoration: BoxDecoration(
                  color: isTranscriptActive
                      ? AppColors.brand.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isTranscriptActive
                        ? AppColors.brand.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isTranscriptActive ? 'Hide Transcript' : 'Transcript',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDescriptionTextContainer(BuildContext context, Video video) {
    final hasDescription = video.description.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESCRIPTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          if (hasDescription)
            ClickableUrlText(
              text: video.description,
              maxLines: null,
              overflow: TextOverflow.visible,
              selectable: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.55,
              ),
            )
          else
            Text(
              'No description provided for this video.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  String _formatChannelSubscribers(Channel? channel) {
    if (channel == null || !channel.showSubscriberCount) {
      return 'Creator';
    }
    final count = channel.subscriberCount;
    return '${FormatUtils.formatCount(count)} ${count == 1 ? 'subscriber' : 'subscribers'}';
  }

  void _handleBack(BuildContext context) {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.back();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoDescriptionScreen.handleBack',
      );
      Get.back();
    }
  }
}
