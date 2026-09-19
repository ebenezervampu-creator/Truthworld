import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Realtime Subscribe Button connected to ChannelSubscriptionController.
class SubscribeButton extends StatelessWidget {
  const SubscribeButton({
    required this.channelId,
    required this.channelName,
    super.key,
  });

  final String channelId;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ChannelSubscriptionController>()
        ? Get.find<ChannelSubscriptionController>()
        : Get.put(ChannelSubscriptionController());
    final colors = context.twColors;
    final typography = context.twTypography;

    final isSubscribedRx = controller.isSubscribedTo(channelId);

    return Obx(() {
      final isSubscribed = isSubscribedRx.value;
      return InkWell(
        onTap: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            AppSnackbar.warning(
              'Please sign in to subscribe to channels.',
              title: 'Sign In Required',
            );
            return;
          }

          if (isSubscribed) {
            await controller.unsubscribeFromChannel(channelId);
          } else {
            await controller.subscribeToChannel(channelId);
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSubscribed
                ? colors.textPrimary.withValues(alpha: 0.1)
                : colors.textPrimary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            isSubscribed ? 'Subscribed' : 'Subscribe',
            style: typography.label.copyWith(
              color: isSubscribed ? colors.textSecondary : colors.background,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }
}
