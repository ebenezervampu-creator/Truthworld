import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/skeletons/shimmer_base.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/models/channel_trust_score.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_notification_options_sheet.dart';
import 'package:truthworld/features/channel/presentation/widgets/channel_trust_badge.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Channel header and action bar for both Mobile and Desktop views, providing
/// 0ms optimistic channel display, memory caching, responsive shimmer skeletons,
/// verification badge, follower counts, and subscribe/bell controls.
class VideoChannelActionBar {
  /// Compact shimmer loading bone for Mobile view matching exact channel bar dimensions.
  static Widget _buildShimmerMobile() {
    return ShimmerBase(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                shimmerBone(width: 36, height: 36, radius: 18),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shimmerBone(width: 110),
                    const SizedBox(height: 4),
                    shimmerBone(width: 70, height: 11),
                  ],
                ),
              ],
            ),
            shimmerBone(width: 88, height: 32, radius: 20),
          ],
        ),
      ),
    );
  }

  /// Compact shimmer loading bone for Desktop view matching exact channel bar dimensions.
  static Widget _buildShimmerDesktop() {
    return ShimmerBase(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            shimmerBone(width: 40, height: 40, radius: 20),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBone(width: 130),
                const SizedBox(height: 4),
                shimmerBone(width: 85, height: 12),
              ],
            ),
            const SizedBox(width: 16),
            shimmerBone(width: 105, height: 40, radius: 22),
          ],
        ),
      ),
    );
  }

  static Widget buildMobile({
    required BuildContext context,
    required VideoController controller,
    required ChannelController? channelController,
    required VoidCallback onSignInPrompt,
  }) {
    final isUserSignedIn = AuthService.to.isAuthenticated.value;

    return Obx(() {
      final video = controller.rxVideo.value;
      final effectiveChannelId = video.channelId.isNotEmpty
          ? video.channelId
          : (video.ownerId.isNotEmpty ? video.ownerId : '');

      final cachedChannel = ChannelMemoryCache.get(effectiveChannelId);
      final optimisticChannel = cachedChannel ??
          (video.channelName.trim().isNotEmpty
              ? Channel.fromVideo(video)
              : null);

      if (effectiveChannelId.isEmpty && optimisticChannel == null) {
        return _buildShimmerMobile();
      }

      final subCtrl = channelController?.subController ??
          ChannelSubscriptionController.to;
      if (effectiveChannelId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          subCtrl.fetchSubscriberCount(effectiveChannelId);
        });
      }

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: effectiveChannelId.isNotEmpty
            ? controller.getChannelStream(effectiveChannelId)
            : const Stream.empty(),
        builder: (context, snapshot) {
          Channel? channel;
          ChannelTrustScore? channelTrust;

          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.exists) {
            channel = Channel.fromDocumentSnapshot(snapshot.data!);

            final rawTrust = snapshot.data!.data()?['trustScore'] ??
                snapshot.data!.data()?['channelTrustScore'];
            channelTrust = rawTrust is Map<String, dynamic>
                ? ChannelTrustScore.fromMap(rawTrust)
                : null;
          } else {
            channel = optimisticChannel ??
                (effectiveChannelId.isNotEmpty
                    ? ChannelMemoryCache.get(effectiveChannelId)
                    : null);
            channelTrust =
                ChannelMemoryCache.getTrustScore(effectiveChannelId);
          }

          if (channel == null) {
            return _buildShimmerMobile();
          }

          return _buildMobileChannelContent(
            context: context,
            channel: channel,
            channelTrust: channelTrust,
            subCtrl: subCtrl,
            channelController: channelController,
            isUserSignedIn: isUserSignedIn,
            onSignInPrompt: onSignInPrompt,
          );
        },
      );
    });
  }

  static Widget _buildMobileChannelContent({
    required BuildContext context,
    required Channel channel,
    required ChannelTrustScore? channelTrust,
    required ChannelSubscriptionController subCtrl,
    required ChannelController? channelController,
    required bool isUserSignedIn,
    required VoidCallback onSignInPrompt,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 300;
        final isUltraCompact = availableWidth < 220;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Channel Avatar + Info
              Expanded(
                child: InkWell(
                  onTap: () => Get.offAndToNamed(
                    channel.channelRoute,
                    arguments: {'channel': channel},
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      // Channel Avatar
                      CircleAvatar(
                        radius: isUltraCompact ? 14 : (isCompact ? 16 : 18),
                        backgroundColor: Colors.grey.shade800,
                        child: ClipOval(
                          child: (channel.avatarUrl.isNotEmpty ||
                                  channel.bannerImageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: (channel.avatarUrl.isNotEmpty
                                          ? channel.avatarUrl
                                          : channel.bannerImageUrl)
                                      .replaceAll(' ', '%20'),
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    if (kIsWeb) {
                                      final targetUrl =
                                          (channel.avatarUrl.isNotEmpty
                                                  ? channel.avatarUrl
                                                  : channel.bannerImageUrl)
                                              .replaceAll(' ', '%20');
                                      return Image.network(
                                        targetUrl,
                                        width: isUltraCompact ? 28 : (isCompact ? 32 : 36),
                                        height: isUltraCompact ? 28 : (isCompact ? 32 : 36),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, err, stack) =>
                                            const Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.white70,
                                        ),
                                      );
                                    }
                                    return const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.white70,
                                    );
                                  },
                                  fit: BoxFit.cover,
                                  width: isUltraCompact ? 28 : (isCompact ? 32 : 36),
                                  height: isUltraCompact ? 28 : (isCompact ? 32 : 36),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                        ),
                      ),
                      SizedBox(width: isUltraCompact ? 6 : 8),

                      // Channel Info
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    channel.channelName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w700,
                                      fontSize: isCompact ? 13 : 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (channel.isVerified) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                                if (channelTrust != null && !isUltraCompact) ...[
                                  const SizedBox(width: 6),
                                  ChannelTrustBadge(score: channelTrust),
                                ],
                              ],
                            ),
                            if (!isUltraCompact) ...[
                              const SizedBox(height: 1),
                              Obx(() {
                                if (!channel.showSubscriberCount) {
                                  return const SizedBox.shrink();
                                }
                                final subCount = subCtrl.getSubscriberCount(
                                  channel.channelId,
                                  fallback: channel.subscriberCount,
                                );
                                return Text(
                                  '${FormatUtils.formatCount(subCount)} subscribers',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.roboto(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isUltraCompact ? 4 : 8),

              // Right: Subscribe Button + Notification bell if subbed
              Flexible(
                child: Obx(() {
                  final isSubbed =
                      subCtrl.isSubscribedTo(channel.channelId).value;
                  final notificationsEnabled =
                      subCtrl.notificationsEnabled.value;
                  final notificationOption =
                      subCtrl.getNotificationOption(channel.channelId).value;

                  IconData bellIcon;
                  if (!notificationsEnabled || notificationOption == 'none') {
                    bellIcon = Icons.notifications_off_outlined;
                  } else if (notificationOption == 'personalized') {
                    bellIcon = Icons.notifications_outlined;
                  } else {
                    bellIcon = Icons.notifications_active_outlined;
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: () {
                            if (!isUserSignedIn) return onSignInPrompt();
                            if (isSubbed) {
                              showNotificationsDialog(
                                context: context,
                                channelId: channel.channelId,
                                channelName: channel.channelName,
                                channelController: channelController,
                              );
                            } else {
                              subCtrl.subscribeToChannel(
                                channel.channelId,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isUltraCompact ? 8 : (isCompact ? 12 : 18),
                              vertical: isCompact ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSubbed
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isSubbed ? 'Subscribed' : 'Subscribe',
                                    style: GoogleFonts.roboto(
                                      color: isSubbed ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: isCompact ? 12 : 13.5,
                                    ),
                                  ),
                                  if (isSubbed && !isUltraCompact) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSubbed && !isUltraCompact) ...[
                        SizedBox(width: isCompact ? 6 : 8),
                        InkWell(
                          onTap: () => showNotificationsDialog(
                            context: context,
                            channelId: channel.channelId,
                            channelName: channel.channelName,
                            channelController: channelController,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(isCompact ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              bellIcon,
                              color: Colors.white,
                              size: isCompact ? 16 : 18,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget buildDesktop({
    required BuildContext context,
    required VideoController controller,
    required ChannelController? channelController,
    required VoidCallback onSignInPrompt,
  }) {
    final isUserSignedIn = AuthService.to.isAuthenticated.value;

    return Obx(() {
      final video = controller.rxVideo.value;
      final effectiveChannelId = video.channelId.isNotEmpty
          ? video.channelId
          : (video.ownerId.isNotEmpty ? video.ownerId : '');

      final cachedChannel = ChannelMemoryCache.get(effectiveChannelId);
      final optimisticChannel = cachedChannel ??
          (video.channelName.trim().isNotEmpty
              ? Channel.fromVideo(video)
              : null);

      if (effectiveChannelId.isEmpty && optimisticChannel == null) {
        return _buildShimmerDesktop();
      }

      final subCtrl = channelController?.subController ??
          ChannelSubscriptionController.to;
      if (effectiveChannelId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          subCtrl.fetchSubscriberCount(effectiveChannelId);
        });
      }

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: effectiveChannelId.isNotEmpty
            ? controller.getChannelStream(effectiveChannelId)
            : const Stream.empty(),
        builder: (context, snapshot) {
          Channel? channel;
          ChannelTrustScore? channelTrust;

          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.exists) {
            channel = Channel.fromDocumentSnapshot(snapshot.data!);

            final rawTrust = snapshot.data!.data()?['trustScore'] ??
                snapshot.data!.data()?['channelTrustScore'];
            channelTrust = rawTrust is Map<String, dynamic>
                ? ChannelTrustScore.fromMap(rawTrust)
                : null;
          } else {
            channel = optimisticChannel ??
                (effectiveChannelId.isNotEmpty
                    ? ChannelMemoryCache.get(effectiveChannelId)
                    : null);
            channelTrust =
                ChannelMemoryCache.getTrustScore(effectiveChannelId);
          }

          if (channel == null) {
            return _buildShimmerDesktop();
          }

          return _buildDesktopChannelContent(
            context: context,
            channel: channel,
            channelTrust: channelTrust,
            subCtrl: subCtrl,
            channelController: channelController,
            isUserSignedIn: isUserSignedIn,
            onSignInPrompt: onSignInPrompt,
          );
        },
      );
    });
  }

  static Widget _buildDesktopChannelContent({
    required BuildContext context,
    required Channel channel,
    required ChannelTrustScore? channelTrust,
    required ChannelSubscriptionController subCtrl,
    required ChannelController? channelController,
    required bool isUserSignedIn,
    required VoidCallback onSignInPrompt,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Channel Avatar + Info - Tappable to navigate to channel
          InkWell(
            onTap: () => Get.offAndToNamed(
              channel.channelRoute,
              arguments: {'channel': channel},
            ),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Channel Avatar - 40px circular
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade800,
                  child: ClipOval(
                    child: (channel.avatarUrl.isNotEmpty ||
                            channel.bannerImageUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: (channel.avatarUrl.isNotEmpty
                                    ? channel.avatarUrl
                                    : channel.bannerImageUrl)
                                .replaceAll(' ', '%20'),
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              if (kIsWeb) {
                                final targetUrl =
                                    (channel.avatarUrl.isNotEmpty
                                            ? channel.avatarUrl
                                            : channel.bannerImageUrl)
                                        .replaceAll(' ', '%20');
                                return Image.network(
                                  targetUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, err, stack) =>
                                      const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.white70,
                                  ),
                                );
                              }
                              return const Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.white70,
                              );
                            },
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                          )
                        : const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white70,
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Channel Info (name + subscribers)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel Name with Verified Badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            channel.channelName,
                            style: GoogleFonts.roboto(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (channel.isVerified) ...[
                          const SizedBox(width: 4),
                          // Grey/white checkmark badge
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.black,
                            ),
                          ),
                        ],
                        if (channelTrust != null) ...[
                          const SizedBox(width: 6),
                          ChannelTrustBadge(score: channelTrust),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    // Subscriber count reactively watched
                    Obx(() {
                      if (!channel.showSubscriberCount) {
                        return const SizedBox.shrink();
                      }
                      final subCount = subCtrl.getSubscriberCount(
                        channel.channelId,
                        fallback: channel.subscriberCount,
                      );
                      return Text(
                        '${FormatUtils.formatCount(subCount)} subscribers',
                        style: GoogleFonts.roboto(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Subscribe Button - White pill
          Obx(() {
            final isSubscribed =
                subCtrl.isSubscribedTo(channel.channelId).value;
            final notificationsEnabled =
                subCtrl.notificationsEnabled.value;
            final notificationOption =
                subCtrl.getNotificationOption(channel.channelId).value;

            IconData bellIcon;
            if (!notificationsEnabled || notificationOption == 'none') {
              bellIcon = Icons.notifications_off;
            } else if (notificationOption == 'personalized') {
              bellIcon = Icons.notifications_outlined;
            } else {
              bellIcon = Icons.notifications_active;
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (!isUserSignedIn) return onSignInPrompt();
                    if (isSubscribed) {
                      showNotificationsDialog(
                        context: context,
                        channelId: channel.channelId,
                        channelName: channel.channelName,
                        channelController: channelController,
                      );
                    } else {
                      subCtrl.subscribeToChannel(
                        channel.channelId,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubscribed
                        ? Colors.grey.shade800
                        : Colors.white,
                    foregroundColor: isSubscribed
                        ? Colors.white
                        : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                    ),
                    minimumSize: const Size(0, 40),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSubscribed ? 'Subscribed' : 'Subscribe',
                        style: GoogleFonts.roboto(
                          color: isSubscribed ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (isSubscribed) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSubscribed) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => showNotificationsDialog(
                      context: context,
                      channelId: channel.channelId,
                      channelName: channel.channelName,
                      channelController: channelController,
                    ),
                    icon: Icon(
                      bellIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.all(10),
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  static void showNotificationsDialog({
    required BuildContext context,
    required String channelId,
    required ChannelController? channelController,
    String? channelName,
  }) {
    final subCtrl = channelController?.subController ??
        (Get.isRegistered<ChannelController>(tag: channelId)
            ? Get.find<ChannelController>(tag: channelId).subController
            : ChannelSubscriptionController.to);
    ChannelNotificationOptionsSheet.show(
      context: context,
      channelId: channelId,
      channelName: channelName,
      subCtrl: subCtrl,
    );
  }
}
