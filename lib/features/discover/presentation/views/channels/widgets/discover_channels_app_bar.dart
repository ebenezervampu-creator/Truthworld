import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// App bar for standalone Discover Channels screen across desktop, tablet, and mobile.
class DiscoverChannelsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DiscoverChannelsAppBar({
    required this.onRefresh,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final bool isDesktop;
  final bool isTablet;
  final VoidCallback onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.textPrimary,
                  AppColors.textPrimary.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Discover Channels',
            style: TextStyle(
              fontSize: (isDesktop || isTablet) ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: buttonBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onRefresh();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Top header widget displayed when Discover Channels is embedded inside a Dashboard.
class DiscoverChannelsDashboardHeader extends StatelessWidget {
  const DiscoverChannelsDashboardHeader({
    required this.padding,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final bool isDesktop;
  final bool isTablet;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          16,
          padding.right,
          20,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.textPrimary,
                    AppColors.textPrimary.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Discover Channels',
              style: TextStyle(
                fontSize: (isDesktop || isTablet) ? 26 : 22,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
