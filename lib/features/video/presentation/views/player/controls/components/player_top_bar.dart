import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_badges.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_buttons.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_notifications_dialog.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    var title = '';
    VideoController? vc;
    ChannelSubscriptionController? subCtrl;
    try {
      if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
        vc = Get.find<VideoController>(tag: ctrl.tag);
        title = vc.video.title;
        if (Get.isRegistered<ChannelSubscriptionController>(tag: ctrl.tag)) {
          subCtrl = Get.find<ChannelSubscriptionController>(tag: ctrl.tag);
        } else if (Get.isRegistered<ChannelSubscriptionController>()) {
          subCtrl = Get.find<ChannelSubscriptionController>();
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'PlayerControls.findControllers',
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgPage.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Back / minimize fullscreen
          IconBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            size: 30,
            onTap: ctrl.toggleFullscreen,
          ),
          const SizedBox(width: 8),
          NetworkBadge(ctrl: ctrl),
          const SizedBox(width: 12),
          // Video title
          Expanded(
            child: Text(
              title,
              style: TS.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ctrl.isFullScreen.value &&
              vc != null &&
              subCtrl != null &&
              MediaQuery.of(context).size.width > 600) ...[
            const SizedBox(width: 20),
            // Avatar
            ClipOval(
              child: vc.video.channelAvatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: vc.video.channelAvatarUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 32,
                      height: 32,
                      color: AppColors.textSecondary,
                      child: const Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Channel Name & Subs
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vc.video.channelName,
                  style: TS.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Obx(
                  () => Text(
                    '${FormatUtils.formatCount(subCtrl!.subscriberCount.value)} subscribers',
                    style: TS.bodySm.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Subscribe Button & Bell Icon
            Obx(() {
              final isSubbed = subCtrl!.isSubscribed.value;
              final notificationsEnabled =
                  subCtrl.notificationsEnabled.value;
              final notificationOption = subCtrl.notificationOption.value;

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
                  InkWell(
                    onTap: () {
                      if (!AuthService.to.isAuthenticated.value) {
                        AppSnackbar.info(
                          'Please sign in to subscribe to channels.',
                          title: 'Sign In Required',
                          actionLabel: 'SIGN IN',
                          onAction: AuthService.to.signInWithGoogle,
                        );
                        return;
                      }
                      subCtrl!.toggleSubscription(vc!.video.channelId);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSubbed
                            ? AppColors.textPrimary.withValues(alpha: 0.1)
                            : AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isSubbed ? 'Subscribed' : 'Subscribe',
                        style: TS.bold.copyWith(
                          color: isSubbed
                              ? AppColors.textPrimary
                              : AppColors.bgPage,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (isSubbed) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => PlayerNotificationsDialog.show(
                        context,
                        subCtrl!,
                        vc!.video.channelId,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          bellIcon,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
