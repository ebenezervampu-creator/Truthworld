import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_buttons.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_notifications_dialog.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/fullscreen_actions_bar.dart';
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
        subCtrl = vc.channelController.subController;
      } else if (Get.isRegistered<ChannelSubscriptionController>(tag: ctrl.tag)) {
        subCtrl = Get.find<ChannelSubscriptionController>(tag: ctrl.tag);
      } else if (Get.isRegistered<ChannelSubscriptionController>()) {
        subCtrl = Get.find<ChannelSubscriptionController>();
      } else {
        subCtrl = ChannelSubscriptionController.to;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'PlayerControls.findControllers',
      );
    }

    final isWide = MediaQuery.of(context).size.width > 540;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back / minimize fullscreen
          IconBtn(
            icon: Icons.arrow_back_rounded,
            size: 22,
            onTap: ctrl.toggleFullscreen,
          ),
          const SizedBox(width: 8),

          // Video title & Truth Credibility Badge
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final showFullBadge = maxWidth >= 260;
                final showCompactBadge = maxWidth >= 150 && !showFullBadge;
                final showBadge = (showFullBadge || showCompactBadge) && vc != null;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TS.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (vc != null && vc.video.channelName.isNotEmpty)
                            Text(
                              vc.video.channelName,
                              style: TS.bodySm.copyWith(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // TruthWorld Credibility / Fact-Check badge
                    if (showBadge)
                      _buildCredibilityBadge(
                        context,
                        ctrl,
                        vc,
                        compact: showCompactBadge,
                      ),
                  ],
                );
              },
            ),
          ),

          // Right cluster: Channel Subscribe + Action Dock
          if (ctrl.isFullScreen.value && vc != null) ...[
            if (isWide && subCtrl != null) ...[
              const SizedBox(width: 14),
              // Channel Avatar
              ClipOval(
                child: vc.video.channelAvatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: vc.video.channelAvatarUrl,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 28,
                        height: 28,
                        color: AppColors.textSecondary,
                        child: const Icon(
                          Icons.person,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // Subscribe Button & Notification Bell
              _buildSubscribeButton(context, vc, subCtrl),
            ],
            const SizedBox(width: 10),
            // Floating Action Dock (Like, Comments, Share, More ⋯)
            FullscreenFloatingActionDock(ctrl: ctrl, vc: vc),
          ],
        ],
      ),
    );
  }

  Widget _buildCredibilityBadge(
    BuildContext context,
    TowerPlayerController ctrl,
    VideoController vc, {
    bool compact = false,
  }) {
    final video = vc.video;
    final currentUid = AuthService.to.uid;
    final userChannelId = AuthService.to.userChannel?.id;
    final isOwner = currentUid.isNotEmpty &&
        (video.ownerId == currentUid ||
            video.userId == currentUid ||
            (userChannelId != null &&
                userChannelId.isNotEmpty &&
                video.channelId == userChannelId));
    final canView = video.canPublicViewFactCheck || isOwner;
    if (!canView) return const SizedBox.shrink();

    final isFactChecked = video.hasAiCredibility ||
        vc.factCheckData.isNotEmpty ||
        (video.uiReport != null && video.uiReport!.keyClaims.isNotEmpty);

    if (!isFactChecked && !ctrl.isAnalyzingTruth) return const SizedBox.shrink();

    final score = ctrl.truthReportScore;
    final isHigh = score != null && score >= 75;
    final badgeColor = isHigh ? AppColors.success : AppColors.brand;
    final badgeText = compact
        ? (ctrl.isAnalyzingTruth
            ? '…'
            : (score != null ? '$score%' : '✓'))
        : ctrl.truthReportBadgeText;

    return Padding(
      padding: EdgeInsets.only(left: compact ? 6 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ctrl.overlayManager.toggle(TowerPlayerOverlay.factCheck);
            ctrl.showFactCheckPopup.value = ctrl.overlayManager.isFactCheckOpen;
            ctrl.showCommentsPopup.value = false;
            ctrl.showTranscriptPopup.value = false;
            ctrl.showLiveChat.value = false;
            ctrl.startHideTimer();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: 3.5,
            ),
            decoration: BoxDecoration(
              color: const Color(0x730F0F12), // rgba(15,15,18,0.45)
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 12,
                  color: badgeColor,
                ),
                SizedBox(width: compact ? 3 : 4),
                Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(
    BuildContext context,
    VideoController vc,
    ChannelSubscriptionController subCtrl,
  ) {
    return Obx(() {
      final isSubbed = subCtrl.isSubscribedTo(vc.video.channelId).value;
      final notificationsEnabled = subCtrl.notificationsEnabled.value;
      final notificationOption =
          subCtrl.getNotificationOption(vc.video.channelId).value;

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
          // Subscribe / Subscribed Pill Button
          InkWell(
            onTap: () {
              ctrl.startHideTimer();
              if (!AuthService.to.isAuthenticated.value) {
                AppSnackbar.info(
                  'Please sign in to subscribe to channels.',
                  title: 'Sign In Required',
                  actionLabel: 'SIGN IN',
                  onAction: () => AuthBottomSheet.show(context),
                );
                return;
              }
              if (isSubbed) {
                PlayerNotificationsDialog.show(
                  context,
                  subCtrl,
                  vc.video.channelId,
                  channelName: vc.video.channelName,
                );
              } else {
                subCtrl.subscribeToChannel(vc.video.channelId);
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSubbed
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSubbed
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSubbed ? 'Subscribed' : 'Subscribe',
                    style: TS.bold.copyWith(
                      color: isSubbed ? Colors.white : Colors.black,
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
            const SizedBox(width: 6),
            // Notification Bell Options Toggle Pill
            InkWell(
              onTap: () {
                ctrl.startHideTimer();
                PlayerNotificationsDialog.show(
                  context,
                  subCtrl,
                  vc.video.channelId,
                  channelName: vc.video.channelName,
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  bellIcon,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}
