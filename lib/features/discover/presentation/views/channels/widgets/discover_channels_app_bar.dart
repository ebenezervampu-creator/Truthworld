import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';

/// App bar for standalone Discover Channels screen across desktop, tablet, and mobile.
/// Matches exact visual architecture from Image 1.
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
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DiscoverChannelsController>()
        ? Get.find<DiscoverChannelsController>()
        : null;

    if (controller != null) {
      return Obx(() {
        if (controller.selectedCategory.value != 'All') {
          return const SizedBox.shrink();
        }
        return _buildBar(context);
      });
    }

    return _buildBar(context);
  }

  Widget _buildBar(BuildContext context) {
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      toolbarHeight: 72,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF222226),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Discover Channels',
                  style: TextStyle(
                    fontSize: (isDesktop || isTablet) ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore and follow amazing creators across different categories',
                  style: TextStyle(
                    fontSize: (isDesktop || isTablet) ? 13 : 11,
                    color: Colors.white.withValues(alpha: 0.60),
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: Material(
            color: const Color(0xFF1E1E22),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onRefresh();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
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
          16,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF222226),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.explore_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Discover Channels',
                    style: TextStyle(
                      fontSize: (isDesktop || isTablet) ? 26 : 22,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Explore and follow amazing creators across different categories',
                    style: TextStyle(
                      fontSize: (isDesktop || isTablet) ? 13 : 11,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
