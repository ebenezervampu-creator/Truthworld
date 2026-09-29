import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/models/channel_trust_score.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_notification_options_sheet.dart';
import 'package:truthworld/features/channel/presentation/widgets/channel_trust_badge.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Channel header and action bar for both Mobile and Desktop views, providing
/// channel avatar, verification badge, follower counts, subscribe/bell toggle,
/// and channel membership CTA.
class VideoChannelActionBar {
  static Widget buildMobile({
    required BuildContext context,
    required VideoController controller,
    required ChannelController? channelController,
    required VoidCallback onSignInPrompt,
  }) {
    final isUserSignedIn = AuthService.to.isAuthenticated.value;

    return Obx(() {
      final effectiveChannelId = controller.video.channelId.isNotEmpty
          ? controller.video.channelId
          : (controller.video.ownerId.isNotEmpty ? controller.video.ownerId : '');

      if (effectiveChannelId.isEmpty) {
        return const SizedBox.shrink();
      }

      final subCtrl = channelController?.subController ?? ChannelSubscriptionController.to;
      subCtrl.fetchSubscriberCount(effectiveChannelId);

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: controller.getChannelStream(effectiveChannelId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final channel = Channel.fromDocumentSnapshot(snapshot.data!);
          final rawTrust = snapshot.data!.data()?['trustScore'] ??
              snapshot.data!.data()?['channelTrustScore'];
          final channelTrust = rawTrust is Map<String, dynamic>
              ? ChannelTrustScore.fromMap(rawTrust)
              : null;

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
                          radius: 18,
                          backgroundColor: Colors.grey.shade800,
                          child: ClipOval(
                            child:
                                (channel.avatarUrl.isNotEmpty ||
                                    channel.bannerImageUrl.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl:
                                        (channel.avatarUrl.isNotEmpty
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
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.white70,
                                        ),
                                    fit: BoxFit.cover,
                                    width: 36,
                                    height: 36,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),

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
                                        fontSize: 14,
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
                                  if (channelTrust != null) ...[
                                    const SizedBox(width: 6),
                                    ChannelTrustBadge(score: channelTrust),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 1),
                              Obx(() {
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Right: Subscribe Button + Notification bell if subbed
                Obx(() {
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
                      InkWell(
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
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSubbed
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isSubbed ? 'Subscribed' : 'Subscribe',
                                style: GoogleFonts.roboto(
                                  color: isSubbed ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (isSubbed) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (isSubbed) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => showNotificationsDialog(
                            context: context,
                            channelId: channel.channelId,
                            channelName: channel.channelName,
                            channelController: channelController,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              bellIcon,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ),
          );
        },
      );
    });
  }

  static Widget buildDesktop({
    required BuildContext context,
    required VideoController controller,
    required ChannelController? channelController,
    required VoidCallback onSignInPrompt,
  }) {
    final isUserSignedIn = AuthService.to.isAuthenticated.value;

    return Obx(() {
      final effectiveChannelId = controller.video.channelId.isNotEmpty
          ? controller.video.channelId
          : (controller.video.ownerId.isNotEmpty ? controller.video.ownerId : '');

      if (effectiveChannelId.isEmpty) {
        return const SizedBox.shrink();
      }

      final subCtrl = channelController?.subController ?? ChannelSubscriptionController.to;
      subCtrl.fetchSubscriberCount(effectiveChannelId);

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: controller.getChannelStream(effectiveChannelId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final channel = Channel.fromDocumentSnapshot(snapshot.data!);
          final rawTrust = snapshot.data!.data()?['trustScore'] ??
              snapshot.data!.data()?['channelTrustScore'];
          final channelTrust = rawTrust is Map<String, dynamic>
              ? ChannelTrustScore.fromMap(rawTrust)
              : null;

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
                          child:
                              (channel.avatarUrl.isNotEmpty ||
                                  channel.bannerImageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl:
                                      (channel.avatarUrl.isNotEmpty
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
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.person,
                                        size: 20,
                                        color: Colors.white70,
                                      ),
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
                                // Grey/white checkmark badge matching image
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
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSubscribed ? 'Subscribed' : 'Subscribe',
                              style: GoogleFonts.roboto(
                                color: isSubscribed ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (isSubscribed) ...[
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
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            padding: const EdgeInsets.all(8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ),
          );
        },
      );
    });
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
