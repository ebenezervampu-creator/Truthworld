import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// THEME COLORS FOR CHANNEL DETAILS
// ==========================================================================
const Color ytBackground = AppColors.bgPage;
const Color ytSurface = Color(0xFF1A1A1A);
const Color ytSurfaceLight = Color(0xFF262626);
const Color ytTextPrimary = AppColors.textPrimary;
const Color ytTextSecondary = AppColors.textSecondary;
const Color ytTextTertiary = AppColors.textTertiary;
const Color ytSubscribeBtn = AppColors.textPrimary;
const Color ytSubscribeBtnText = AppColors.bgPage;
const Color ytSubscribedBtn = Color(0xFF262626);
const Color ytLinkBlue = AppColors.textLink;
const Color ytBorder = AppColors.searchBorder;

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================
const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1000;
const double kDesktopBreakpoint = 1200;

// ==========================================================================
// SLIVER APP BAR DELEGATE
// ==========================================================================
class ChannelSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  ChannelSliverTabBarDelegate(this.child, {required this.maxHeight});
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
    return ColoredBox(color: ytBackground, child: child);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
