import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    if (!isUserSignedIn) {
      onSignInPrompt();
      return;
    }

    final channelId = controller.video.channelId;
    final ch = controller.channelController.selectedChannel.value;

    ChannelMembershipJoinSheet.show(
      context,
      channelId: channelId,
      channel: ch,
    );
  }
}
