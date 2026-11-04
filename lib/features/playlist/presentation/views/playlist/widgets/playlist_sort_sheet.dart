import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet for sorting playlists.
void showPlaylistSortBottomSheet({
  required BuildContext context,
  required PlaylistController controller,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort Playlists',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PlaylistSortOptionTile(
                    value: 'index',
                    label: 'Custom Order',
                    icon: Icons.format_list_numbered_rounded,
                    sortBy: controller.sortBy,
                    isAscending: controller.isAscending,
                    onSelected: controller.setSortBy,
                    onTap: () => Navigator.pop(context),
                  ),
                  PlaylistSortOptionTile(
                    value: 'recent',
                    label: 'Recently updated',
                    icon: Icons.access_time_rounded,
                    sortBy: controller.sortBy,
                    isAscending: controller.isAscending,
                    onSelected: controller.setSortBy,
                    onTap: () => Navigator.pop(context),
                  ),
                  PlaylistSortOptionTile(
                    value: 'name',
                    label: 'Name',
                    icon: Icons.sort_by_alpha_rounded,
                    sortBy: controller.sortBy,
                    isAscending: controller.isAscending,
                    onSelected: controller.setSortBy,
                    onTap: () => Navigator.pop(context),
                  ),
                  PlaylistSortOptionTile(
                    value: 'videos',
                    label: 'Videos',
                    icon: Icons.video_library_rounded,
                    sortBy: controller.sortBy,
                    isAscending: controller.isAscending,
                    onSelected: controller.setSortBy,
                    onTap: () => Navigator.pop(context),
                  ),
                  PlaylistSortOptionTile(
                    value: 'created',
                    label: 'Created',
                    icon: Icons.calendar_today_rounded,
                    sortBy: controller.sortBy,
                    isAscending: controller.isAscending,
                    onSelected: controller.setSortBy,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PlaylistSortOptionTile extends StatelessWidget {
  const PlaylistSortOptionTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.sortBy,
    required this.isAscending,
    required this.onSelected,
    required this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final IconData icon;
  final RxString sortBy;
  final RxBool isAscending;
  final ValueChanged<String> onSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = sortBy.value == value;

      return InkWell(
        onTap: () {
          onSelected(value);
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brand.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: AppColors.brand) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.brand : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  isAscending.value
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
            ],
          ),
        ),
      );
    });
  }
}
