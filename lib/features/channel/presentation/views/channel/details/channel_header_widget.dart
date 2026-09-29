import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/animated_interaction_buttons.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_state_widgets.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_notification_options_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Channel header widget showing avatar, title, handle, subscriber count, description, and subscription controls.
class ChannelHeaderWidget extends StatelessWidget {
  final Channel channel;
  final ChannelController controller;
  final bool isDesktop;
  final bool isTablet;
  final bool isDashboard;

  const ChannelHeaderWidget({
    required this.channel,
    required this.controller,
    this.isDesktop = false,
    this.isTablet = false,
    this.isDashboard = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);
    final avatarSize = isDesktop ? 120.0 : (isTablet ? 100.0 : 80.0);

    return Container(
      color: ytBackground,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'channel-avatar-${channel.channelId}',
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ytSurfaceLight),
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: channel.avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => ColoredBox(
                              color: ytSurface,
                              child: Icon(
                                Icons.person,
                                color: ytTextTertiary,
                                size: avatarSize * 0.4,
                              ),
                            ),
                            errorWidget: (context, url, error) => ColoredBox(
                              color: ytSurface,
                              child: Icon(
                                Icons.person,
                                color: ytTextTertiary,
                                size: avatarSize * 0.4,
                              ),
                            ),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser == null ||
                                channel.ownerId != currentUser.uid) {
                              return const SizedBox.shrink();
                            }

