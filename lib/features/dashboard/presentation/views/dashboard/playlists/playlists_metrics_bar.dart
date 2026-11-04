import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/create_playlist_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_search_filter_bar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single YouTube Studio-style KPI metric summary card.
class PlaylistMetricSummaryCard extends StatelessWidget {
  const PlaylistMetricSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.isSelected = false,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.bgSurfaceHover : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.07),
              width: isSelected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        fontFamily: TWTypography.uiFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        fontFamily: TWTypography.brandFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header and summary metrics bar for the Playlists Management screen.
class PlaylistsMetricsBar extends GetView<PlaylistsManagementController> {
  const PlaylistsMetricsBar({
    required this.channelId,
    super.key,
  });

  final String channelId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. YouTube Studio Page Header & "+ New Playlist" Button
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              final titleInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Playlists',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                      fontFamily: TWTypography.brandFamily,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Manage and curate your channel playlists, series, and collections.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: TWTypography.uiFamily,
                    ),
                  ),
                ],
              );

              // YouTube Studio-style White Pill Button (Zero White-on-White Policy)
              final newPlaylistButton = ElevatedButton.icon(
                onPressed: () => CreatePlaylistDialog.show(
                  context,
                  channelId: channelId,
                ),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 19,
                  color: Colors.black,
                ),
                label: const Text(
                  'New Playlist',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: TWTypography.uiFamily,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleInfo,
                    const SizedBox(height: 14),
                    newPlaylistButton,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleInfo),
                  const SizedBox(width: 16),
                  newPlaylistButton,
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // 2. Responsive Summary Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              return Obx(() {
                return GridView.count(
                  crossAxisCount: isMobile ? 2 : 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  childAspectRatio: isMobile ? 2.1 : 2.5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    PlaylistMetricSummaryCard(
                      title: 'Total Playlists',
                      value: '${controller.totalPlaylistsCount}',
                      icon: Icons.playlist_play_rounded,
                      onTap: () => controller.setFilterMode('all'),
                      isSelected: controller.activeFilterMode.value == 'all',
                    ),
                    PlaylistMetricSummaryCard(
                      title: 'Linked Videos',
                      value: '${controller.totalVideosCount}',
                      icon: Icons.video_library_rounded,
                      onTap: () => controller.setFilterMode('all'),
                    ),
                    PlaylistMetricSummaryCard(
                      title: 'Public Playlists',
                      value: '${controller.publicPlaylistsCount}',
                      icon: Icons.public_rounded,
                      onTap: () => controller.setFilterMode('public'),
                      isSelected: controller.activeFilterMode.value == 'public',
                    ),
                    PlaylistMetricSummaryCard(
                      title: 'Unlisted / Private',
                      value:
                          '${controller.unlistedPlaylistsCount + controller.privatePlaylistsCount}',
                      icon: Icons.lock_outline_rounded,
                      onTap: () => controller.setFilterMode('unlisted'),
                      isSelected: controller.activeFilterMode.value ==
                              'unlisted' ||
                          controller.activeFilterMode.value == 'private',
                    ),
                  ],
                );
              });
            },
          ),

          const SizedBox(height: 18),

          // 3. YouTube Studio-style Filter & Search Bar
          const PlaylistsSearchFilterBar(),
        ],
      ),
    );
  }
}
