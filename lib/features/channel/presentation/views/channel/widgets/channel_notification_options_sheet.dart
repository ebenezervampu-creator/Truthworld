import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Unified bottom sheet displaying notification and subscription options for a channel:
/// - All (You'll get all notifications)
/// - Personalized (You'll get personalized notifications)
/// - None (Turn off all notifications)
/// - Unsubscribe (with confirmation dialog)
class ChannelNotificationOptionsSheet {
  const ChannelNotificationOptionsSheet._();

  static void show({
    required BuildContext context,
    required String channelId,
    String? channelName,
    ChannelSubscriptionController? subCtrl,
  }) {
    final effectiveCtrl = subCtrl ?? ChannelSubscriptionController.to;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Center(
                  child: Text(
                    'Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Options list
                Obx(() {
                  final option = effectiveCtrl.getNotificationOption(channelId).value;
                  final isAll = option == 'all';
                  final isPersonalized = option == 'personalized';
                  final isNone = option == 'none' ||
                      !effectiveCtrl.notificationsEnabled.value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // All
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        title: Text(
                          'All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight:
                                isAll ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(
                          "You'll get all notifications",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: isAll
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          effectiveCtrl.updateNotificationPreference(
                            channelId,
                            'all',
                          );
                        },
                      ),

                      // Personalized
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        title: Text(
                          'Personalized',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: isPersonalized
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(
                          "You'll get personalized notifications",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: isPersonalized
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          effectiveCtrl.updateNotificationPreference(
                            channelId,
                            'personalized',
                          );
                        },
                      ),

                      // None
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_off_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        title: Text(
                          'None',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight:
                                isNone ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(
                          'Turn off all notifications',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: isNone
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          effectiveCtrl.updateNotificationPreference(
                            channelId,
                            'none',
                          );
                        },
                      ),

                      const Divider(
                        color: Colors.white12,
                        height: 16,
                        thickness: 1,
                      ),

                      // Unsubscribe
                      ListTile(
                        leading: const Icon(
                          Icons.person_remove_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        title: Text(
                          'Unsubscribe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _showUnsubscribeConfirmation(
                            context,
                            channelId,
                            channelName,
                            effectiveCtrl,
                          );
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showUnsubscribeConfirmation(
    BuildContext context,
    String channelId,
    String? channelName,
    ChannelSubscriptionController subCtrl,
  ) {
    final displayName = (channelName != null && channelName.trim().isNotEmpty)
        ? channelName.trim()
        : 'this channel';

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unsubscribe from $displayName?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You will no longer see this channel's content in your subscription feed.",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      subCtrl.unsubscribeFromChannel(channelId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Unsubscribe',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
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
}
