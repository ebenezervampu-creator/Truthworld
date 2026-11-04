import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
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
  static final Set<String> _pendingChannelIds = <String>{};

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
      return Material(
        color: isSubscribed
            ? colors.textPrimary.withValues(alpha: 0.1)
            : colors.brand,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () async {
            if (_pendingChannelIds.contains(channelId)) return;

            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              AppSnackbar.warning(
                'Please sign in to subscribe to channels.',
              );
              return;
            }

            _pendingChannelIds.add(channelId);
            try {
              if (isSubscribed) {
                await controller.unsubscribeFromChannel(channelId);
              } else {
                await controller.subscribeToChannel(channelId);
              }
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'SubscribeButton.onTap',
              );
            } finally {
              _pendingChannelIds.remove(channelId);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: isSubscribed
                  ? Border.all(
                      color: colors.textPrimary.withValues(alpha: 0.2),
                      width: 0.8,
                    )
                  : null,
            ),
            child: Text(
              isSubscribed ? 'Subscribed' : 'Subscribe',
              style: typography.label.copyWith(
                color: isSubscribed ? colors.textPrimary : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    });
  }
}
