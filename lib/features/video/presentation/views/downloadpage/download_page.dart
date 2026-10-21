import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// RESPONSIVE UTILITIES
// ==========================================================================

class ResponsiveUtils {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(16);
    if (isTablet(context)) return const EdgeInsets.all(24);
    return const EdgeInsets.all(32);
  }
}

// ==========================================================================
// MAIN WIDGET
// ==========================================================================

class DownloadsPage extends GetView<DownloadsController> {
  const DownloadsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  DownloadsController get controller =>
      Get.isRegistered<DownloadsController>()
          ? Get.find<DownloadsController>()
          : Get.put(DownloadsController());

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.videos.isEmpty && !controller.rxIsLoading.value) {
        controller.loadVideos();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: RefreshIndicator(
        onRefresh: controller.loadVideos,
        color: AppColors.brand,
        backgroundColor: AppColors.bgSurface,
        child: _buildMainContent(context),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, isDashboard ? 16 : 48, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Obx(
                    () => controller.isSearchExpanded.value
                        ? Container(
                            height: 40,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.bgDivider.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: TextField(
                              maxLength: ContentValidator.defaultMaxSearchLength,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              inputFormatters: TruthworldTextInputFormatters.withLimit(
                                ContentValidator.defaultMaxSearchLength,
                              ),
                              onChanged: (value) =>
                                  controller.searchQuery.value = value,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search downloads...',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    controller.isSearchExpanded.value = false;
                                    controller.searchQuery.value = '';
                                  },
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.textPrimary,
                                ),
                                onPressed: () {
                                  if (isDashboard) {
                                    Get.find<HomeController>()
                                            .sideNavSelectedIndex
                                            .value =
                                        HomeController.indexLibrary;
                                  } else {
                                    Get.back();
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Downloads',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                Obx(
                  () => !controller.isSearchExpanded.value
                      ? IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () =>
                              controller.isSearchExpanded.value = true,
                        )
                      : const SizedBox.shrink(),
                ),
                IconButton(
                  icon: Obx(
                    () => Icon(
                      controller.isListView.value
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onPressed: controller.toggleView,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        Obx(() {
          if (controller.rxIsLoading.value) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.brand,
                ),
              ),
            );
          }

          final errorMsg = controller.errorMessage.isNotEmpty
              ? controller.errorMessage
              : controller.rxErrorMessage.value;

          if (errorMsg.isNotEmpty &&
              controller.videos.isEmpty &&
              controller.activeDownloads.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMsg,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: controller.loadVideos,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
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

          final activeTasks = controller.activeDownloads.values.toList();
          final videos = controller.filteredVideos;
          final groupedVideos = controller.groupVideosByDate(videos);

          return SliverList(
            delegate: SliverChildListDelegate([
              // 1. In-flight active downloads
              if (activeTasks.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Downloading (${activeTasks.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final task in activeTasks)
                  _ActiveDownloadCard(
                    task: task,
                    controller: controller,
                  ),
                const SizedBox(height: 12),
              ],

              // 2. Empty state (only if both completed and active downloads are empty)
              if (videos.isEmpty && activeTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppColors.bgSurfaceHover,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.file_download_outlined,
                            size: 40,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Downloads Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Downloaded videos will appear here for offline playback.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final entry in groupedVideos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  for (final video in entry.value)
                    _DownloadVideoListCard(
                      video: video,
                      controller: controller,
                    ),
                ],

              const SizedBox(height: 28),
              _buildRecommendedDownloadsSection(context),
              const SizedBox(height: 40),
            ]),
          );
        }),
      ],
    );
  }

  Widget _buildRecommendedDownloadsSection(BuildContext context) {
    final mainController = Get.find<MainController>();

    return Obx(() {
      final rawCandidates = mainController.filteredVideos.isNotEmpty
          ? mainController.filteredVideos
          : mainController.videos;

      // Filter exclusively to approved, public, recommended videos (excluding moderation rejected)
      final cleanVideos = VideoSanitizer.sanitizeForRecommendation(rawCandidates);

      final downloadedIds = controller.videos.map((v) => v.id).toSet();
      final downloadingIds = controller.activeDownloads.keys.toSet();
      final excludedIds = {...downloadedIds, ...downloadingIds};

      final displayList = cleanVideos
          .where((v) => !excludedIds.contains(v.id))
          .take(10)
          .toList();

      if (displayList.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Recommended Downloads',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Popular videos you can save for offline watching',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final video = displayList[index];
              return _RecommendedDownloadCard(
                key: ValueKey(video.id),
                video: video,
                isDownloaded: downloadedIds.contains(video.id),
                isDownloading: downloadingIds.contains(video.id),
                onDownload: () => _downloadRecommendedVideo(video, context),
              );
            },
          ),
        ],
      );
    });
  }

  Future<void> _downloadRecommendedVideo(
    Video video,
    BuildContext context, {
    bool isAudioOnly = false,
  }) async {
    if (video.isRejected ||
        video.status == VideoStatus.rejected ||
        !video.isApprovedByGeminiOrManual ||
        !VideoVisibilityPolicy.canViewVideo(video)) {
      AppSnackbar.warning(
        'This video is unavailable for offline viewing.',
      );
      return;
    }

    if (isAudioOnly) {
      await controller.downloadAudioOffline(
        context: context,
        video: video,
      );
    } else {
      controller.showDownloadQualityDialog(
        context,
        video,
      );
    }
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Videos', 'Audio', 'Recent'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Obx(() {
            final isSelected = controller.selectedCategory.value == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) controller.setCategory(category);
                },
                selectedColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                showCheckmark: false,
              ),
            );
          });
        },
      ),
    );
  }
}

