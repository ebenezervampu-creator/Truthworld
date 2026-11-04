import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

/// Filter & Sort bar matching the uploaded UI:
/// - Left: Filter chips ("Latest", "From followed channels", "Trending", "Popular")
/// - Right: "Sort by" dropdown pill and Grid/List layout toggle
/// - Responsive: scrollable filter chips on mobile, clean spacing on desktop
class FollowingTopicsFilterBar extends StatelessWidget {
  const FollowingTopicsFilterBar({
    required this.controller,
    required this.isMobile,
    super.key,
  });

  final FollowingTopicsController controller;
  final bool isMobile;

  static const List<String> _filters = [
    'Latest',
    'From followed channels',
    'Trending',
    'Popular',
  ];

  static const List<String> _sortOptions = [
    'Newest first',
    'Oldest first',
    'Most popular',
    'Most viewed',
  ];

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Sort videos by',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                ..._sortOptions.map((option) {
                  final isSelected = controller.selectedSortOrder.value == option;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                      size: 20,
                    ),
                    title: Text(
                      option,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFD0D0D0),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.setSortOrder(option);
                      Get.back<void>();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: 10,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map(_buildFilterChip).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Sort & View Mode Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSortDropdown(context),
                        _buildLayoutToggle(),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  // Left: Filter Chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map(_buildFilterChip).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Right: Sort by & View Toggle
                  _buildSortDropdown(context),
                  const SizedBox(width: 10),
                  _buildLayoutToggle(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    return Obx(() {
      final isActive = controller.activeVideoFilter.value == filter;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            controller.setVideoFilter(filter);
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : const Color(0xFF222224),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              filter,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSortDropdown(BuildContext context) {
    return Obx(() {
      final currentSort = controller.selectedSortOrder.value;

      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showSortMenu(context);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF222224),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sort_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Sort by  ',
                style: TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                currentSort,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLayoutToggle() {
    return Obx(() {
      final isGrid = controller.isGridView.value;

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grid Toggle Button
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.setGridView(true);
              },
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isGrid ? const Color(0xFF2C2C30) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isGrid
                      ? Border.all(color: Colors.white.withValues(alpha: 0.20))
                      : null,
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: isGrid ? Colors.white : const Color(0xFF8E8E93),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 3),

            // List Toggle Button
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.setGridView(false);
              },
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: !isGrid ? const Color(0xFF2C2C30) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: !isGrid
                      ? Border.all(color: Colors.white.withValues(alpha: 0.20))
                      : null,
                ),
                child: Icon(
                  Icons.view_agenda_outlined,
                  color: !isGrid ? Colors.white : const Color(0xFF8E8E93),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
