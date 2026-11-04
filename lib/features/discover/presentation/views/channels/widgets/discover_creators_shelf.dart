import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/widgets/channel_trust_badge.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

/// Horizontal scrolling shelf displaying top creators on the main Discover Channels page.
/// Industry standard pattern for instant user engagement and creator social proof.
class DiscoverCreatorsShelf extends StatelessWidget {
  const DiscoverCreatorsShelf({
    required this.title,
    required this.subtitle,
    required this.channels,
    required this.controller,
    super.key,
    this.icon = Icons.trending_up_rounded,
    this.isDashboard = false,
  });

  final String title;
  final String subtitle;
  final List<Channel> channels;
  final DiscoverChannelsController controller;
  final IconData icon;
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shelf Header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
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

        // Horizontal Creator Cards List
        SizedBox(
          height: 245,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: channels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final channel = channels[index];
              final avatarUrl = channel.avatarUrl.isNotEmpty
                  ? channel.avatarUrl
                  : getCategoryImage(channel.category);

              return Container(
                width: 172,
                decoration: BoxDecoration(
                  color: const Color(0xFF141417),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
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
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Circular Avatar matching redesigned reference
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF222226),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl.trim().replaceAll(' ', '%20'),
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const ColoredBox(color: buttonBg),
                              errorWidget: (_, _, _) => Center(
                                child: Icon(
                                  getCategoryIcon(channel.category),
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Channel Name + Verified Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  channel.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: primaryText,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (channel.showVerifiedBadge) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  color: kDiscoverVerifiedBlue,
                                  size: 15,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Subscriber count (e.g. "1 sub", "245K subs")
                          Obx(() {
                            final dynamicCount = controller.getSubscriberCount(channel);
                            return Text(
                              '${formatSubscriberCount(dynamicCount)} ${dynamicCount == 1 ? 'sub' : 'subs'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          }),
                          const Spacer(),

                          // Subscribe / Subscribed Pill Button (Zero White-on-White compliant)
                          Obx(() {
                            final isSubscribed = controller.isSubscribed(channel.channelId);
                            return SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: isSubscribed
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF26262C),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.10),
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(22),
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            controller.toggleSubscription(channel);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'Subscribed',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 1,
                                                  height: 14,
                                                  color: Colors.white.withValues(alpha: 0.20),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.notifications_none_rounded,
                                                  color: Colors.white70,
                                                  size: 17,
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
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                      ),
                                      child: const Text(
                                        'Subscribe',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
