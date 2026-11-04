import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Options Menu Bottom Sheet for Community Post
void showCommunityPostOptionsMenu(
  BuildContext context,
  CommunityPostModel post,
  CommunityPostController controller, {
  bool isChannelContext = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final currentUid = controller.currentUid;
      final isOwner = currentUid != null &&
          (currentUid == post.ownerId || currentUid == post.channelId);

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Obx(
              () => ListTile(
                leading: Icon(
                  controller.isSaved.value
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: Colors.white, // Rule compliance: white icon
                ),
                title: Text(
                  controller.isSaved.value ? 'Unsave post' : 'Save post',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.toggleBookmark();
                },
              ),
            ),
            if (!isOwner && !isChannelContext) ...[
              ListTile(
                leading: const Icon(
                  Icons.block_outlined,
                  color: Colors.white, // Rule compliance: white icon
                ),
                title: const Text(
                  'Not interested',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  "We won't recommend this post in your feed",
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.hidePost();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.notifications_off_outlined,
                  color: Colors.white, // Rule compliance: white icon
                ),
                title: const Text(
                  "Don't recommend posts from this channel",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: Text(
                  "We won't recommend posts from ${post.channelName}",
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.turnOffChannelPosts();
                },
              ),
            ],
            if (!isOwner && isChannelContext) ...[
              Obx(() {
                if (controller.isPostHiddenInFeed.value) {
                  return ListTile(
                    leading: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white, // Rule compliance: white icon
                    ),
                    title: const Text(
                      'Restore post recommendation',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Unhide this post in your feed recommendations',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      controller.unhidePost();
                    },
                  );
                }
                return const SizedBox.shrink();
              }),
              Obx(() {
                if (controller.isChannelMutedInFeed.value) {
                  return ListTile(
                    leading: const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.white, // Rule compliance: white icon
                    ),
                    title: const Text(
                      'Turn on community posts from this channel',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Allow posts from ${post.channelName} in your feed',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      controller.unmuteChannelPosts();
                    },
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
            if (!isOwner && post.channelId.isNotEmpty)
              Builder(
                builder: (context) {
                  final isSubscribedRx =
                      Get.isRegistered<ChannelSubscriptionController>()
                          ? ChannelSubscriptionController.to
                              .isSubscribedTo(post.channelId)
                          : false.obs;

                  return Obx(() {
                    final isSub = isSubscribedRx.value;
                    return ListTile(
                      leading: Icon(
                        isSub
                            ? Icons.person_remove_outlined
                            : Icons.person_add_alt_1_outlined,
                        color: Colors.white, // Rule compliance: white icon
                      ),
                      title: Text(
                        isSub ? 'Unsubscribe' : 'Subscribe to channel',
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      subtitle: Text(
                        isSub
                            ? 'Unsubscribe from ${post.channelName}'
                            : 'Get updates from ${post.channelName}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        if (!AuthService.to.isAuthenticated.value) {
                          AppSnackbar.warning(
                            'Please sign in to manage subscriptions.',
                            actionLabel: 'SIGN IN',
                            onAction: () =>
                                AuthService.to.triggerPlatformSignIn(),
                          );
                          return;
                        }
                        if (isSub) {
                          await controller.unsubscribeChannel();
                        } else {
                          final subCtrl =
                              Get.isRegistered<ChannelSubscriptionController>()
                                  ? ChannelSubscriptionController.to
                                  : Get.put(ChannelSubscriptionController());
                          await subCtrl.subscribeToChannel(post.channelId);
                        }
                      },
                    );
                  });
                },
              ),
            if (isOwner) ...[
              ListTile(
                leading: const Icon(
                  Icons.thumbs_up_down_outlined,
                  color: Colors.white, // Rule compliance: white icon
                ),
                title: const Text(
                  'Like & Dislike Count Settings',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showCommunityPostReactionsSettingsModal(
                    context,
                    post,
                    controller,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white, // Rule compliance: white icon
                ),
                title: const Text(
                  'Move to Trash',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmMovePostToTrash(context, post, controller);
                },
              ),
            ],
            if (!isOwner)
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Colors.white, // Rule compliance: white icon
                ),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showCommunityPostReportModal(context, post, controller);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
        ),
      );
    },
  );
}

/// Modal for adjusting like and dislike count visibility
void showCommunityPostReactionsSettingsModal(
  BuildContext context,
  CommunityPostModel post,
  CommunityPostController controller,
) {
  final showLike = controller.showLikeCount.value.obs;
  final showDislike = controller.showDislikeCount.value.obs;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.thumbs_up_down_outlined,
                      color: Colors.white, // Rule compliance: white icon
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Like & Dislike Counts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  title: const Text(
                    'Show Like Count',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Show like count to users',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: showLike.value,
                  onChanged: (v) => showLike.value = v,
                  activeTrackColor: Colors.white,
                ),
                SwitchListTile.adaptive(
                  title: const Text(
                    'Show Dislike Count',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Show dislike count to users',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: showDislike.value,
                  onChanged: (v) => showDislike.value = v,
                  activeTrackColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        controller.updateCountSettings(
                          showLike.value,
                          showDislike.value,
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 2-Step Reporting Modal for Community Post
void showCommunityPostReportModal(
  BuildContext context,
  CommunityPostModel post,
  CommunityPostController controller,
) {
  if (controller.currentUid == null || !AuthService.to.isAuthenticated.value) {
    AppSnackbar.warning(
      'Please sign in to report posts.',
      actionLabel: 'SIGN IN',
      onAction: () => AuthService.to.triggerPlatformSignIn(),
    );
    return;
  }

  final reasons = [
    {
      'label': 'Sexual content',
      'description': 'Nudity, sexually explicit content, or pornography',
    },
    {
      'label': 'Violent or repulsive content',
      'description': 'Fight clips, self-harm, gore, or animal abuse',
    },
    {
      'label': 'Hateful or abusive content',
      'description': 'Promoting violence or hatred against protected groups',
    },
    {
      'label': 'Harassment or bullying',
      'description': 'Cyberbullying or personal abuse',
    },
    {
      'label': 'Harmful or dangerous acts',
      'description': 'Dangerous challenges, stunts, or drug promotion',
    },
    {
      'label': 'Child abuse',
      'description': 'Endangerment, exploitation, or sexualization of minors',
    },
    {
      'label': 'Spam or misleading',
      'description': 'Scams, clickbait, or deceptive metadata',
    },
    {
      'label': 'Infringement of my rights',
      'description': 'Copyright violation or privacy invasion',
    },
  ];

  final selectedReason = RxnString();
  final currentStep = 1.obs;
  final detailsController = TextEditingController();

  Get.bottomSheet<dynamic>(
    Obx(() {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                if (currentStep.value == 2)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white, // Rule compliance: white icon
                    ),
                    onPressed: () => currentStep.value = 1,
                  ),
                Expanded(
                  child: Text(
                    currentStep.value == 1
                        ? 'Report Post'
                        : 'Provide Additional Details',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white, // Rule compliance: white icon
                  ),
                  onPressed: Get.back,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentStep.value == 1) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reasons.length,
                  itemBuilder: (context, index) {
                    final reason = reasons[index];
                    final label = reason['label']!;
                    final description = reason['description']!;
                    return Obx(
                      () => RadioListTile<String>(
                        title: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        value: label,
                        groupValue: selectedReason.value,
                        activeColor: Colors.white,
                        onChanged: (val) => selectedReason.value = val,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedReason.value == null
                    ? null
                    : () => currentStep.value = 2,
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              Text(
                'Selected issue: ${selectedReason.value}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 4,
                maxLength: 500,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(500),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Explain why you are reporting this post (optional)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final details = detailsController.text.trim();
                  if (details.isNotEmpty) {
                    final detailsVal = ContentValidator.validate(
                      details,
                      fieldName: 'Report details',
                      maxLength: 500,
                    );
                    if (!detailsVal.isValid) {
                      AppSnackbar.warning(detailsVal.message);
                      return;
                    }
                  }
                  Get.back();
                  controller.submitReport(
                    selectedReason.value!,
                    details,
                  );
                },
                child: const Text(
                  'Submit Report',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      );
    }),
    isScrollControlled: true,
  );
}

void _confirmMovePostToTrash(
  BuildContext context,
  CommunityPostModel post,
  CommunityPostController controller,
) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        title: const Text(
          'Move to Trash?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: TWTypography.brandFamily,
          ),
        ),
        content: const Text(
          'Are you sure you want to move this post to Trash? Deleted items are retained for 30 days before permanent deletion.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontFamily: TWTypography.uiFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.moveToTrash();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Move to Trash'),
          ),
        ],
      );
    },
  );
}
