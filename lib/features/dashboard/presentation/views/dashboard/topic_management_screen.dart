import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

class TopicManagementScreen extends StatelessWidget {
  final String channelId;
  final bool isDarkMode;
  final String searchQuery;
  final RxInt _retryTrigger = 0.obs;

  TopicManagementScreen({
    super.key,
    required this.channelId,
    required this.isDarkMode,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    // Ensure the controller is registered
    if (!Get.isRegistered<TopicManagementController>()) {
      Get.put(TopicManagementController());
    }
    final TopicManagementController controller =
        Get.find<TopicManagementController>();

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppTheme.colors.background
          : AppTheme.colors.textPrimary,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTopicDialog(context, controller),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Create Topic",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
      ),
      body: Obx(() {
        _retryTrigger.value; // register reactive dependency
        return StreamBuilder<List<Topic>>(
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

            var topics = snapshot.data!;

            if (searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              topics = topics
                  .where(
                    (topic) =>
                        topic.title.toLowerCase().contains(query) ||
                        topic.description.toLowerCase().contains(query),
                  )
                  .toList();
            }

            if (topics.isEmpty && searchQuery.isNotEmpty) {
              return _buildSearchEmptyState();
            }

            final size = MediaQuery.of(context).size;
            final bool isDesktop = size.width >= 1024;
            final bool isTablet = size.width >= 600 && size.width < 1024;
            final int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
            final double childAspectRatio = isDesktop ? 1.7 : 1.6;

            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                return _buildTopicCard(context, topic, controller);
              },
            );
          },
        );
      }),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    TopicManagementController controller,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.topic_outlined,
            size: 80,
            color: isDarkMode
                ? AppColors.textPrimary38
                : AppTheme.colors.textSecondary,
          ),
          const SizedBox(height: 20),
          Text(
            'No Topics Yet',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary70
                  : AppTheme.colors.background54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first topic to organize content!',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary54
                  : AppTheme.colors.background45,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _showCreateTopicDialog(context, controller),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Create First Topic',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: isDarkMode
                ? AppTheme.colors.textPrimary30
                : AppTheme.colors.textSecondary,
          ),
          const SizedBox(height: 20),
          Text(
            'No matching topics found',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary70
                  : AppTheme.colors.background54,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              if (Get.isRegistered<DashboardController>()) {
                Get.find<DashboardController>().setSearchQuery('');
              }
            },
            icon: const Icon(Icons.clear_rounded, size: 18),
            label: const Text('Clear Search'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              side: const BorderSide(color: Color(0xFF6366F1)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 1024;
    final bool isTablet = size.width >= 600 && size.width < 1024;
    final int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
    final double childAspectRatio = isDesktop ? 1.7 : 1.6;

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
              color: Colors.black,
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
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
              Text(
                'Failed to Load Topics',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
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

  Widget _buildTopicCard(
    BuildContext context,
    Topic topic,
    TopicManagementController controller,
  ) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(
          '/topic/${topic.slug}',
          arguments: {'slug': topic.slug, 'fromCard': true},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: () {
                final imageUrl =
                    (topic.thumbnailUrl != null &&
                        topic.thumbnailUrl!.isNotEmpty)
                    ? topic.thumbnailUrl!
                    : (topic.coverImage != null && topic.coverImage!.isNotEmpty)
                    ? topic.coverImage!
                    : '';
                if (imageUrl.isNotEmpty) {
                  return CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: const Color(0xFF1F1F1F)),
                    errorWidget: (context, url, error) =>
                        Container(color: const Color(0xFF1F1F1F)),
                  );
                }
                return Container(color: const Color(0xFF1F1F1F));
              }(),
            ),

            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row (Badges + Deletion menu)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Red badge for category
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  topic.category.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Visibility Badge
                          if (topic.visibilityType ==
                              TopicVisibilityType.private)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "PRIVATE",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (topic.visibilityType ==
                              TopicVisibilityType.channelOnly)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "CHANNEL ONLY",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.public,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "PUBLIC",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Actions Popup menu
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            Get.defaultDialog(
                              title: "Delete Topic?",
                              middleText:
                                  "Are you sure you want to delete '${topic.title}'?",
                              textConfirm: "Delete",
                              textCancel: "Cancel",
                              confirmTextColor: Colors.white,
                              buttonColor: Colors.red,
                              onConfirm: () {
                                controller.deleteTopic(topic);
                                Get.back();
                              },
                            );
                          } else if (value == 'view_code') {
                            Get.defaultDialog(
                              title: "Topic Access Code",
                              middleText:
                                  "The setup access code for '${topic.title}' is:\n\n${topic.accessCode ?? 'N/A'}",
                              textConfirm: "Dismiss",
                              confirmTextColor: Colors.white,
                              buttonColor: const Color(0xFF6366F1),
                              onConfirm: () => Get.back(),
                            );
                          } else if (value == 'edit') {
                            _showEditTopicDialog(context, controller, topic);
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                  ),
                                  title: Text(
                                    'Edit Topic',
                                    style: TextStyle(color: Colors.blueAccent),
                                  ),
                                ),
                              ),
                              if (topic.visibilityType ==
                                  TopicVisibilityType.private)
                                const PopupMenuItem<String>(
                                  value: 'view_code',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.vpn_key_outlined,
                                      color: Colors.amber,
                                    ),
                                    title: Text(
                                      'View Access Code',
                                      style: TextStyle(color: Colors.amber),
                                    ),
                                  ),
                                ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Title
                  Text(
                    topic.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Meta Row
                  Row(
                    children: [
                      Text(
                        '${topic.videoCount} videos • ${topic.likeCount} likes • ${topic.views} views',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          topic.category,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    topic.description,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Buttons Row
                  Row(
                    children: [
                      // Explore Topic Button
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Get.toNamed(
                                '/topic/${topic.slug}',
                                arguments: {
                                  'slug': topic.slug,
                                  'fromCard': true,
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text(
                              'Explore Topic',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete Button
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Get.defaultDialog(
                                title: "Delete Topic?",
                                middleText:
                                    "Are you sure you want to delete '${topic.title}'?",
                                textConfirm: "Delete",
                                textCancel: "Cancel",
                                confirmTextColor: Colors.white,
                                buttonColor: Colors.red,
                                onConfirm: () {
                                  controller.deleteTopic(topic);
                                  Get.back();
                                },
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.red.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.2),
                              ),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTopicDialog(
    BuildContext context,
    TopicManagementController controller,
  ) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController(text: "Technology");
    final accessCodeController = TextEditingController();
    final fetchVideosFuture = controller.fetchChannelVideos(channelId);

    final selectedVisibility = TopicVisibilityType.public.obs;
    final obscureAccessCode = true.obs;

    // Thumbnail state
    final thumbnailSource = 'video'.obs;
    final Rx<String?> chosenVideoThumbnailUrl = Rx<String?>(null);
    final Rx<Uint8List?> pickedCustomImageBytes = Rx<Uint8List?>(null);
    final Rx<String?> pickedCustomImageName = Rx<String?>(null);
    final isSaving = false.obs;
    final selectedVideoIds = <String>[].obs;

    Get.dialog(
      Obx(() {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? AppTheme.colors.surface
              : AppTheme.colors.textPrimary,
          title: Text(
            "Create New Topic",
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary
                  : AppTheme.colors.background,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary
                        : AppTheme.colors.background,
                  ),
                  decoration: InputDecoration(
                    labelText: "Topic Title",
                    labelStyle: TextStyle(
                      color: isDarkMode
                          ? AppTheme.colors.textPrimary54
                          : AppTheme.colors.textSecondary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? const Color(0xFF374151)
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
                  maxLines: 2,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary
                        : AppTheme.colors.background,
                  ),
                  decoration: InputDecoration(
                    labelText: "Description",
                    labelStyle: TextStyle(
                      color: isDarkMode
                          ? AppTheme.colors.textPrimary54
                          : AppTheme.colors.textSecondary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? const Color(0xFF374151)
                            : AppColors.bgDivider,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Category",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary70
                        : AppTheme.colors.background54,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: categoryController.text.isNotEmpty
                      ? categoryController.text
                      : "Technology",
                  dropdownColor: isDarkMode
                      ? const Color(0xFF1C2128)
                      : Colors.white,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode
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
                      value: 'Education',
                      child: Text('Education'),
                    ),
                    DropdownMenuItem(
                      value: 'Entertainment',
                      child: Text('Entertainment'),
                    ),
                    DropdownMenuItem(value: 'Music', child: Text('Music')),
                    DropdownMenuItem(value: 'News', child: Text('News')),
                    DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                    DropdownMenuItem(value: 'Gaming', child: Text('Gaming')),
                    DropdownMenuItem(
                      value: 'Technology',
                      child: Text('Technology'),
                    ),
                    DropdownMenuItem(value: 'Science', child: Text('Science')),
                    DropdownMenuItem(value: 'Travel', child: Text('Travel')),
                    DropdownMenuItem(
                      value: 'Lifestyle',
                      child: Text('Lifestyle'),
                    ),
                    DropdownMenuItem(value: 'Comedy', child: Text('Comedy')),
                    DropdownMenuItem(
                      value: 'Documentary',
                      child: Text('Documentary'),
                    ),
                    DropdownMenuItem(value: 'Movies', child: Text('Movies')),
                    DropdownMenuItem(
                      value: 'TV Shows',
                      child: Text('TV Shows'),
                    ),
                    DropdownMenuItem(value: 'Vlogs', child: Text('Vlogs')),
                    DropdownMenuItem(
                      value: 'DIY & How-to',
                      child: Text('DIY & How-to'),
                    ),
                    DropdownMenuItem(
                      value: 'Health & Fitness',
                      child: Text('Health & Fitness'),
                    ),
                    DropdownMenuItem(
                      value: 'Fashion & Beauty',
                      child: Text('Fashion & Beauty'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      categoryController.text = val;
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Topic Visibility Type Selector
                Text(
                  "Visibility Type",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary70
                        : AppTheme.colors.background54,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TopicVisibilityType>(
                  initialValue: selectedVisibility.value,
                  dropdownColor: isDarkMode
                      ? const Color(0xFF1C2128)
                      : Colors.white,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode
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
                      child: Text("Public (Anyone can contribute)"),
                    ),
                    DropdownMenuItem(
                      value: TopicVisibilityType.channelOnly,
                      child: Text("Channel Only (Only you can contribute)"),
                    ),
                    DropdownMenuItem(
                      value: TopicVisibilityType.private,
                      child: Text("Private (Passcode required for others)"),
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
                      color: isDarkMode
                          ? AppTheme.colors.textPrimary
                          : AppTheme.colors.background,
                    ),
                    decoration: InputDecoration(
                      labelText: "Setup Access Code",
                      labelStyle: TextStyle(
                        color: isDarkMode
                            ? AppTheme.colors.textPrimary54
                            : AppTheme.colors.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureAccessCode.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          obscureAccessCode.value = !obscureAccessCode.value;
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDarkMode
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

                // Topic Thumbnail Section
                Text(
                  "Topic Thumbnail",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary70
                        : AppTheme.colors.background54,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF161B22)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: thumbnailSource.value == 'video'
                                  ? const Color(0xFF6366F1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Use Video Thumbnail",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: thumbnailSource.value == 'video'
                                    ? Colors.white
                                    : (isDarkMode
                                          ? Colors.white70
                                          : Colors.black54),
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: thumbnailSource.value == 'custom'
                                  ? const Color(0xFF6366F1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Upload Custom",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: thumbnailSource.value == 'custom'
                                    ? Colors.white
                                    : (isDarkMode
                                          ? Colors.white70
                                          : Colors.black54),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetchVideosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "No videos found on your channel. Upload a video first to create topics.",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    final channelVideos = snapshot.data!;

                    // Render thumbnail preview selector if video source is active
                    Widget renderThumbnailSelector() {
                      if (thumbnailSource.value != 'video') {
                        // Custom upload UI
                        return GestureDetector(
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
                                "Error",
                                "Failed to pick image: $e",
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF161B22)
                                  : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode
                                    ? const Color(0xFF30363D)
                                    : const Color(0xFFE5E7EB),
                                style: pickedCustomImageBytes.value == null
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
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
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
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 32,
                                        color: isDarkMode
                                            ? Colors.white54
                                            : Colors.black54,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Tap to upload topic thumbnail",
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: isDarkMode
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      }

                      // Video source UI
                      if (selectedVideoIds.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            "Link at least one video below to use its thumbnail.",
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        );
                      }

                      final selectedVideos = channelVideos
                          .where((v) => selectedVideoIds.contains(v['id']))
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Select which video's thumbnail to use:",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: isDarkMode
                                  ? AppTheme.colors.textPrimary70
                                  : AppTheme.colors.background54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: selectedVideos.map((v) {
                                final String videoUrl = v['thumbnailUrl'] ?? '';
                                final bool isSelected =
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
                                                  color: Colors.grey.shade800,
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
                                              padding: const EdgeInsets.all(2),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
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
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            child: Text(
                                              v['title'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        renderThumbnailSelector(),
                        const SizedBox(height: 20),
                        Text(
                          "Link Videos (At least 1 required)",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode
                                ? AppTheme.colors.textPrimary70
                                : AppTheme.colors.background54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: isDarkMode
                              ? const Color(0xFF161B22)
                              : const Color(0xFFF9FAFB),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isDarkMode
                                  ? const Color(0xFF30363D)
                                  : const Color(0xFFE5E7EB),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: channelVideos.map((video) {
                              final String videoId = video['id'];
                              final String title = video['title'];
                              final String thumbnailUrl = video['thumbnailUrl'];
                              final isSelected = selectedVideoIds.contains(
                                videoId,
                              );

                              return Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  activeColor: const Color(0xFF6366F1),
                                  checkColor: Colors.white,
                                  value: isSelected,
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
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
                                            errorBuilder: (c, o, s) =>
                                                Container(
                                                  width: 44,
                                                  height: 25,
                                                  color: Colors.grey.withValues(
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
                                            color: Colors.grey.withValues(
                                              alpha: 0.3,
                                            ),
                                            child: const Icon(
                                              Icons.video_library,
                                              size: 14,
                                            ),
                                          ),
                                  ),
                                  onChanged: (bool? checked) {
                                    if (checked == true) {
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
                                      if (chosenVideoThumbnailUrl.value ==
                                              null ||
                                          !selectedMap.any(
                                            (v) =>
                                                v['thumbnailUrl'] ==
                                                chosenVideoThumbnailUrl.value,
                                          )) {
                                        chosenVideoThumbnailUrl.value =
                                            selectedMap.first['thumbnailUrl'];
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
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.colors.textPrimary70
                      : AppTheme.colors.background54,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving.value
                  ? null
                  : () async {
                      if (titleController.text.isEmpty) {
                        AppSnackbar.show(
                          "Error",
                          "Title is required",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      if (selectedVisibility.value ==
                              TopicVisibilityType.private &&
                          accessCodeController.text.trim().isEmpty) {
                        AppSnackbar.show(
                          "Error",
                          "Access code is required for private topics",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      if (selectedVideoIds.isEmpty) {
                        AppSnackbar.show(
                          "Validation Error",
                          "Please select at least one video to link to your new topic.",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 4),
                        );
                        return;
                      }

                      isSaving.value = true;

                      try {
                        String? finalThumbnailUrl;
                        if (thumbnailSource.value == 'custom' &&
                            pickedCustomImageBytes.value != null) {
                          finalThumbnailUrl = await controller
                              .uploadTopicThumbnail(
                                pickedCustomImageBytes.value!,
                                pickedCustomImageName.value!,
                              );
                        } else if (thumbnailSource.value == 'video') {
                          finalThumbnailUrl = chosenVideoThumbnailUrl.value;
                        }

                        await controller.createTopic(
                          channelId: channelId,
                          title: titleController.text,
                          description: descriptionController.text,
                          category: categoryController.text.isEmpty
                              ? "General"
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
                      } catch (e) {
                        debugPrint('Error creating topic: $e');
                      } finally {
                        isSaving.value = false;
                        Get.back();
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
                        color: Colors.white,
                      ),
                    )
                  : const Text("Create", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  void _showEditTopicDialog(
    BuildContext context,
    TopicManagementController controller,
    Topic topic,
  ) {
    Get.dialog(
      EditTopicDialog(
        topic: topic,
        channelId: channelId,
        isDarkMode: isDarkMode,
        controller: controller,
      ),
    );
  }
}

class EditTopicDialog extends StatefulWidget {
  final Topic topic;
  final String channelId;
  final bool isDarkMode;
  final TopicManagementController controller;

  const EditTopicDialog({
    super.key,
    required this.topic,
    required this.channelId,
    required this.isDarkMode,
    required this.controller,
  });

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
            chosenVideoThumbnailUrl.value = firstVideo['thumbnailUrl'];
          }
        }
      }

      _isLoading.value = false;
    } catch (e) {
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
          "Edit Topic",
          style: TextStyle(
            fontFamily: 'Inter',
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
                        labelText: "Topic Title",
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
                        labelText: "Description",
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
                      "Category",
                      style: TextStyle(
                        fontFamily: 'Inter',
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
                          : Colors.white,
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
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
                      "Visibility Type",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary70
                            : AppTheme.colors.background54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TopicVisibilityType>(
                      initialValue: selectedVisibility.value,
                      dropdownColor: widget.isDarkMode
                          ? const Color(0xFF1C2128)
                          : Colors.white,
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
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
                          child: Text("Public (Anyone can contribute)"),
                        ),
                        DropdownMenuItem(
                          value: TopicVisibilityType.channelOnly,
                          child: Text("Channel Only (Only you can contribute)"),
                        ),
                        DropdownMenuItem(
                          value: TopicVisibilityType.private,
                          child: Text("Private (Passcode required for others)"),
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
                          labelText: "Setup Access Code",
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
                              color: Colors.grey,
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
                      "Topic Thumbnail",
                      style: TextStyle(
                        fontFamily: 'Inter',
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
                                  "Use Video Thumbnail",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: thumbnailSource.value == 'video'
                                        ? Colors.white
                                        : (widget.isDarkMode
                                              ? Colors.white70
                                              : Colors.black54),
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
                                  "Upload Custom",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: thumbnailSource.value == 'custom'
                                        ? Colors.white
                                        : (widget.isDarkMode
                                              ? Colors.white70
                                              : Colors.black54),
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
                              "Error",
                              "Failed to pick image: $e",
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
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
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
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
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 32,
                                            color: widget.isDarkMode
                                                ? Colors.white54
                                                : Colors.black54,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Tap to upload a custom topic thumbnail",
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: widget.isDarkMode
                                                  ? Colors.white54
                                                  : Colors.black54,
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
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            "Link at least one video below to use its thumbnail.",
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: widget.isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          "Select which video's thumbnail to use:",
                          style: TextStyle(
                            fontFamily: 'Inter',
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
                                  final String videoUrl =
                                      v['thumbnailUrl'] ?? '';
                                  final bool isSelected =
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
                                                    color: Colors.grey.shade800,
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
                                                  color: Colors.white,
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
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              child: Text(
                                                v['title'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
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
                      "Link Videos (At least 1 required)",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDarkMode
                            ? AppTheme.colors.textPrimary70
                            : AppTheme.colors.background54,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (channelVideos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "No videos found on your channel. Upload a video first to link to topics.",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.redAccent,
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
                            final String videoId = video['id'];
                            final String title = video['title'];
                            final String thumbnailUrl = video['thumbnailUrl'];
                            final isSelected = selectedVideoIds.contains(
                              videoId,
                            );

                            return Material(
                              color: Colors.transparent,
                              child: CheckboxListTile(
                                activeColor: const Color(0xFF6366F1),
                                checkColor: Colors.white,
                                value: isSelected,
                                title: Text(
                                  title,
                                  style: TextStyle(
                                    color: widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
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
                                            color: Colors.grey.withValues(
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
                                          color: Colors.grey.withValues(
                                            alpha: 0.3,
                                          ),
                                          child: const Icon(
                                            Icons.video_library,
                                            size: 14,
                                          ),
                                        ),
                                ),
                                onChanged: (bool? checked) {
                                  if (checked == true) {
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
                                          selectedMap.first['thumbnailUrl'];
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
            onPressed: () => Get.back(),
            child: Text(
              "Cancel",
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
                          "Error",
                          "Title is required",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      if (selectedVisibility.value ==
                              TopicVisibilityType.private &&
                          accessCodeController.text.trim().isEmpty) {
                        AppSnackbar.show(
                          "Error",
                          "Access code is required for private topics",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      if (selectedVideoIds.isEmpty) {
                        AppSnackbar.show(
                          "Validation Error",
                          "Please select at least one video to link to your topic.",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 4),
                        );
                        return;
                      }

                      isSaving.value = true;

                      try {
                        String? finalThumbnailUrl = currentThumbnailUrl.value;
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
                              ? "General"
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
                      } catch (e) {
                        debugPrint('Error updating topic: $e');
                      } finally {
                        isSaving.value = false;
                        Get.back();
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
                        color: Colors.white,
                      ),
                    )
                  : const Text("Save", style: TextStyle(color: Colors.white)),
            ),
        ],
      );
    });
  }
}
