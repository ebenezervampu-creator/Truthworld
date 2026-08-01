import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_popup_menu.dart';
import 'package:truthworld/theme/app_theme.dart';

class TopicManagementScreen extends StatelessWidget {
  TopicManagementScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
    this.searchQuery = '',
  });
  final String channelId;
  final bool isDarkMode;
  final String searchQuery;
  final RxInt _retryTrigger = 0.obs;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TopicManagementController>()) {
      Get.find<TopicManagementController>();
    }
    final controller = Get.find<TopicManagementController>();

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

      Get.dialog<void>(
        EditTopicDialog(
          topic: topic,
          channelId: topic.channelId ?? channelId,
          isDarkMode: isDarkMode,
          controller: controller,
        ),
      );
    };

    final isDark =
        Theme.of(context).brightness == Brightness.dark || isDarkMode;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF9FAFB);
    final cardBgColor = isDark
        ? const Color(0xFF161B22)
        : AppColors.textPrimary;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE5E7EB);
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF111827);
    final subtextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTopicDialog(context, controller),
        icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary),
        label: const Text(
          'Create Topic',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 4,
      ),
      body: CustomScrollView(
        slivers: [
          // YouTube Studio Header & Summary Metrics Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Subtitle Row (Responsive Header Layout)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isHeaderMobile = constraints.maxWidth < 600;
                      if (isHeaderMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Topics',
                              style: AppTextStyles.pageTitle.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage and curate your channel topic knowledge hubs',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                color: subtextColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showCreateTopicDialog(context, controller),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  'New Topic',
                                  style: AppTextStyles.buttonText.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: AppColors.textPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Topics',
                                  style: AppTextStyles.pageTitle.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage and curate your channel topic knowledge hubs',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 13,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showCreateTopicDialog(context, controller),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'New Topic',
                              style: AppTextStyles.buttonText.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // YouTube Studio Metric Summary Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return Obx(() {
                        return GridView.count(
                          crossAxisCount: isMobile ? 2 : 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          childAspectRatio: isMobile ? 2.2 : 2.4,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMetricSummaryCard(
                              context,
                              title: 'Total Topics',
                              value: '${controller.totalTopicsCount}',
                              icon: Icons.topic_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              isDark: isDark,
                              borderColor: borderColor,
                              cardBg: cardBgColor,
                            ),
                            _buildMetricSummaryCard(
                              context,
                              title: 'Linked Videos',
                              value: '${controller.totalVideosCount}',
                              icon: Icons.video_library_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              isDark: isDark,
                              borderColor: borderColor,
                              cardBg: cardBgColor,
                            ),
                            _buildMetricSummaryCard(
                              context,
                              title: 'Public Topics',
                              value: '${controller.publicTopicsCount}',
                              icon: Icons.public_rounded,
                              iconColor: const Color(0xFF10B981),
                              isDark: isDark,
                              borderColor: borderColor,
                              cardBg: cardBgColor,
                            ),
                            _buildMetricSummaryCard(
                              context,
                              title: 'Private Topics',
                              value: '${controller.privateTopicsCount}',
                              icon: Icons.lock_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              isDark: isDark,
                              borderColor: borderColor,
                              cardBg: cardBgColor,
                            ),
                          ],
                        );
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Studio Search Bar
                  _buildStudioSearchBar(
                    context,
                    controller,
                    isDark,
                    textColor,
                    subtextColor,
                    borderColor,
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Main Topics Grid / States
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<List<Topic>>(
                stream: controller.fetchChannelTopics(channelId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerGrid(context);
                  }
                  if (snapshot.hasError) {
                    return _buildGlassmorphicError(snapshot.error.toString());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(context, controller);
                  }

                  final topics = snapshot.data!;
                  // Update controller reactive list safely after the frame renders
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (controller.topicsList.length != topics.length) {
                      controller.topicsList.assignAll(topics);
                    }
                  });

                  return Obx(() {
                    final query = controller.searchQuery.value
                        .trim()
                        .toLowerCase();
                    final filtered = query.isEmpty
                        ? topics
                        : topics.where((topic) {
                            return topic.title.toLowerCase().contains(query) ||
                                topic.handle.toLowerCase().contains(query) ||
                                topic.description.toLowerCase().contains(
                                  query,
                                ) ||
                                topic.category.toLowerCase().contains(query);
                          }).toList();

                    if (filtered.isEmpty) {
                      return _buildSearchEmptyState(context, controller);
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.25,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final topic = filtered[index];
                        return TopicCardWidget(
                          topic: topic,
                          isDashboard: true,
                          showEditOption: false,
                          trailing: TopicPopupMenu(
                            topic: topic,
                            controller: controller,
                          ),
                        );
                      },
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

  /// YouTube Studio Metric Card Widget
  Widget _buildMetricSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required Color borderColor,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF111827),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Studio Search Input Bar
  Widget _buildStudioSearchBar(
    BuildContext context,
    TopicManagementController controller,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    return Obx(() {
      final query = controller.searchQuery.value;
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: query.isNotEmpty ? const Color(0xFF3B82F6) : borderColor,
            width: query.isNotEmpty ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          onChanged: (val) => controller.searchQuery.value = val,
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: 'Search topics by title, handle, or category...',
            hintStyle: TextStyle(fontSize: 14, color: subtextColor),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => controller.searchQuery.value = '',
                    color: subtextColor,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState(
    BuildContext context,
    TopicManagementController controller,
  ) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark || isDarkMode;
    final cardBg = isDark ? const Color(0xFF161B22) : AppColors.textPrimary;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE5E7EB);
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF111827);
    final subtextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_special_rounded,
                size: 40,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Topics Yet',
              textAlign: TextAlign.center,
              style: context.themeTypography.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Topics help organize related videos into knowledge hubs and improve content discovery for your viewers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateTopicDialog(context, controller),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create Topic',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(
    BuildContext context,
    TopicManagementController controller,
  ) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark || isDarkMode;
    final cardBg = isDark ? const Color(0xFF161B22) : AppColors.textPrimary;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE5E7EB);
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF111827);
    final subtextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: subtextColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching topics found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching with a different keyword or clear the search query.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => controller.searchQuery.value = '',
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text(
                'Clear Search',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
    const childAspectRatio = 16 / 9;

    return Shimmer.fromColors(
      baseColor: const Color(0xFF1F1F1F),
      highlightColor: const Color(0xFF2D2D2D),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassmorphicError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Failed to Load Topics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _retryTrigger.value++,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.bgPage,
                ),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: AppColors.bgPage,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          accessCode:
              createCtrl.selectedVisibility.value == TopicVisibilityType.private
              ? createCtrl.accessCodeController.text.trim()
              : null,
          thumbnailUrl: finalThumbnailUrl,
        );
      },
    );
  }
}

