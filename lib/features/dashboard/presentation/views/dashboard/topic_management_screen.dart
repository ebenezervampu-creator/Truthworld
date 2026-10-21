import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/topics_widgets.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/topics_widgets.dart';

/// Redesigned Topics Tab in Studio.
///
/// Matches exact Visual Architecture, Fonts, Colors, and Theme from the Channel Creation Screen.
class TopicManagementScreen extends StatelessWidget {
  final String channelId;
  final bool isDarkMode;
  final String searchQuery;
  final RxInt _retryTrigger = 0.obs;

  TopicManagementScreen({
    required this.channelId,
    required this.isDarkMode,
    this.searchQuery = '',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<TopicManagementController>()
        ? Get.find<TopicManagementController>()
        : Get.put(TopicManagementController());

    // Register edit topic dialog handler
    controller.onEditTopicRequested = (ctx, topic) {
      final isOwner =
          Get.isRegistered<AuthService>() &&
          ((topic.channelId != null &&
                  topic.channelId!.isNotEmpty &&
                  AuthService.to.userChannel?.id == topic.channelId) ||
              (topic.creatorId != null &&
                  topic.creatorId!.isNotEmpty &&
                  AuthService.to.uid == topic.creatorId));

      if (!isOwner) {
        SnackbarService.error(
          message: 'Only the topic creator channel can edit this topic.',
        );
        return;
      }

      EditTopicDialog.show(
        context: ctx,
        topic: topic,
        channelId: topic.channelId ?? channelId,
        isDarkMode: isDarkMode,
        controller: controller,
      );
    };

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        slivers: [
          // Studio Header & Summary Metrics Bar
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                border: Border(
                  bottom: BorderSide(color: AppColors.bgDivider),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Subtitle Row (Responsive Header Layout matching Channel Wizard)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isHeaderMobile = constraints.maxWidth < 650;
                      if (isHeaderMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Topics',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: TWTypography.brandFamily,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Manage and curate your channel topic knowledge hubs.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => _showCreateTopicDialog(context, controller),
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: Colors.black,
                              ),
                              label: const Text(
                                'New Topic',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Topics',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontFamily: TWTypography.brandFamily,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Manage and curate your channel topic knowledge hubs.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateTopicDialog(context, controller),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                            label: const Text(
                              'New Topic',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Metric Summary Cards
                  TopicMetricsBar(controller: controller),

                  const SizedBox(height: 16),

                  // Studio Search Bar
                  TopicManagementSearchBar(controller: controller),
                ],
              ),
            ),
          ),

          // Main Topics Grid / States
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<List<Topic>>(
                stream: controller.fetchChannelTopics(channelId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const TopicLoadingGrid();
                  }
                  if (snapshot.hasError) {
                    ErrorHandler.log(
                      snapshot.error,
                      tag: 'TopicManagementScreen.stream',
                    );
                    return TopicErrorState(
                      error: UserFeedbackSanitizer.sanitizeMessage(
                        snapshot.error,
                        defaultActionContext:
                            'Unable to load topics. Please check your connection and try again.',
                      ),
                      onRetry: () => _retryTrigger.value++,
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const TopicEmptyState();
                  }

                  final topics = snapshot.data!;
                  // Update controller reactive list safely after the frame renders
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_haveTopicsChanged(controller.topicsList, topics)) {
                      controller.topicsList.assignAll(topics);
                    }
                  });

                  return Obx(() {
                    final query = controller.searchQuery.value.trim().toLowerCase();
                    final filterMode = controller.activeFilterMode.value;

                    var baseTopics = topics;
                    if (filterMode == 'public') {
                      baseTopics = topics
                          .where((t) =>
                              t.visibilityType == TopicVisibilityType.public &&
                              t.status.toLowerCase() == 'active')
                          .toList();
                    } else if (filterMode == 'private') {
                      baseTopics = topics
                          .where((t) => t.visibilityType == TopicVisibilityType.private)
                          .toList();
                    } else if (filterMode == 'rejected') {
                      baseTopics = topics
                          .where((t) =>
                              t.status.toLowerCase() == 'verificationrejected' ||
                              t.status.toLowerCase() == 'rejected')
                          .toList();
                    }

                    final filtered = query.isEmpty
                        ? baseTopics
                        : baseTopics.where((topic) {
                            return topic.title.toLowerCase().contains(query) ||
                                topic.handle.toLowerCase().contains(query) ||
                                topic.description.toLowerCase().contains(query) ||
                                topic.category.toLowerCase().contains(query);
                          }).toList();

                    if (filtered.isEmpty) {
                      return TopicSearchEmptyState(controller: controller);
                    }

                    return TopicGridView(
                      topics: filtered,
                      controller: controller,
                    );
                  });
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  void _showCreateTopicDialog(
    BuildContext context,
    TopicManagementController controller,
  ) {
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDarkMode,
      channelVideosFuture: controller.fetchChannelVideos(channelId),
      onCreateTopicSubmitted: (createCtrl) async {
        String? finalThumbnailUrl;
        if (createCtrl.thumbnailSource.value == 'custom' &&
            createCtrl.pickedCustomImageBytes.value != null) {
          finalThumbnailUrl = await controller.uploadTopicThumbnail(
            createCtrl.pickedCustomImageBytes.value!,
            createCtrl.pickedCustomImageName.value ?? 'custom_topic_thumb.jpg',
          );
        } else if (createCtrl.thumbnailSource.value == 'video') {
          finalThumbnailUrl = createCtrl.chosenVideoThumbnailUrl.value;
        }

        await controller.createTopic(
          channelId: channelId,
          title: createCtrl.titleController.text,
          handle: createCtrl.handleController.text,
          description: createCtrl.descriptionController.text,
          category: createCtrl.categoryController.text.isEmpty
              ? 'General'
              : createCtrl.categoryController.text,
          selectedVideoIds: createCtrl.selectedVideoIds,
          visibilityType: createCtrl.selectedVisibility.value,
          accessCode: createCtrl.selectedVisibility.value == TopicVisibilityType.private
              ? createCtrl.accessCodeController.text.trim()
              : null,
          thumbnailUrl: finalThumbnailUrl,
        );
      },
    );
  }

  bool _haveTopicsChanged(List<Topic> current, List<Topic> incoming) {
    if (current.length != incoming.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != incoming[i].id ||
          current[i].updatedAt != incoming[i].updatedAt ||
          current[i].title != incoming[i].title ||
          current[i].videoCount != incoming[i].videoCount ||
          current[i].visibilityType != incoming[i].visibilityType ||
          current[i].thumbnailUrl != incoming[i].thumbnailUrl ||
          current[i].category != incoming[i].category) {
        return true;
      }
    }
    return false;
  }
}
