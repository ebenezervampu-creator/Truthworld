import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Modal bottom sheet launcher for channel membership tiers and perks.
/// Delegates directly to the unified, production-grade ChannelMembershipJoinSheet.
class VideoChannelMembershipModal {
  static final RxBool rxAutoPay = true.obs;

  static void show({
    required BuildContext context,
    required VideoController controller,
    required bool isUserSignedIn,
    required VoidCallback onSignInPrompt,
  }) {
    if (!AuthService.to.isAuthenticated.value) {
      onSignInPrompt();
      return;
    }

    final channelId = controller.video.channelId.isNotEmpty
        ? controller.video.channelId
        : controller.video.ownerId;
    final ch = ChannelMemoryCache.get(channelId) ?? controller.channelController.selectedChannel.value;
    final isMonetized = ch != null ? ch.isMonetizationActive : controller.video.isMonetized;

    if (!isMonetized) {
      AppSnackbar.info('Channel memberships are only available for monetized channels.');
      return;
    }

    ChannelMembershipJoinSheet.show(
      context,
      channelId: channelId,
      channel: ch,
    );
  }
}
