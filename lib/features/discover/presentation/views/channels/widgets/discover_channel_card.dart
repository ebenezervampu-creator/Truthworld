import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/channel/presentation/widgets/channel_trust_badge.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Single channel row item displaying squircle thumbnail, verified badge, truth trust score,
/// stats, bio, subscribe pill button, overflow menu, and on-demand video preview carousel.
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF19191D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary Row: Avatar + Details + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular Avatar Thumbnail
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF222226),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
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
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, stack) => Center(
                                child: Icon(
                                  getCategoryIcon(channel.category),
                                  color: Colors.white54,
                                  size: 26,
                                ),
                              ),
                            );
                          }
                          return Center(
                            child: Icon(
                              getCategoryIcon(channel.category),
                              color: Colors.white54,
                              size: 26,
                            ),
                          );
                        },
                      );
                    }(),
                  ),
                  const SizedBox(width: 12),

                  // Channel Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title + Verified Checkmark + Channel Trust Badge
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (channel.channelTrustScore != null)
                              ChannelTrustBadge(score: channel.channelTrustScore),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Handle
                        Text(
                          handleText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),

                        // Subscribers & Videos Stats
                        Obx(() {
                          final dynamicCount =
                              ChannelSubscriptionController.channelSubscriberCounts[channel.channelId] ??
                                  (controller?.getSubscriberCount(channel) ?? subscriberCount);
                          return Text(
                            '${formatSubscriberCount(dynamicCount)} subscribers • ${channel.videoCount} videos',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
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
                              ? Container(
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF26262C),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.10),
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        controller.toggleSubscription(channel);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Subscribed',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 1,
                                              height: 12,
                                              color: Colors.white.withValues(alpha: 0.20),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.notifications_none_rounded,
                                              color: Colors.white70,
                                              size: 15,
                                            ),
                                          ],
                                        ),
                                      ),
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
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text(
                                    'Subscribe',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
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
                              horizontal: 14,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Subscribe',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // Overflow menu button (⋮)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.white.withValues(alpha: 0.70),
                          size: 19,
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

              // Bio / Description
              if (channel.description.isNotEmpty) ...[
                const SizedBox(height: 8),
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

              // On-Demand Content Previews Action & Carousel
              if (controller != null && channel.videoCount > 0) ...[
                const SizedBox(height: 8),
                Obx(() {
                  final isExpanded = controller.isChannelPreviewExpanded(channel.channelId);
                  final isLoading = controller.isLoadingPreview(channel.channelId);
                  final previews = controller.getChannelPreviews(channel.channelId);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle Button
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          controller.toggleChannelPreview(channel.channelId);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.play_circle_outline_rounded,
                                size: 14,
                                color: isExpanded ? Colors.white : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExpanded ? 'Hide Recent Videos' : 'Preview Recent Videos',
                                style: TextStyle(
                                  color: isExpanded ? Colors.white : Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Expandable Preview Videos Row
                      if (isExpanded) ...[
                        const SizedBox(height: 8),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else if (previews == null || previews.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'No public videos available yet.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11.5,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              for (int i = 0; i < previews.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: _buildVideoPreviewCard(context, previews[i]),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ],
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreviewCard(BuildContext context, Video video) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        MiniplayerNavigationHelper.navigateToVideoScreen(
          video: video,
          routeArguments: {
            'video': video,
            'heroTag': 'discover_preview_${video.id}',
          },
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF222227),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 Thumbnail with Duration Pill
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl.trim().replaceAll(' ', '%20'),
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const ColoredBox(color: buttonBg),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: buttonBg,
                        child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 20),
                      ),
                    ),
                    if (video.duration.isNotEmpty)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Video Title
            Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: primaryText,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),

            // View Count
            Text(
              '${FormatUtils.formatCount(video.viewCount)} views',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
