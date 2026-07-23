import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
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

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> with TickerProviderStateMixin {
  final controller = Get.put(DownloadsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => controller.isSearchExpanded.value
                      ? Expanded(
                          child: Container(
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
                          ),
                        )
                      : Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                              onPressed: () {
                                if (widget.isDashboard) {
                                  Get.find<HomeController>().sideNavSelectedIndex.value = HomeController.indexLibrary;
                                } else {
                                  Get.back();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Downloads',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
                Row(
                  children: [
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
                      icon: Obx(() => Icon(
                        controller.isListView.value ? Icons.grid_view_rounded : Icons.view_list_rounded,
                        color: AppColors.textPrimary,
                      )),
                      onPressed: controller.toggleView,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        Obx(() {
          if (controller.isLoading.value) {
            return const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.brand,
                ),
              ),
            );
          }

          if (controller.errorMessage.isNotEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Error: ${controller.errorMessage.value}',
                    style: const TextStyle(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final videos = controller.filteredVideos;
          final groupedVideos = controller.groupVideosByDate(videos);

          return SliverList(
            delegate: SliverChildListDelegate([
              if (videos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                    _DownloadVideoListCard(video: video, controller: controller),
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
    final mainController = Get.isRegistered<MainController>()
        ? Get.find<MainController>()
        : Get.put(MainController());

    return Obx(() {
      final allVideos = mainController.filteredVideos.isNotEmpty
          ? mainController.filteredVideos
          : mainController.videos;

      final downloadedIds = controller.videos.map((v) => v.id).toSet();
      final recommended = allVideos
          .where((v) => !downloadedIds.contains(v.id))
          .take(10)
          .toList();

      final displayList = recommended.isNotEmpty ? recommended : allVideos.take(10).toList();

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
                  color: AppColors.brand,
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
                video: video,
                isDownloaded: downloadedIds.contains(video.id),
                onDownload: () => _downloadRecommendedVideo(video, context),
              );
            },
          ),
        ],
      );
    });
  }

  Future<void> _downloadRecommendedVideo(Video video, BuildContext context) async {
    try {
      final offlineVideo = OfflineVideo(
        id: video.id,
        title: video.title,
        channelName: video.channelName,
        channelImage: video.channelImage.isNotEmpty
            ? video.channelImage
            : video.channelAvatarUrl,
        views: FormatUtils.formatCount(video.views),
        thumbnailUrl: video.thumbnailUrl,
        downloadedAt: DateTime.now(),
      );

      AppSnackbar.show(
        'Downloading...',
        "Starting download for '${video.title}'",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.brand.withValues(alpha: 0.8),
        colorText: AppColors.textPrimary,
      );

      var videoBytes = Uint8List(0);
      final targetUrl = video.originalUrl.isNotEmpty ? video.originalUrl : video.videoUrl;
      if (targetUrl.isNotEmpty && targetUrl.startsWith('http')) {
        final res = await http.get(Uri.parse(targetUrl));
        if (res.statusCode == 200) {
          videoBytes = res.bodyBytes;
        }
      }

      await saveOfflineVideoBytes(
        video.id,
        videoBytes,
        offlineVideo,
      );

      if (Get.isRegistered<DownloadsController>()) {
        await Get.find<DownloadsController>().loadVideos();
      }

      AppSnackbar.show(
        'Download Complete',
        "'${video.title}' downloaded successfully.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withValues(alpha: 0.8),
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      AppSnackbar.show(
        'Download Failed',
        'Could not download video: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.8),
        colorText: AppColors.textPrimary,
      );
    }
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Videos', 'Offline', 'Recent'];
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
                // Offline badge
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
                    child: const Row(
                      children: [
                        Icon(Icons.download_done, color: AppColors.textPrimary, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'OFFLINE',
                          style: TextStyle(
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
                    '${video.channelName} • ${video.views} views',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Downloaded ${controller.formatTimeAgo(video.downloadedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
          color: (color ?? AppColors.brand).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? AppColors.textSecondary, size: 20),
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
              foregroundColor: AppColors.textPrimary,
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

class _RecommendedDownloadCard extends StatefulWidget {

  const _RecommendedDownloadCard({
    required this.video,
    required this.isDownloaded,
    required this.onDownload,
  });
  final Video video;
  final bool isDownloaded;
  final VoidCallback onDownload;

  @override
  State<_RecommendedDownloadCard> createState() => _RecommendedDownloadCardState();
}

class _RecommendedDownloadCardState extends State<_RecommendedDownloadCard> {
  bool isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.toNamed('/watch?v=${widget.video.id}');
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
                    imageUrl: widget.video.thumbnailUrl,
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.bgSurfaceHover),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.bgSurfaceHover),
                  ),
                  if (widget.video.duration.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.video.duration,
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
                    widget.video.title,
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
                    '${widget.video.channelName} • ${FormatUtils.formatCount(widget.video.views)} views',
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
            IconButton(
              onPressed: (widget.isDownloaded || isDownloading)
                  ? null
                  : () async {
                      setState(() {
                        isDownloading = true;
                      });
                      widget.onDownload();
                      if (mounted) {
                        setState(() {
                          isDownloading = false;
                        });
                      }
                    },
              icon: isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  : Icon(
                      widget.isDownloaded
                          ? Icons.download_done_rounded
                          : Icons.download_for_offline_outlined,
                      color: widget.isDownloaded
                          ? AppColors.brand
                          : AppColors.textPrimary,
                      size: 26,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}