class _DownloadVideoListCard extends StatelessWidget {
  const _DownloadVideoListCard({required this.video, required this.controller});
  final OfflineVideo video;
  final DownloadsController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => controller.playVideo(video),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 160,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppTheme.secondaryBackground),
                    errorWidget: (context, url, error) =>
                        Container(color: AppTheme.secondaryBackground),
                  ),
                ),
                // Offline / Audio badge
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          video.isAudioOnly
                              ? Icons.headphones_rounded
                              : Icons.lock_outline_rounded,
                          color: AppColors.textPrimary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video.isAudioOnly
                              ? 'ENCRYPTED AUDIO'
                              : 'ENCRYPTED OFFLINE',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        onPressed: () => _showOptions(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channelName} • ${video.views} ${video.views == '1' ? 'view' : 'views'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.enhanced_encryption_outlined,
                        color: AppColors.textPrimary,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'AES-256 Encrypted • ${controller.formatTimeAgo(video.downloadedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    Get.bottomSheet(
      Material(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildOptionItem(
                icon: Icons.delete_outline_rounded,
                label: 'Delete from downloads',
                color: AppColors.error,
                onTap: () {
                  Get.back();
                  _showDeleteConfirmation(context);
                },
              ),
              _buildOptionItem(
                icon: Icons.share_outlined,
                label: 'Share link',
                onTap: Get.back,
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final textColor = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color != null ? color.withValues(alpha: 0.15) : AppColors.bgSurfaceHover),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text(
          'Delete download?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${video.title}" from your downloads?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteVideoItem(video.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _RecommendedDownloadCard extends StatelessWidget {
  _RecommendedDownloadCard({
    required this.video,
    required this.isDownloaded,
    required this.onDownload,
    super.key,
    this.isDownloading = false,
  });

  final Video video;
  final bool isDownloaded;
  final bool isDownloading;
  final Future<void> Function() onDownload;
  final RxBool _isInitiating = false.obs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (video.isRejected ||
            video.status == VideoStatus.rejected ||
            !video.isApprovedByGeminiOrManual ||
            !VideoVisibilityPolicy.canViewVideo(video)) {
          AppSnackbar.warning(
            'This video is unavailable for playback.',
          );
          return;
        }
        if (isDownloaded) {
          final downloadsCtrl = Get.isRegistered<DownloadsController>()
              ? Get.find<DownloadsController>()
              : Get.put(DownloadsController());
          var offline = downloadsCtrl.videos
              .firstWhereOrNull((v) => v.id == video.id);
          offline ??= await downloadsCtrl.getOfflineVideo(video.id);
          if (offline != null) {
            downloadsCtrl.playVideo(offline);
            return;
          }
        }
        MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.bgSurfaceHover),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.bgSurfaceHover),
                  ),
                  if (video.duration.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channelName} • ${FormatUtils.formatCount(video.views)} ${video.views == 1 ? 'view' : 'views'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final active = isDownloading || _isInitiating.value;
              return IconButton(
                onPressed: (isDownloaded || active)
                    ? null
                    : () async {
                        _isInitiating.value = true;
                        try {
                          await onDownload();
                        } finally {
                          _isInitiating.value = false;
                        }
                      },
                icon: active
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      )
                    : Icon(
                        isDownloaded
                            ? Icons.download_done_rounded
                            : Icons.download_for_offline_outlined,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActiveDownloadCard extends StatelessWidget {
  const _ActiveDownloadCard({
    required this.task,
    required this.controller,
  });

  final ActiveDownloadTask task;
  final DownloadsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.bgDivider.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with live progress spinner overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: task.video.thumbnailUrl,
                    width: 120,
                    height: 70,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.bgSurfaceHover),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.bgSurfaceHover),
                  ),
                  Container(
                    width: 120,
                    height: 70,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  Obx(() {
                    final p = task.progress.value;
                    return SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: p > 0 ? p : null,
                        strokeWidth: 3,
                        color: AppColors.brand,
                        backgroundColor: Colors.white24,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info & Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.video.channelName} • ${task.quality}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  Obx(() {
                    final p = task.progress.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p > 0 ? p : null,
                            minHeight: 4,
                            color: AppColors.brand,
                            backgroundColor: AppColors.bgSurfaceHover,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              task.status.value,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (p > 0)
                              Text(
                                '${(p * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cancel Button
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              tooltip: 'Cancel download',
              onPressed: () => controller.cancelDownload(task.video.id),
            ),
          ],
        ),
      ),
    );
  }
}
