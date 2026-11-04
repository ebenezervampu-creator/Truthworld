import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet presenting user options for a Topic:
/// 1. Save Topic / Bookmark
/// 2. Notifications (All, Personalized, None, Unfollow)
/// 3. Don't recommend this topic
/// 4. Not interested
/// 5. Copy link
/// 6. Share
/// 7. Report topic
class TopicMoreOptionsBottomSheet extends StatelessWidget {
  const TopicMoreOptionsBottomSheet({
    required this.topic,
    super.key,
  });

  final Topic topic;

  static Future<void> show(BuildContext context, {required Topic topic}) async {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TopicMoreOptionsBottomSheet(topic: topic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    final isFollowed = followingController.isTopicFollowed(topic.id);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 1. Save Topic
                _buildMenuItem(
                  context,
                  icon: const Icon(
                    Icons.bookmark_outline_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: 'Save topic',
                  onTap: () {
                    Navigator.pop(context);
                    _handleSaveTopic(context);
                  },
                ),

                // 2. Topic Notifications (If followed or accessible)
                _buildMenuItem(
                  context,
                  icon: Icon(
                    isFollowed
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: 'Notifications',
                  onTap: () {
                    Navigator.pop(context);
                    TopicNotificationOptionsSheet.show(context, topic: topic);
                  },
                ),

                // 3. Don't recommend this topic
                _buildMenuItem(
                  context,
                  icon: const Icon(
                    Icons.do_not_disturb_on_outlined,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: "Don't recommend this topic",
                  onTap: () {
                    Navigator.pop(context);
                    _handleDontRecommendTopic(context);
                  },
                ),

                // 4. Not interested
                _buildMenuItem(
                  context,
                  icon: const Icon(
                    Icons.thumb_down_alt_outlined,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: 'Not interested',
                  onTap: () {
                    Navigator.pop(context);
                    _handleNotInterested(context);
                  },
                ),

                // 5. Copy Link
                _buildMenuItem(
                  context,
                  icon: const Icon(
                    Icons.link_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: 'Copy topic link',
                  onTap: () {
                    Navigator.pop(context);
                    final url = DeepLinkService.topicUrl(topic.slug);
                    Clipboard.setData(ClipboardData(text: url));
                    AppSnackbar.show(
                      'Link copied',
                      'Topic link copied to clipboard.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),

                // 6. Share
                _buildMenuItem(
                  context,
                  icon: const Icon(
                    Icons.reply_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: 'Share',
                  onTap: () {
                    Navigator.pop(context);
                    final url = DeepLinkService.topicUrl(topic.slug);
                    final followingCtrl = Get.isRegistered<FollowingTopicsController>()
                        ? Get.find<FollowingTopicsController>()
                        : Get.put(FollowingTopicsController());
                    final count = followingCtrl.getFollowerCount(topic);
                    ShareBottomSheet.show(
                      title: topic.name,
                      url: url,
                      thumbnailUrl: topic.coverImage ?? topic.thumbnailUrl,
                      followerCount: count,
                      videoCount: topic.effectiveVideoCount,
                      handle: topic.slug,
                      type: 'topic',
                    );
                  },
                ),

                // 7. Report Topic
                _buildMenuItem(
                  context,
                  icon: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: 'Report topic',
                  onTap: () {
                    Navigator.pop(context);
                    _showReportTopicDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required Widget icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        splashColor: AppColors.brand.withValues(alpha: 0.15),
        highlightColor: AppColors.brand.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSaveTopic(BuildContext context) {
    AppSnackbar.show(
      'Saved',
      'Topic saved to your library.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurfaceHover,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(20),
      borderRadius: 16,
    );
  }

  void _handleDontRecommendTopic(BuildContext context) {
    UserPreferencesService.to.hideTopic(
      topic.id,
      topicSlug: topic.slug,
      topicName: topic.name,
      canonicalKey: topic.canonicalKey,
    );
    _removeTopicFromFeeds();
    AppSnackbar.show(
      "Don't recommend topic",
      "We won't recommend \"${topic.name}\" anymore.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurfaceHover,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(20),
      borderRadius: 16,
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) Get.back();
          UserPreferencesService.to.unhideTopic(
            topic.id,
            topicSlug: topic.slug,
            topicName: topic.name,
            canonicalKey: topic.canonicalKey,
          );
          if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().discovery.fetchFeaturedTopics();
          } else if (Get.isRegistered<HomeDiscoveryController>()) {
            Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
          }
          AppSnackbar.show(
            'Restored',
            'Topic recommendations restored.',
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        child: const Text(
          'Undo',
          style: TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _handleNotInterested(BuildContext context) {
    UserPreferencesService.to.hideTopic(
      topic.id,
      topicSlug: topic.slug,
      topicName: topic.name,
      canonicalKey: topic.canonicalKey,
    );
    _removeTopicFromFeeds();
    AppSnackbar.show(
      'Not interested',
      'Topic marked as not interested.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurfaceHover,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(20),
      borderRadius: 16,
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) Get.back();
          UserPreferencesService.to.unhideTopic(
            topic.id,
            topicSlug: topic.slug,
            topicName: topic.name,
            canonicalKey: topic.canonicalKey,
          );
          if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().discovery.fetchFeaturedTopics();
          } else if (Get.isRegistered<HomeDiscoveryController>()) {
            Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
          }
          AppSnackbar.show(
            'Restored',
            'Topic restored.',
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        child: const Text(
          'Undo',
          style: TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _removeTopicFromFeeds() {
    final userPrefs = Get.isRegistered<UserPreferencesService>()
        ? UserPreferencesService.to
        : null;

    bool matchesTopic(Topic t) {
      if (t.id == topic.id) return true;
      if (topic.slug.isNotEmpty && t.slug == topic.slug) return true;
      if (topic.canonicalKey.isNotEmpty && t.canonicalKey == topic.canonicalKey) return true;
      if (topic.name.isNotEmpty && t.name.toLowerCase() == topic.name.toLowerCase()) return true;
      if (userPrefs != null && userPrefs.isTopicBlocked(t)) return true;
      return false;
    }

    if (Get.isRegistered<HomeController>()) {
      final hc = Get.find<HomeController>();
      hc.featuredTopics.removeWhere(matchesTopic);
      hc.discovery.saveFeaturedTopicsToCache();
    } else if (Get.isRegistered<HomeDiscoveryController>()) {
      final dc = Get.find<HomeDiscoveryController>();
      dc.featuredTopics.removeWhere(matchesTopic);
      dc.saveFeaturedTopicsToCache();
    }

    if (Get.isRegistered<ExploreTopicsController>()) {
      final etc = Get.find<ExploreTopicsController>();
      etc.featuredTopics.removeWhere(matchesTopic);
      etc.topics.removeWhere(matchesTopic);
    }

    if (Get.isRegistered<FollowingTopicsController>()) {
      final ftc = Get.find<FollowingTopicsController>();
      ftc.followedTopics.removeWhere(matchesTopic);
      ftc.favoriteTopics.removeWhere(matchesTopic);
    }
  }

  void _showReportTopicDialog(BuildContext context) {
    final selectedReason = Rxn<String>();
    final isSubmitting = false.obs;

    final reasons = [
      'Misleading or false information',
      'Spam or advertising',
      'Inappropriate or offensive content',
      'Copyright or IP violation',
      'Harassment or hate speech',
      'Other issue',
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Report Topic',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why are you reporting "${topic.name}"?',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ...reasons.map((reason) {
                      final isSelected = selectedReason.value == reason;
                      return RadioListTile<String>(
                        value: reason,
                        groupValue: selectedReason.value,
                        onChanged: (val) => selectedReason.value = val,
                        title: Text(
                          reason,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        activeColor: Colors.white,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: (selectedReason.value == null || isSubmitting.value)
                    ? null
                    : () async {
                        isSubmitting.value = true;
                        final reason = selectedReason.value!;
                        Navigator.of(dialogContext).pop();

                        try {
                          final currentUid = Get.isRegistered<AuthService>()
                              ? AuthService.to.uid
                              : '';
                          await FirebaseFirestore.instance
                              .collection(FirestoreCollections.reports)
                              .add({
                            'topicId': topic.id,
                            'topicSlug': topic.slug,
                            'topicName': topic.name,
                            'topicTitle': topic.name,
                            'reason': reason,
                            'reporterId': currentUid,
                            'reportedAt': FieldValue.serverTimestamp(),
                            'status': 'pending',
                            'type': 'topic',
                          });
                          await UserPreferencesService.to.hideTopic(
                            topic.id,
                            topicSlug: topic.slug,
                            topicName: topic.name,
                            canonicalKey: topic.canonicalKey,
                          );
                          _removeTopicFromFeeds();
                          AppSnackbar.success(
                            'Thank you for reporting. This topic has been hidden and our team will review it.',
                          );
                        } catch (e, s) {
                          ErrorHandler.log(e, stackTrace: s, tag: 'ReportTopic');
                          await UserPreferencesService.to.hideTopic(
                            topic.id,
                            topicSlug: topic.slug,
                            topicName: topic.name,
                            canonicalKey: topic.canonicalKey,
                          );
                          _removeTopicFromFeeds();
                          AppSnackbar.success(
                            'Thank you for reporting. This topic has been hidden and our team will review it.',
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  'Report',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}
