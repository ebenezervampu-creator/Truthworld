import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import '../theme/video_screen_theme.dart';

/// Channel information section with avatar, name, subscribers, and subscribe button
class ChannelSection extends StatelessWidget {
  final VideoController controller;
  final ChannelController channelController;
  final bool isUserSignedIn;
  final VoidCallback showSignInPrompt;

  const ChannelSection({
    super.key,
    required this.controller,
    required this.channelController,
    required this.isUserSignedIn,
    required this.showSignInPrompt,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.video.channelId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('channels')
          .doc(controller.video.channelId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final channel = Channel.fromDocumentSnapshot(snapshot.data!);

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(VideoScreenTheme.radiusLg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel Avatar + Info - Tappable to navigate to channel
              InkWell(
                onTap: () => Get.toNamed('/channel/${channel.id}'),
                borderRadius: BorderRadius.circular(VideoScreenTheme.radiusMd),
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
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                                memCacheWidth: 80,
                                memCacheHeight: 80,
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
                            Text(
                              channel.channelName,
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
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
                          ],
                        ),
                        const SizedBox(height: 1),
                        // Subscriber count in grey
                        Text(
                          '${FormatUtils.formatCount(channel.subscriberCount)} subscribers',
                          style: GoogleFonts.roboto(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Subscribe Button
              _buildSubscribeButton(channel, channelController, isUserSignedIn, showSignInPrompt),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscribeButton(
    Channel channel,
    ChannelController channelController,
    bool isUserSignedIn,
    VoidCallback showSignInPrompt,
  ) {
    return Obx(() {
      final isSubscribed = channelController.isSubscribed.value;
      final preference = channelController.notificationPreference.value;

      if (isSubscribed) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                if (!isUserSignedIn) return showSignInPrompt();
                channelController.toggleSubscription(channel.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VideoScreenTheme.radiusFull),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                minimumSize: Size.zero,
              ),
              child: Text(
                'Subscribed',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Notification bell
            IconButton(
              icon: Icon(
                preference == 'all'
                    ? Icons.notifications
                    : preference == 'personalized'
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                size: 22,
                color: Colors.white,
              ),
              onPressed: () {
                if (!isUserSignedIn) return showSignInPrompt();
                _showNotificationOptions(channel.id);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        );
      } else {
        return ElevatedButton(
          onPressed: () {
            if (!isUserSignedIn) return showSignInPrompt();
            channelController.toggleSubscription(channel.id);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VideoScreenTheme.radiusFull),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            minimumSize: Size.zero,
          ),
          child: Text(
            'Subscribe',
            style: GoogleFonts.roboto(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    });
  }

  void _showNotificationOptions(String channelId) {
    // Implementation for notification options dialog
    // Extracted to separate method for clarity
  }
}