class EditTopicDialog extends StatefulWidget {
  const EditTopicDialog({
    required this.topic,
    required this.channelId,
    required this.isDarkMode,
    required this.controller,
    super.key,
  });
  final Topic topic;
  final String channelId;
  final bool isDarkMode;
  final TopicManagementController controller;

  @override
  State<EditTopicDialog> createState() => _EditTopicDialogState();
}

class _EditTopicDialogState extends State<EditTopicDialog> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController categoryController;
  late TextEditingController accessCodeController;

  late final Rx<TopicVisibilityType> selectedVisibility;
  final obscureAccessCode = true.obs;
  final selectedVideoIds = <String>[].obs;
  final _isLoading = true.obs;
  final channelVideos = <Map<String, dynamic>>[].obs;

  // Thumbnail State
  final thumbnailSource = 'video'.obs; // 'video' or 'custom'
  final Rx<String?> chosenVideoThumbnailUrl = Rx<String?>(null);
  final Rx<Uint8List?> pickedCustomImageBytes = Rx<Uint8List?>(null);
  final Rx<String?> pickedCustomImageName = Rx<String?>(null);
  final isSaving = false.obs;
  final Rx<String?> currentThumbnailUrl = Rx<String?>(null);

  final List<String> categories = const [
    'Technology',
    'Education',
    'Science',
    'Gaming',
    'Music',
    'News',
    'Entertainment',
    'Sports',
    'Comedy',
    'Travel',
    'Food',
    'Beauty',
    'Fashion',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion & Beauty',
  ];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.topic.title);
    descriptionController = TextEditingController(
      text: widget.topic.description,
    );
    categoryController = TextEditingController(
      text: categories.contains(widget.topic.category)
          ? widget.topic.category
          : 'Technology',
    );
    accessCodeController = TextEditingController(
      text: widget.topic.accessCode ?? '',
    );
    selectedVisibility = widget.topic.visibilityType.obs;
    currentThumbnailUrl.value = widget.topic.thumbnailUrl;
    chosenVideoThumbnailUrl.value = widget.topic.thumbnailUrl;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final videos = await widget.controller.fetchChannelVideos(
        widget.channelId,
      );
      final linkedIds = await widget.controller.fetchTopicVideos(
        widget.topic.slug,
      );

      channelVideos.assignAll(videos);
      selectedVideoIds.assignAll(linkedIds);

      // Intelligently identify if current thumbnail is from video or custom upload
      if (currentThumbnailUrl.value != null &&
          currentThumbnailUrl.value!.isNotEmpty) {
        final matchesVideo = videos.any(
          (v) => v['thumbnailUrl'] == currentThumbnailUrl.value,
        );
        if (matchesVideo) {
          thumbnailSource.value = 'video';
          chosenVideoThumbnailUrl.value = currentThumbnailUrl.value;
        } else {
          thumbnailSource.value = 'custom';
        }
      } else {
        // Default to video source and select first linked video's thumbnail
        thumbnailSource.value = 'video';
        if (selectedVideoIds.isNotEmpty) {
          final firstVideo = videos.firstWhereOrNull(
            (v) => selectedVideoIds.contains(v['id']),
          );
          if (firstVideo != null) {
            chosenVideoThumbnailUrl.value =
                firstVideo['thumbnailUrl'] as String?;
          }
        }
      }

      _isLoading.value = false;
    } catch (_) {
      _isLoading.value = false;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return AlertDialog(
        backgroundColor: widget.isDarkMode
            ? AppTheme.colors.surface
            : AppTheme.colors.textPrimary,
        title: Text(
          'Edit Topic',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode
                ? AppTheme.colors.textPrimary
                : AppTheme.colors.background,
          ),
        ),
        content: _isLoading.value
            ? const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary
                            : AppTheme.colors.background,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Topic Title',
                        labelStyle: TextStyle(
                          color: widget.isDarkMode
                              ? AppTheme.colors.textPrimary54
                              : AppTheme.colors.textSecondary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.isDarkMode
                                ? const Color(0xFF30363D)
                                : AppColors.bgDivider,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary
                            : AppTheme.colors.background,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(
                          color: widget.isDarkMode
                              ? AppTheme.colors.textPrimary54
                              : AppTheme.colors.textSecondary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.isDarkMode
                                ? const Color(0xFF30363D)
                                : AppColors.bgDivider,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    Text(
                      'Category',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary70
                            : AppTheme.colors.background54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: categoryController.text,
                      dropdownColor: widget.isDarkMode
                          ? const Color(0xFF1C2128)
                          : AppColors.textPrimary,
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? AppColors.textPrimary
                            : AppColors.bgPage,
                      ),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.isDarkMode
                                ? const Color(0xFF374151)
                                : AppColors.bgDivider,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6366F1)),
                        ),
                      ),
                      items: categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          categoryController.text = val;
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Topic Visibility Type Selector
                    Text(
                      'Visibility Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary70
                            : AppTheme.colors.background54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TopicVisibilityType>(
                      isExpanded: true,
                      initialValue: selectedVisibility.value,
                      dropdownColor: widget.isDarkMode
                          ? const Color(0xFF1C2128)
                          : AppColors.textPrimary,
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? AppColors.textPrimary
                            : AppColors.bgPage,
                      ),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.isDarkMode
                                ? const Color(0xFF374151)
                                : AppColors.bgDivider,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6366F1)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TopicVisibilityType.public,
                          child: Text(
                            'Public (Anyone can contribute)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: TopicVisibilityType.channelOnly,
                          child: Text(
                            'Channel Only (Only you can contribute)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: TopicVisibilityType.private,
                          child: Text(
                            'Private (Passcode required for others)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          selectedVisibility.value = val;
                        }
                      },
                    ),

                    // Private Access Code field
                    if (selectedVisibility.value ==
                        TopicVisibilityType.private) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: accessCodeController,
                        obscureText: obscureAccessCode.value,
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? AppTheme.colors.textPrimary
                              : AppTheme.colors.background,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Setup Access Code',
                          labelStyle: TextStyle(
                            color: widget.isDarkMode
                                ? AppTheme.colors.textPrimary54
                                : AppTheme.colors.textSecondary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureAccessCode.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              obscureAccessCode.value =
                                  !obscureAccessCode.value;
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: widget.isDarkMode
                                  ? const Color(0xFF374151)
                                  : AppColors.bgDivider,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Topic Thumbnail Selector tab
                    Text(
                      'Topic Thumbnail',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary70
                            : AppTheme.colors.background54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? const Color(0xFF161B22)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.isDarkMode
                              ? const Color(0xFF30363D)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                thumbnailSource.value = 'video';
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: thumbnailSource.value == 'video'
                                      ? const Color(0xFF6366F1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Use Video Thumbnail',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: thumbnailSource.value == 'video'
                                        ? AppColors.textPrimary
                                        : (widget.isDarkMode
                                              ? AppColors.textSecondary
                                              : AppColors.bgPage54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                thumbnailSource.value = 'custom';
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: thumbnailSource.value == 'custom'
                                      ? const Color(0xFF6366F1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Upload Custom',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: thumbnailSource.value == 'custom'
                                        ? AppColors.textPrimary
                                        : (widget.isDarkMode
                                              ? AppColors.textSecondary
                                              : AppColors.bgPage54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Thumbnail source specific panels
                    if (thumbnailSource.value == 'custom') ...[
                      GestureDetector(
                        onTap: () async {
                          try {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (pickedFile != null) {
                              final pickedImage = await pickedFile
                                  .readAsBytes();
                              pickedCustomImageBytes.value = pickedImage;
                              pickedCustomImageName.value =
                                  'topic_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            }
                          } catch (e) {
                            AppSnackbar.show(
                              'Error',
                              'Failed to pick image: $e',
                              backgroundColor: AppColors.error,
                              colorText: AppColors.textPrimary,
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: widget.isDarkMode
                                ? const Color(0xFF161B22)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.isDarkMode
                                  ? const Color(0xFF30363D)
                                  : const Color(0xFFE5E7EB),
                              style:
                                  pickedCustomImageBytes.value == null &&
                                      (currentThumbnailUrl.value == null ||
                                          currentThumbnailUrl.value!.isEmpty)
                                  ? BorderStyle.solid
                                  : BorderStyle.none,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: pickedCustomImageBytes.value != null
                              ? Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.memory(
                                        pickedCustomImageBytes.value!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          pickedCustomImageBytes.value = null;
                                          pickedCustomImageName.value = null;
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.bgPage.withValues(
                                              alpha: 0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.close,
                                            color: AppColors.textPrimary,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : (currentThumbnailUrl.value != null &&
                                        currentThumbnailUrl.value!.isNotEmpty
                                    ? Image.network(
                                        currentThumbnailUrl.value!,
                                        fit: BoxFit.cover,
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 32,
                                            color: widget.isDarkMode
                                                ? AppColors.textSecondary
                                                : AppColors.bgPage54,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap to upload a custom topic thumbnail',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: widget.isDarkMode
                                                  ? AppColors.textSecondary
                                                  : AppColors.bgPage54,
                                            ),
                                          ),
                                        ],
                                      )),
                        ),
                      ),
                    ] else ...[
                      // Video Thumbnail Picker
                      if (selectedVideoIds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Link at least one video below to use its thumbnail.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: widget.isDarkMode
                                  ? AppColors.textSecondary
                                  : AppColors.bgPage54,
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          "Select which video's thumbnail to use:",
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDarkMode
                                ? AppTheme.colors.textPrimary70
                                : AppTheme.colors.background54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: channelVideos
                                .where(
                                  (v) => selectedVideoIds.contains(v['id']),
                                )
                                .map((v) {
                                  final videoUrl =
                                      (v['thumbnailUrl'] as String?) ?? '';
                                  final isSelected =
                                      chosenVideoThumbnailUrl.value == videoUrl;
                                  return GestureDetector(
                                    onTap: () {
                                      chosenVideoThumbnailUrl.value = videoUrl;
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 140,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF6366F1)
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF6366F1,
                                                  ).withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: videoUrl.isNotEmpty
                                                ? Image.network(
                                                    videoUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, o, s) =>
                                                        Container(
                                                          color: Colors
                                                              .grey
                                                              .shade800,
                                                        ),
                                                  )
                                                : Container(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF6366F1),
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  color: AppColors.textPrimary,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              color: AppColors.bgPage
                                                  .withValues(
                                                    alpha: 0.6,
                                                  ),
                                              child: Text(
                                                (v['title'] as String?) ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),

                    Text(
                      'Link Videos (At least 1 required)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary70
                            : AppTheme.colors.background54,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (channelVideos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No videos found on your channel. Upload a video first to link to topics.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      Material(
                        color: widget.isDarkMode
                            ? const Color(0xFF161B22)
                            : const Color(0xFFF9FAFB),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: widget.isDarkMode
                                ? const Color(0xFF30363D)
                                : const Color(0xFFE5E7EB),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: channelVideos.map((video) {
                            final videoId = (video['id'] as String?) ?? '';
                            final title = (video['title'] as String?) ?? '';
                            final thumbnailUrl =
                                (video['thumbnailUrl'] as String?) ?? '';
                            final isSelected = selectedVideoIds.contains(
                              videoId,
                            );

                            return Material(
                              color: Colors.transparent,
                              child: CheckboxListTile(
                                activeColor: const Color(0xFF6366F1),
                                checkColor: AppColors.textPrimary,
                                value: isSelected,
                                title: Text(
                                  title,
                                  style: TextStyle(
                                    color: widget.isDarkMode
                                        ? AppColors.textPrimary
                                        : AppColors.bgPage,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                secondary: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: thumbnailUrl.isNotEmpty
                                      ? Image.network(
                                          thumbnailUrl,
                                          width: 44,
                                          height: 25,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, o, s) => Container(
                                            width: 44,
                                            height: 25,
                                            color: AppColors.textSecondary
                                                .withValues(
                                                  alpha: 0.3,
                                                ),
                                            child: const Icon(
                                              Icons.video_library,
                                              size: 14,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 44,
                                          height: 25,
                                          color: AppColors.textSecondary
                                              .withValues(
                                                alpha: 0.3,
                                              ),
                                          child: const Icon(
                                            Icons.video_library,
                                            size: 14,
                                          ),
                                        ),
                                ),
                                onChanged: (bool? checked) {
                                  if (checked ?? false) {
                                    selectedVideoIds.add(videoId);
                                  } else {
                                    selectedVideoIds.remove(videoId);
                                  }

                                  // Sync chosen video thumbnail
                                  if (selectedVideoIds.isNotEmpty) {
                                    final selectedMap = channelVideos
                                        .where(
                                          (v) => selectedVideoIds.contains(
                                            v['id'],
                                          ),
                                        )
                                        .toList();
                                    if (chosenVideoThumbnailUrl.value == null ||
                                        !selectedMap.any(
                                          (v) =>
                                              v['thumbnailUrl'] ==
                                              chosenVideoThumbnailUrl.value,
                                        )) {
                                      chosenVideoThumbnailUrl.value =
                                          selectedMap.first['thumbnailUrl']
                                              as String?;
                                    }
                                  } else {
                                    chosenVideoThumbnailUrl.value = null;
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: widget.isDarkMode
                    ? AppTheme.colors.textPrimary70
                    : AppTheme.colors.background54,
              ),
            ),
          ),
          if (!_isLoading.value)
            ElevatedButton(
              onPressed: isSaving.value
                  ? null
                  : () async {
                      if (titleController.text.isEmpty) {
                        AppSnackbar.show(
                          'Error',
                          'Title is required',
                          backgroundColor: AppColors.error,
                          colorText: AppColors.textPrimary,
                        );
                        return;
                      }
                      if (selectedVisibility.value ==
                              TopicVisibilityType.private &&
                          accessCodeController.text.trim().isEmpty) {
                        AppSnackbar.show(
                          'Error',
                          'Access code is required for private topics',
                          backgroundColor: AppColors.error,
                          colorText: AppColors.textPrimary,
                        );
                        return;
                      }
                      if (selectedVideoIds.isEmpty) {
                        AppSnackbar.show(
                          'Validation Error',
                          'Please select at least one video to link to your topic.',
                          backgroundColor: AppColors.error,
                          colorText: AppColors.textPrimary,
                          duration: const Duration(seconds: 4),
                        );
                        return;
                      }

                      isSaving.value = true;

                      try {
                        var finalThumbnailUrl = currentThumbnailUrl.value;
                        if (thumbnailSource.value == 'custom' &&
                            pickedCustomImageBytes.value != null) {
                          finalThumbnailUrl = await widget.controller
                              .uploadTopicThumbnail(
                                pickedCustomImageBytes.value!,
                                pickedCustomImageName.value!,
                              );
                        } else if (thumbnailSource.value == 'video') {
                          finalThumbnailUrl = chosenVideoThumbnailUrl.value;
                        }

                        await widget.controller.updateTopic(
                          topic: widget.topic,
                          title: titleController.text,
                          description: descriptionController.text,
                          category: categoryController.text.isEmpty
                              ? 'General'
                              : categoryController.text,
                          selectedVideoIds: selectedVideoIds,
                          visibilityType: selectedVisibility.value,
                          accessCode:
                              selectedVisibility.value ==
                                  TopicVisibilityType.private
                              ? accessCodeController.text.trim()
                              : null,
                          thumbnailUrl: finalThumbnailUrl,
                        );
                      } on Exception catch (e) {
                        debugPrint('Error updating topic: $e');
                      } finally {
                        isSaving.value = false;
                        Get.back<void>();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: isSaving.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
            ),
        ],
      );
    });
  }
}
