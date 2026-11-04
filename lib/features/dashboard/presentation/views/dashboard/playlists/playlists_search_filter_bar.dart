import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// YouTube-style pill filter chip with high contrast and zero white-on-white violations.
class PlaylistFilterChip extends StatelessWidget {
  const PlaylistFilterChip({
    required this.label,
    required this.mode,
    super.key,
  });

  final String label;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistsManagementController>();

    return Obx(() {
      final isSelected = controller.activeFilterMode.value == mode;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.setFilterMode(mode),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                // On white background: text MUST be black (Zero White-on-White Policy)
                color: isSelected ? Colors.black : AppColors.textPrimary,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// YouTube Studio-inspired search & filter toolbar.
class PlaylistsSearchFilterBar extends GetView<PlaylistsManagementController> {
  const PlaylistsSearchFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        // YouTube-style Pill Search Input Field
        final searchField = SizedBox(
          height: 40,
          child: TextField(
            controller: controller.searchController,
            maxLength: ContentValidator.defaultMaxSearchLength,
            buildCounter: (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            inputFormatters: TruthworldTextInputFormatters.withLimit(
              ContentValidator.defaultMaxSearchLength,
            ),
            onChanged: controller.updateSearchQuery,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFamily: TWTypography.uiFamily,
            ),
            decoration: InputDecoration(
              hintText: 'Search playlists by title or description...',
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontFamily: TWTypography.uiFamily,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 19,
              ),
              suffixIcon: Obx(() {
                if (controller.searchQuery.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.searchController.clear();
                    controller.updateSearchQuery('');
                  },
                );
              }),
              filled: true,
              fillColor: AppColors.bgSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
            ),
          ),
        );

        // Sort Pill Button (YouTube Studio Style)
        final sortButton = Obx(() {
          final sortMode = controller.activeSortMode.value;
          var sortLabel = 'Recently Updated';
          if (sortMode == 'videos_desc') sortLabel = 'Most Videos';
          if (sortMode == 'title_asc') sortLabel = 'Title (A-Z)';
          if (sortMode == 'oldest') sortLabel = 'Oldest First';

          return PopupMenuButton<String>(
            tooltip: 'Sort playlists',
            color: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            onSelected: controller.setSortMode,
            itemBuilder: (context) => [
              _buildSortItem('recent', 'Recently Updated', sortMode),
              _buildSortItem('videos_desc', 'Most Videos', sortMode),
              _buildSortItem('title_asc', 'Title (A-Z)', sortMode),
              _buildSortItem('oldest', 'Oldest First', sortMode),
            ],
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sort_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sortLabel,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: TWTypography.uiFamily,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        });

        // View Mode Toggle (Grid / List)
        final viewToggle = Obx(() {
          final isGrid = controller.isGridView.value;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: controller.toggleViewMode,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGrid
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGrid ? 'List' : 'Grid',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });

        // YouTube Filter Chips Row
        final filterChips = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PlaylistFilterChip(label: 'All', mode: 'all'),
              const SizedBox(width: 8),
              const PlaylistFilterChip(label: 'Public', mode: 'public'),
              const SizedBox(width: 8),
              const PlaylistFilterChip(label: 'Unlisted', mode: 'unlisted'),
              const SizedBox(width: 8),
              const PlaylistFilterChip(label: 'Private', mode: 'private'),
              const SizedBox(width: 12),
              sortButton,
              const SizedBox(width: 8),
              viewToggle,
            ],
          ),
        );

        if (isDesktop) {
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: searchField,
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: filterChips,
                ),
              ),
            ],
          );
        }

        // Responsive Mobile / Tablet Layout (Vertical Stack with Horizontal Chips)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchField,
            const SizedBox(height: 12),
            filterChips,
          ],
        );
      },
    );
  }

  PopupMenuItem<String> _buildSortItem(
    String value,
    String label,
    String currentSort,
  ) {
    final isSelected = value == currentSort;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_rounded : Icons.circle_outlined,
            size: 16,
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color:
                  isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
        ],
      ),
    );
  }
}
