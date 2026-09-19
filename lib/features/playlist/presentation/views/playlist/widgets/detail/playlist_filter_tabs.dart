import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';

/// Filter tabs for toggling between All videos and standard videos.
class PlaylistFilterTabs extends StatelessWidget {
  const PlaylistFilterTabs({
    required this.controller,
    super.key,
  });

  final PlaylistDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final filters = ['All', 'Videos'];
      final selectedFilter = controller.filterValue.value.isEmpty
          ? 'All'
          : controller.filterValue.value;

      return Container(
        color: ytBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: filters.map((filter) {
            final isSelected = selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    controller.setFilterValue(filter == 'All' ? '' : filter);
                  }
                },
                backgroundColor: ytSurface,
                selectedColor: ytTextPrimary,
                labelStyle: TextStyle(
                  color: isSelected ? ytBackground : ytTextPrimary,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? ytTextPrimary : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

/// SliverPersistentHeaderDelegate for pinning filter tabs while scrolling.
class PlaylistFilterTabDelegate extends SliverPersistentHeaderDelegate {
  PlaylistFilterTabDelegate({
    required this.child,
    required this.maxHeight,
  });

  final Widget child;
  final double maxHeight;

  @override
  double get minExtent => maxHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: ytBackground,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
