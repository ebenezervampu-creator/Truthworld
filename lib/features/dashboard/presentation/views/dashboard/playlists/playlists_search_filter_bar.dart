import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single choice chip for filtering playlists by visibility.
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
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => controller.setFilterMode(mode),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
        backgroundColor: const Color(0xFF0F0F0F),
        selectedColor: const Color(0xFF27272A),
        side: BorderSide(
          color: isSelected ? const Color(0xFF52525B) : const Color(0xFF27272A),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        showCheckmark: false,
      );
    });
  }
}

/// Studio search & filter controls bar for Playlists Management tab.
class PlaylistsSearchFilterBar extends GetView<PlaylistsManagementController> {
  const PlaylistsSearchFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;

          final searchField = TextField(
            controller: controller.searchController,
            onChanged: controller.updateSearchQuery,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search playlists by name or description...',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 18,
              ),
              suffixIcon: Obx(() {
                if (controller.searchQuery.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  onPressed: () {
                    controller.searchController.clear();
                    controller.updateSearchQuery('');
                  },
                );
              }),
              filled: true,
              fillColor: const Color(0xFF0F0F0F),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF52525B)),
              ),
            ),
          );

          final filterControls = Obx(() {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Filter Chips
                const PlaylistFilterChip(label: 'All', mode: 'all'),
                const PlaylistFilterChip(label: 'Public', mode: 'public'),
                const PlaylistFilterChip(label: 'Unlisted', mode: 'unlisted'),
                const PlaylistFilterChip(label: 'Private', mode: 'private'),

                // Sort Dropdown
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.activeSortMode.value,
                      dropdownColor: const Color(0xFF1E1E22),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'recent',
                          child: Text('Recently Updated'),
                        ),
                        DropdownMenuItem(
                          value: 'videos_desc',
                          child: Text('Most Videos'),
                        ),
                        DropdownMenuItem(
                          value: 'title_asc',
                          child: Text('Title (A-Z)'),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text('Oldest First'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.setSortMode(val);
                      },
                    ),
                  ),
                ),

                // View Toggle (Grid / List)
                IconButton(
                  tooltip: controller.isGridView.value
                      ? 'Switch to List View'
                      : 'Switch to Grid View',
                  icon: Icon(
                    controller.isGridView.value
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: controller.toggleViewMode,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0F0F),
                    side: const BorderSide(color: Color(0xFF27272A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          });

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                filterControls,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 14),
              filterControls,
            ],
          );
        },
      ),
    );
  }
}
