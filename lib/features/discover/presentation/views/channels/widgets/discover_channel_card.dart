import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single channel row card displaying channel avatar, verified badge, subscriber count, and subscribe action.
class DiscoverChannelCard extends StatelessWidget {
  const DiscoverChannelCard({
    required this.channel,
    required this.subscriberCount,
    super.key,
    this.isDashboard = false,
  });

  final Channel channel;
  final int subscriberCount;
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    final handleText = channel.handle.isNotEmpty
        ? (channel.handle.startsWith('@')
            ? channel.handle
            : '@${channel.handle}')
        : '@${channel.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final avatarSize =
        screenWidth < 380 ? 56.0 : (screenWidth < 600 ? 68.0 : 80.0);
    final avatarGap = screenWidth < 380 ? 10.0 : 16.0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        if (isDashboard && Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().navigateToChannelDetail(channel);
        } else {
          Get.toNamed(
            channel.channelRoute,
            arguments: {'channel': channel},
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            // Circular Avatar
            ClipOval(
              child: Container(
                width: avatarSize,
                height: avatarSize,
                color: AppColors.bgSurfaceHover,
                child: channel.avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: channel.avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: AppColors.bgDivider),
                        errorWidget: (context, url, error) => Icon(
                          Icons.account_circle,
                          size: avatarSize * 0.5,
                          color: Colors.white70,
                        ),
                      )
                    : Icon(
                        Icons.account_circle,
                        size: avatarSize * 0.5,
                        color: Colors.white70,
                      ),
              ),
            ),
            SizedBox(width: avatarGap),
            // Channel Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$handleText • ${formatSubscriberCount(subscriberCount)} subscribers',
                    style: const TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channel.description.isNotEmpty
                        ? channel.description
                        : 'Official channel. Explore and join.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Subscribe button
            SubscribeButton(
              channelId: channel.channelId,
              channelName: channel.name,
            ),
          ],
        ),
      ),
    );
  }
}
