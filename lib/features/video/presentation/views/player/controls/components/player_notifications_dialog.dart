import 'package:flutter/material.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_notification_options_sheet.dart';

class PlayerNotificationsDialog {
  const PlayerNotificationsDialog._();

  static void show(
    BuildContext context,
    ChannelSubscriptionController subCtrl,
    String channelId, {
    String? channelName,
  }) {
    ChannelNotificationOptionsSheet.show(
      context: context,
      channelId: channelId,
      channelName: channelName,
      subCtrl: subCtrl,
    );
  }
}
