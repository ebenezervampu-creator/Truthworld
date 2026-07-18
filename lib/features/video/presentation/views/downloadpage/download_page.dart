import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

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
  final bool isDashboard;
  const DownloadsPage({super.key, this.isDashboard = false});

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
                                color: Colors.white,
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
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                if (widget.isDashboard) {
                                  Get.find<HomeController>().sideNavSelectedIndex.value = HomeController.indexLibrary;
                                } else {
                                  Get.back();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Downloads',
                              style: GoogleFonts.roboto(
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
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  controller.isSearchExpanded.value = true,
                            )
                          : const SizedBox.shrink(),
                    ),
                    IconButton(
                      icon: Obx(() => Icon(
                        controller.isListView.value ? Icons.grid_view_rounded : Icons.view_list_rounded,
                        color: Colors.white,
                      )),
                      onPressed: () => controller.toggleView(),
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
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final videos = controller.filteredVideos;
          if (videos.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No downloads found',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          final groupedVideos = controller.groupVideosByDate(videos);

          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final dateKey = groupedVideos.keys.elementAt(index);
              final dateVideos = groupedVideos[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Text(
                      dateKey,
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...dateVideos.map(
                    (video) =>
                        _DownloadVideoListCard(video: video, controller: controller),
                  ),
                ],
              );
            }, childCount: groupedVideos.length),
          );
        }),
      ],
    );
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
                selectedColor: Colors.white,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: GoogleFonts.roboto(
                  color: isSelected ? Colors.black : Colors.white,
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
  final OfflineVideo video;
  final DownloadsController controller;
  const _DownloadVideoListCard({required this.video, required this.controller});

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
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.download_done, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'OFFLINE',
                          style: TextStyle(
                            color: Colors.white,
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
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
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
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Downloaded ${controller.formatTimeAgo(video.downloadedAt)}',
                    style: GoogleFonts.roboto(
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete from downloads',
              color: Colors.red,
              onTap: () {
                Get.back();
                _showDeleteConfirmation(context);
              },
            ),
            _buildOptionItem(
              icon: Icons.share_outlined,
              label: 'Share link',
              onTap: () {
                Get.back();
                // Implement share
              },
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
        style: GoogleFonts.roboto(
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
        title: Text(
          'Delete download?',
          style: GoogleFonts.roboto(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${video.title}" from your downloads?',
          style: GoogleFonts.roboto(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteVideoItem(video.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
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






