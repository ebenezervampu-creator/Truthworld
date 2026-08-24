import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_popup_menu.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Redesigned Topics Tab in Studio
/// Matches exact Visual Architecture, Fonts, Colors, and Theme from the Channel Creation Screen.
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

      Get.dialog<void>(
        EditTopicDialog(
          topic: topic,
          channelId: topic.channelId ?? channelId,
          isDarkMode: isDarkMode,
          controller: controller,
        ),
      );
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTopicDialog(context, controller),
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text(
          'Create Topic',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 13,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Studio Header & Summary Metrics Bar
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF27272A)),
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
                                color: Colors.white,
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
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      TopicSelectionBottomSheet.showPopupDialog(
                                        context,
                                        controller,
                                        onCreateNewTopic: (isDark) =>
                                            _showCreateTopicDialog(context, controller),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.topic_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Save Video',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFF18181B),
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFF27272A)),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _showCreateTopicDialog(context, controller),
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
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
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
                                    color: Colors.white,
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
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  TopicSelectionBottomSheet.showPopupDialog(
                                    context,
                                    controller,
                                    onCreateNewTopic: (isDark) =>
                                        _showCreateTopicDialog(context, controller),
                                  );
                                },
                                icon: const Icon(
                                  Icons.topic_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Save Video to Topic',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFF18181B),
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF27272A)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showCreateTopicDialog(context, controller),
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
                                  backgroundColor: Colors.white,
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
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Metric Summary Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return Obx(() {
                        return GridView.count(
                          crossAxisCount: isMobile ? 2 : 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          childAspectRatio: isMobile ? 1.8 : 2.4,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMetricSummaryCard(
                              context,
                              title: 'Total Topics',
                              value: '${controller.totalTopicsCount}',
                              icon: Icons.topic_rounded,
                              onTap: () => controller.setFilterMode('all'),
                              isSelected: controller.activeFilterMode.value == 'all',
                            ),
                            _buildMetricSummaryCard(
                              context,
                              title: 'Linked Videos',
                              value: '${controller.totalVideosCount}',
                              icon: Icons.video_library_rounded,
                              onTap: () => controller.setFilterMode('all'),
                            ),
                            _buildMetricSummaryCard(
                              context,
                              title: 'Public Topics',
                              value: '${controller.publicTopicsCount}',
                              icon: Icons.public_rounded,
                              onTap: () => controller.setFilterMode('public'),
                              isSelected: controller.activeFilterMode.value == 'public',
                            ),
                            _buildMetricSummaryCard(
                              context,
                              title: 'Private Topics',
                              value: '${controller.privateTopicsCount}',
                              icon: Icons.lock_rounded,
                              onTap: () => controller.setFilterMode('private'),
                              isSelected: controller.activeFilterMode.value == 'private',
                            ),
                          ],
                        );
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Studio Search Bar
                  _buildStudioSearchBar(context, controller),
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
                    final filterMode = controller.activeFilterMode.value;

                    var baseTopics = topics;
                    if (filterMode == 'public') {
                      baseTopics = topics
                          .where((t) => t.visibilityType == TopicVisibilityType.public)
                          .toList();
                    } else if (filterMode == 'private') {
                      baseTopics = topics
                          .where((t) => t.visibilityType == TopicVisibilityType.private)
                          .toList();
                    }

                    final filtered = query.isEmpty
                        ? baseTopics
                        : baseTopics.where((topic) {
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

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final int crossAxisCount;
                        final double childAspectRatio;

                        if (width >= 1200) {
                          crossAxisCount = 4;
                          childAspectRatio = 0.95;
                        } else if (width >= 800) {
                          crossAxisCount = 3;
                          childAspectRatio = 0.90;
                        } else if (width >= 550) {
                          crossAxisCount = 2;
                          childAspectRatio = 0.85;
                        } else {
                          crossAxisCount = 1;
                          childAspectRatio = 1.25;
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: childAspectRatio,
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

  /// Studio Metric Card Widget matching Channel Creation Card Theme
  Widget _buildMetricSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF27272A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Studio Search Input Bar matching Channel Creation _buildInputField
  Widget _buildStudioSearchBar(
    BuildContext context,
    TopicManagementController controller,
  ) {
    return Obx(() {
      final query = controller.searchQuery.value;
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: query.isNotEmpty ? Colors.white : const Color(0xFF27272A),
            width: query.isNotEmpty ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          onChanged: (val) => controller.searchQuery.value = val,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search topics by title, handle, or category...',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 20,
            ),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white70),
                    onPressed: () => controller.searchQuery.value = '',
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState(
    BuildContext context,
    TopicManagementController controller,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Icon(
                Icons.folder_special_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Topics Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Topics help organize related videos into knowledge hubs and improve content discovery for your viewers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateTopicDialog(context, controller),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.black),
              label: const Text(
                'Create Topic',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching topics found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try searching with a different keyword or clear the search query.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => controller.searchQuery.value = '',
              icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Clear Search',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF18181B),
                side: const BorderSide(color: Color(0xFF27272A)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
      baseColor: const Color(0xFF161618),
      highlightColor: const Color(0xFF27272A),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
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
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
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
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Failed to Load Topics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _retryTrigger.value++,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Colors.black,
                ),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

/// Edit Topic Dialog matching Channel Wizard form aesthetics and design tokens
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
  final RxBool obscureAccessCode = true.obs;
  final RxList<String> selectedVideoIds = <String>[].obs;
  final RxBool _isLoading = true.obs;
  final RxList<Map<String, dynamic>> channelVideos = <Map<String, dynamic>>[].obs;

  // Thumbnail State
  final RxString thumbnailSource = 'video'.obs; // 'video' or 'custom'
  final Rx<String?> chosenVideoThumbnailUrl = Rx<String?>(null);
  final Rx<Uint8List?> pickedCustomImageBytes = Rx<Uint8List?>(null);
  final Rx<String?> pickedCustomImageName = Rx<String?>(null);
  final RxBool isSaving = false.obs;
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
    'Lifestyle',
    'Food',
    'Fashion',
    'Health',
    'Fitness',
    'Business',
    'Finance',
    'History',
    'Art',
    'Animation',
    'Automotive',
    'Pets & Animals',
    'DIY & How-to',
    'Nature',
    'Spirituality',
    'People & Blogs',
    'Kids & Family',
    'Movies',
    'TV Shows',
    'Vlogs',
    'Documentary',
    'Other',
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

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    int? maxLength,
    Widget? suffixIcon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          suffixIcon: suffixIcon,
          counterStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Dialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF27272A)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Topic',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Get.back<void>(),
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: _isLoading.value
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Topic Title', isRequired: true),
                            const SizedBox(height: 8),
                            _buildInputField(
                              controller: titleController,
                              hintText: 'Enter topic title',
                              maxLength: 100,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Description'),
                            const SizedBox(height: 8),
                            _buildInputField(
                              controller: descriptionController,
                              hintText: 'Describe your topic...',
                              maxLines: 3,
                              maxLength: 500,
                            ),
                            const SizedBox(height: 16),

                            // Category Dropdown
                            _buildFieldLabel('Category', isRequired: true),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF121212),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF27272A)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: categoryController.text,
                                  dropdownColor: const Color(0xFF18181B),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  items: categories
                                      .map(
                                        (cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Text(cat),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      categoryController.text = val;
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Topic Visibility Type Selector
                            _buildFieldLabel('Visibility Type', isRequired: true),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF121212),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF27272A)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButtonFormField<TopicVisibilityType>(
                                  isExpanded: true,
                                  value: selectedVisibility.value,
                                  dropdownColor: const Color(0xFF18181B),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                              ),
                            ),

                            // Private Access Code field
                            if (selectedVisibility.value ==
                                TopicVisibilityType.private) ...[
                              const SizedBox(height: 16),
                              _buildFieldLabel('Setup Access Code', isRequired: true),
                              const SizedBox(height: 8),
                              _buildInputField(
                                controller: accessCodeController,
                                hintText: 'Enter access code',
                                obscureText: obscureAccessCode.value,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureAccessCode.value
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    obscureAccessCode.value =
                                        !obscureAccessCode.value;
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Topic Thumbnail Selector
                            _buildFieldLabel('Topic Thumbnail'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF121212),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF27272A),
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
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: thumbnailSource.value == 'video'
                                              ? const Color(0xFF27272A)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Use Video Thumbnail',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: thumbnailSource.value == 'video'
                                                ? Colors.white
                                                : AppColors.textSecondary,
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
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: thumbnailSource.value == 'custom'
                                              ? const Color(0xFF27272A)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Upload Custom',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: thumbnailSource.value == 'custom'
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Thumbnail Source Panel
                            if (thumbnailSource.value == 'custom') ...[
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    final picker = ImagePicker();
                                    final pickedFile = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (pickedFile != null && context.mounted) {
                                      final croppedFile =
                                          await ImageCropperService.cropTopicThumbnail(
                                        imagePath: pickedFile.path,
                                        context: context,
                                      );
                                      if (croppedFile != null) {
                                        final croppedBytes =
                                            await croppedFile.readAsBytes();
                                        pickedCustomImageBytes.value = croppedBytes;
                                        pickedCustomImageName.value =
                                            'topic_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      }
                                    }
                                  } catch (e) {
                                    AppSnackbar.show(
                                      'Error',
                                      'Failed to pick image: $e',
                                      backgroundColor: AppColors.error,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121212),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF27272A),
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
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xB3000000),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  padding: const EdgeInsets.all(4),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
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
                                          : const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.cloud_upload_outlined,
                                                  size: 32,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Tap to upload a custom topic thumbnail',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            )),
                                ),
                              ),
                            ] else ...[
                              // Video Thumbnail Picker
                              if (selectedVideoIds.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Link at least one video below to use its thumbnail.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              else ...[
                                const Text(
                                  "Select which video's thumbnail to use:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
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
                                              margin: const EdgeInsets.only(right: 10),
                                              width: 130,
                                              height: 75,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : const Color(0xFF27272A),
                                                  width: isSelected ? 2 : 1,
                                                ),
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
                                                                  color: const Color(0xFF1E1E1E),
                                                                ),
                                                          )
                                                        : Container(
                                                            color: const Color(0xFF1E1E1E),
                                                          ),
                                                  ),
                                                  if (isSelected)
                                                    Positioned(
                                                      top: 4,
                                                      right: 4,
                                                      child: Container(
                                                        decoration: const BoxDecoration(
                                                          color: Colors.white,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        padding: const EdgeInsets.all(2),
                                                        child: const Icon(
                                                          Icons.check,
                                                          color: Colors.black,
                                                          size: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  Positioned(
                                                    bottom: 0,
                                                    left: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      color: Colors.black.withValues(
                                                        alpha: 0.7,
                                                      ),
                                                      child: Text(
                                                        (v['title'] as String?) ?? '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
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
                            const SizedBox(height: 16),

                            _buildFieldLabel('Link Videos (At least 1 required)', isRequired: true),
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
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121212),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF27272A)),
                                ),
                                clipBehavior: Clip.antiAlias,
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
                                        activeColor: Colors.white,
                                        checkColor: Colors.black,
                                        value: isSelected,
                                        title: Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        secondary: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: thumbnailUrl.isNotEmpty
                                              ? Image.network(
                                                  thumbnailUrl,
                                                  width: 44,
                                                  height: 25,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, o, s) => Container(
                                                    width: 44,
                                                    height: 25,
                                                    color: const Color(0xFF27272A),
                                                    child: const Icon(
                                                      Icons.video_library,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: 44,
                                                  height: 25,
                                                  color: const Color(0xFF27272A),
                                                  child: const Icon(
                                                    Icons.video_library,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                        onChanged: (checked) {
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
              ),

              // Dialog Action Buttons Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF27272A)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                                    colorText: Colors.white,
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
                                    colorText: Colors.white,
                                  );
                                  return;
                                }
                                if (selectedVideoIds.isEmpty) {
                                  AppSnackbar.show(
                                    'Validation Error',
                                    'Please select at least one video to link to your topic.',
                                    backgroundColor: AppColors.error,
                                    colorText: Colors.white,
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
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: isSaving.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