                            return Obx(() {
                              final status =
                                  controller.detailsAvatarStatus.value;
                              if (status.isEmpty || status == 'APPROVED') {
                                return const SizedBox.shrink();
                              }

                              var overlayColor = AppColors.bgPage54;
                              var badgeColor = const Color(0xFF3B82F6);
                              var icon = Icons.sync_rounded;
                              final isPending = status == 'PENDING';

                              if (status == 'REJECTED') {
                                overlayColor = AppColors.bgPage.withValues(
                                  alpha: 0.8,
                                );
                                badgeColor = const Color(0xFFEF4444);
                                icon = Icons.error_outline_rounded;
                              } else if (status == 'FLAGGED') {
                                overlayColor = AppColors.bgPage.withValues(
                                  alpha: 0.7,
                                );
                                badgeColor = const Color(0xFFF59E0B);
                                icon = Icons.warning_amber_rounded;
                              }

                              return Positioned.fill(
                                child: ColoredBox(
                                  color: overlayColor,
                                  child: Tooltip(
                                    message: status == 'REJECTED'
                                        ? 'Avatar Rejected: ${controller.detailsAvatarReason.value}'
                                        : (status == 'FLAGGED'
                                              ? 'Review Needed: ${controller.detailsAvatarReason.value}'
                                              : 'Avatar Verification Pending'),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: badgeColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: isPending
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(AppColors.textPrimary),
                                                ),
                                              )
                                            : Icon(
                                                icon,
                                                color: AppColors.textPrimary,
                                                size: 14,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isDesktop ? 24.0 : 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            channel.channelName,
                            style: TextStyle(
                              fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                              fontWeight: FontWeight.w700,
                              color: ytTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (channel.isVerified) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            color: ytTextSecondary,
                            size: isDesktop ? 24 : 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Obx(() {
                      final currentChannel =
                          controller.selectedChannel.value ?? channel;
                      final handle = currentChannel.handle.isNotEmpty
                          ? currentChannel.handle
                          : '@${currentChannel.channelName.toLowerCase().replaceAll(' ', '')}';
                      final count = controller.channelVideoCount.value > 0
                          ? controller.channelVideoCount.value
                          : currentChannel.videoCount;
                      return Text(
                        '$handle • ${controller.formattedSubscribers} subscribers • $count videos',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          color: ytTextSecondary,
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    _buildExpandableDescription(channel, isDesktop: isDesktop),
                    const SizedBox(height: 8),
                    if ((channel.socialLinks?.isNotEmpty ?? false) ||
                        channel.websiteUrl.isNotEmpty)
                      _buildChannelLinks(channel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSubscribeRow(
            context,
            channel,
            isDesktop: isDesktop,
            isTablet: isTablet,
          ),
        ],
      ),
    );
  }


  Widget _buildExpandableDescription(
    Channel channel, {
    bool isDesktop = false,
  }) {
    final text = channel.description.isEmpty
        ? 'No description available'
        : channel.description;
    final isLongText = text.length > 50 || text.contains('\n');

    return Container(
      constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
      child: Obx(() {
        final isExpanded = controller.isDescriptionExpanded.value;

        return InkWell(
          onTap: isLongText
              ? controller.isDescriptionExpanded.toggle
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClickableUrlText(
                text: text,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: ytTextSecondary),
              ),
              if (isLongText) ...[
                const SizedBox(height: 2),
                Text(
                  isExpanded ? '...less' : '...more',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ytTextPrimary,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }



  Widget _buildChannelLinks(Channel channel) {
    if (channel.websiteUrl.isEmpty) return const SizedBox.shrink();

    final uri = Uri.tryParse(channel.websiteUrl);
    final domain = uri?.host.replaceAll('www.', '') ?? channel.websiteUrl;

    return InkWell(
      onTap: () => ChannelDetailsStateWidgets.launchURL(channel.websiteUrl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            domain,
            style: const TextStyle(fontSize: 12, color: ytLinkBlue),
          ),
          if (channel.socialLinks?.isNotEmpty ?? false) ...[
            Text(
              ' and ${channel.socialLinks!.length} more links',
              style: const TextStyle(fontSize: 12, color: ytTextSecondary),
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildSubscribeRow(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final isSubscribed = controller.isSubscribed.value;
            final notificationsEnabled = controller.notificationsEnabled.value;
            final notificationOption = controller.notificationOption.value;
            return AnimatedSubscribeButton(
              isSubscribed: isSubscribed,
              notificationsEnabled: notificationsEnabled,
              notificationOption: notificationOption,
              onNotificationTap: () => _showNotificationsDialog(context, channel),
              onPressed: !AuthService.to.isAuthenticated.value
                  ? () => AuthService.to.signInWithGoogle()
                  : () async {
                      if (isSubscribed) {
                        _showNotificationsDialog(context, channel);
                      } else {
                        await controller.toggleSubscription(
                          channel.channelId,
                        );
                      }
                    },
            );
          }),
          const SizedBox(width: 8),
          // Join / Joined Channel Membership Button
          Obx(() {
            final isJoined = controller.isChannelMember.value;
            return Container(
              height: 36,
              decoration: BoxDecoration(
                color: isJoined ? const Color(0xFF1B382B) : ytSurfaceLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isJoined
                      ? const Color(0xFF10B981)
                      : ytTextPrimary.withValues(alpha: 0.3),
                  width: isJoined ? 1.2 : 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => ChannelMembershipJoinSheet.show(
                    context,
                    channelId: channel.channelId,
                    channel: channel,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isJoined ? 'Joined' : 'Join',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isJoined ? const Color(0xFF34D399) : ytTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: ytSurfaceLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.shareChannel(channel.channelId),
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.share, color: ytTextPrimary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ytTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showUnsubscribeConfirmation(BuildContext context, Channel channel) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: ytSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unsubscribe from ${channel.channelName}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: ytTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You will no longer see this channel's content in your feed.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: ytTextSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: ytTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        controller.toggleSubscription(channel.channelId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ytTextPrimary,
                        foregroundColor: ytBackground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Unsubscribe',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB BUILDERS
  // ==========================================================================


  void _showNotificationsDialog(BuildContext context, Channel targetChannel) {
    ChannelNotificationOptionsSheet.show(
      context: context,
      channelId: targetChannel.channelId,
      channelName: targetChannel.channelName,
      subCtrl: controller.subController,
    );
  }

}
