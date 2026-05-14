//lib/features/presentation/views/home/slivertabbardelegate.dart
import 'package:flutter/material.dart';

class SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  final Function(int)?
  onTabTap; // Optional: For handling taps (e.g., category change)

  SliverTabBarDelegate(
    this.tabBar, {
    required this.backgroundColor,
    this.onTabTap,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Fallback if no controller: Warn and render placeholder (prevents assertion crash)
    final controller = tabBar.controller;
    if (controller == null) {
      debugPrint(
        'Warning: SliverTabBarDelegate requires TabBar with explicit TabController',
      );
      return Container(
        color: backgroundColor,
        height: tabBar.preferredSize.height,
        child: Center(
          child: Text(
            'Tabs Unavailable',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Wrap with theme-aware padding/elevation for your dark green design
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 2.0,
        labelStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        tabs: tabBar.tabs,
        onTap: onTabTap ?? tabBar.onTap,
      ),
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    // Optimize: Rebuild only if tabBar or background changes (avoids unnecessary renders)
    return tabBar != (oldDelegate as SliverTabBarDelegate).tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}





