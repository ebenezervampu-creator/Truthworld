import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// YouTube-style modal bottom sheet for topic notifications and unfollow options.
/// Displays options:
/// 1. "All" - You'll get all notifications
/// 2. "Personalized" - You'll get personalized notifications
/// 3. "None" - Turn off all notifications
/// 4. "Unfollow" - Unfollow the topic with confirmation dialog
class TopicNotificationOptionsSheet extends StatelessWidget {
  const TopicNotificationOptionsSheet({
    required this.topic,
    required this.controller,
    super.key,
  });

  final Topic topic;
  final FollowingTopicsController controller;

  /// Display the topic notification & options sheet
  static Future<void> show(
    BuildContext context, {
    required Topic topic,
  }) async {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    // Preload notification setting if not yet loaded in controller map
    followingController.fetchTopicNotificationSetting(topic.id);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => TopicNotificationOptionsSheet(
        topic: topic,
        controller: followingController,
      ),
    );
  }

  /// Show confirmation dialog before unfollowing a topic
  static void showUnfollowConfirmation(
    BuildContext context, {
    required Topic topic,
    required FollowingTopicsController controller,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unfollow ${topic.title}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'You will no longer receive notifications or updates for this topic.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        controller.unfollowTopic(topic);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Unfollow',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            const Text(
              'Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Options List with reactive selection state
            Obx(() {
              final option =
                  controller.topicNotificationSettings[topic.id] ?? 'personalized';
              final isAll = option == 'all';
              final isPersonalized = option == 'personalized';
              final isNone = option == 'none';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Option 1: All notifications
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      'All',
                      style: TextStyle(
                        color: isAll ? AppColors.brand : AppColors.textPrimary,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get all notifications",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isAll
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateTopicNotificationSetting(
                        topic.id,
                        'all',
                      );
                    },
                  ),

                  // Option 2: Personalized notifications
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      'Personalized',
                      style: TextStyle(
                        color: isPersonalized
                            ? AppColors.brand
                            : AppColors.textPrimary,
                        fontWeight:
                            isPersonalized ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get personalized notifications",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isPersonalized
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateTopicNotificationSetting(
                        topic.id,
                        'personalized',
                      );
                    },
                  ),

                  // Option 3: Turn off all notifications
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_off_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      'None',
                      style: TextStyle(
                        color: isNone ? AppColors.brand : AppColors.textPrimary,
                        fontWeight:
                            isNone ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      'Turn off all notifications',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isNone
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateTopicNotificationSetting(
                        topic.id,
                        'none',
                      );
                    },
                  ),

                  const Divider(color: AppColors.bgDivider),

                  // Option 4: Unfollow
                  ListTile(
                    leading: const Icon(
                      Icons.person_remove_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Unfollow',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showUnfollowConfirmation(
                        context,
                        topic: topic,
                        controller: controller,
                      );
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
