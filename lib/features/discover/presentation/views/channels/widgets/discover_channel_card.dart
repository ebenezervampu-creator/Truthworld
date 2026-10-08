import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

/// Single channel row item displaying squircle thumbnail, verified badge, stats, bio,
/// subscribe pill button, and overflow menu.
/// Matches exact visual architecture from Image 2.
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
        ? (channel.handle.startsWith('@') ? channel.handle : '@${channel.handle}')
        : '@${channel.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

    final controller = Get.isRegistered<DiscoverChannelsController>()
        ? Get.find<DiscoverChannelsController>()
        : null;

    final avatarUrl = channel.avatarUrl.isNotEmpty
        ? channel.avatarUrl
        : getCategoryImage(channel.category);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Squircle Thumbnail (rounded square photo matching Image 2)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF222226),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: () {
                  final cleanAvatarUrl = avatarUrl.trim().replaceAll(' ', '%20');
                  return CachedNetworkImage(
                    imageUrl: cleanAvatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: buttonBg),
                    errorWidget: (context, url, error) {
                      if (kIsWeb && cleanAvatarUrl.isNotEmpty) {
                        return Image.network(
                          cleanAvatarUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, err, stack) => Center(
                            child: Icon(
                              getCategoryIcon(channel.category),
                              color: Colors.white54,
                              size: 28,
                            ),
                          ),
                        );
                      }
                      return Center(
                        child: Icon(
                          getCategoryIcon(channel.category),
                          color: Colors.white54,
                          size: 28,
                        ),
                      );
                    },
                  );
                }(),
              ),
            ),
            const SizedBox(width: 14),

            // Channel Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title + Blue Verified Checkmark Badge
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
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified,
                          color: kDiscoverVerifiedBlue,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Handle
                  Text(
                    handleText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Subscribers & Videos Stats
                  Text(
                    '${formatSubscriberCount(subscriberCount)} subscribers • ${channel.videoCount} videos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),

                  // Bio / Description
                  if (channel.description.isNotEmpty)
                    Text(
                      channel.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Actions: Subscribe Button + Overflow Menu
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller != null)
                  Obx(() {
                    final isSubscribed = controller.isSubscribed(channel.channelId);
                    return isSubscribed
                        ? OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              controller.toggleSubscription(channel);
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFF27272A),
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Subscribed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              controller.toggleSubscription(channel);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Subscribe',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                  })
                else
                  ElevatedButton(
                    onPressed: HapticFeedback.lightImpact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Subscribe',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Overflow menu button (⋮)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withValues(alpha: 0.70),
                    size: 20,
                  ),
                  color: const Color(0xFF222226),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  onSelected: (value) {
                    HapticFeedback.lightImpact();
                    if (value == 'view') {
                      Get.toNamed(
                        channel.channelRoute,
                        arguments: {'channel': channel},
                      );
                    } else if (value == 'copy') {
                      Clipboard.setData(ClipboardData(text: handleText));
                      AppSnackbar.info('Handle copied to clipboard');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.launch_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'View Channel',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Copy Handle',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
