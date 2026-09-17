import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/create_playlist_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_search_filter_bar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single clickable metric card displaying a playlist summary statistic.
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF27272A)
                : const Color(0xFF141417),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF52525B)
                  : const Color(0xFF27272A),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF202024),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Action Buttons Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Playlists',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Manage and curate your channel playlists and series.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => CreatePlaylistDialog.show(
                        context,
                        channelId: channelId,
                      ),
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'New Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27272A),
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFF3F3F46),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Playlists',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Manage and curate your channel playlists and series.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => CreatePlaylistDialog.show(
                      context,
                      channelId: channelId,
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'New Playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27272A),
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF3F3F46),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Metric Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Obx(() {
                return GridView.count(
                  crossAxisCount: isMobile ? 2 : 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  childAspectRatio: isMobile ? 1.8 : 2.4,
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

          const SizedBox(height: 16),

          // Studio Search & Control Bar
          const PlaylistsSearchFilterBar(),
        ],
      ),
    );
  }
}
