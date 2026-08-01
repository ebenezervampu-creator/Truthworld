import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Industry-standard Topic Selection Bottom Sheet for Upload Video Flow
class TopicSelectionBottomSheet extends StatelessWidget {
  const TopicSelectionBottomSheet({
    required this.controller,
    required this.onCreateNewTopicRequested,
    super.key,
  });
  final dynamic controller;
  final Function(bool isDark) onCreateNewTopicRequested;

  /// Helper to present bottom sheet modally
  static void show(
    BuildContext context,
    dynamic controller, {
    required Function(bool isDark) onCreateNewTopic,
  }) {
    controller.topicSearchQuery.value = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TopicSelectionBottomSheet(
        controller: controller,
        onCreateNewTopicRequested: onCreateNewTopic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF161B22) : AppColors.textPrimary;
    final surfaceColor = isDark
        ? const Color(0xFF0D1117)
        : const Color(0xFFF9FAFB);
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE5E7EB);
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF111827);
    final subtextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Header
              _buildHeader(
                context,
                isDark,
                textColor,
                subtextColor,
                borderColor,
              ),

              // Search Bar Field
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: _buildSearchBar(
                  context,
                  isDark,
                  textColor,
                  subtextColor,
                  borderColor,
                ),
              ),

              const SizedBox(height: 4),

              // Main Topics List
              Expanded(
                child: Obx(() {
                  if (controller.isTopicsLoading.value) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 2.5),
                          const SizedBox(height: 16),
                          Text(
                            'Loading topics...',
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final query = controller.topicSearchQuery.value
                      .trim()
                      .toLowerCase();
                  final allTopics = controller.availableTopics;

                  // Filter topics by title, handle, slug, description, or creator channel name
                  final filteredTopics = allTopics.where((topic) {
                    if (query.isEmpty) return true;
                    if (topic.title.toLowerCase().contains(query)) return true;
                    if (topic.slug.toLowerCase().contains(query)) return true;
                    if (topic.handle.toLowerCase().contains(query)) return true;
                    if (topic.description.toLowerCase().contains(query)) {
                      return true;
                    }

                    // Channel search
                    final channelMeta = controller.getChannelMetadata(
                      topic.channelId ?? '',
                    );
                    if (channelMeta != null) {
                      final chName = (channelMeta['name'] ?? '').toLowerCase();
                      final chHandle = (channelMeta['handle'] ?? '')
                          .toLowerCase();
                      if (chName.contains(query) || chHandle.contains(query)) {
                        return true;
                      }
                    }
                    return false;
                  }).toList();

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      // "None" option card
                      _buildNoneTopicCard(
                        context,
                        isDark,
                        textColor,
                        subtextColor,
                        borderColor,
                      ),
                      const SizedBox(height: 8),

                      // Draft Topic Option (if exists)
                      if (controller.newTopicData.isNotEmpty) ...[
                        _buildDraftTopicCard(context, isDark, borderColor),
                        const SizedBox(height: 8),
                      ],

                      // Header label
                      if (filteredTopics.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 4,
                          ),
                          child: Text(
                            'AVAILABLE TOPICS (${filteredTopics.length})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: subtextColor,
                            ),
                          ),
                        ),

                      if (filteredTopics.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.only(top: 20),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: subtextColor.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                query.isEmpty
                                    ? 'No topics found'
                                    : 'No matching topics for "$query"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try a different search term or create a new topic below.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredTopics.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final topic = filteredTopics[index];
                            final isSelected =
                                controller.selectedTopicId.value == topic.slug;
                            return _buildTopicCard(
                              context,
                              topic,
                              isSelected,
                              isDark,
                              textColor,
                              subtextColor,
                              borderColor,
                              surfaceColor,
                            );
                          },
                        ),

                      const SizedBox(height: 16),

                      // Create New Topic button card
                      _buildCreateTopicActionCard(context, isDark, borderColor),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Header widget with title and close/refresh buttons
  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 38,
          height: 4.5,
          decoration: BoxDecoration(
            color: isDark ? AppColors.textDisabled : Colors.black12,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.topic_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Topic',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Save video directly to a topic knowledge hub',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.fetchAvailableTopics,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh topics',
                style: IconButton.styleFrom(
                  foregroundColor: subtextColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  foregroundColor: subtextColor,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),
      ],
    );
  }

  /// Search Bar with instant query filtering
  Widget _buildSearchBar(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    return Obx(() {
      final query = controller.topicSearchQuery.value;
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: query.isNotEmpty
                ? const Color(0xFF3B82F6)
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB)),
            width: query.isNotEmpty ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          onChanged: (val) => controller.topicSearchQuery.value = val,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: 'Search topics by name, handle or channel...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: subtextColor,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => controller.topicSearchQuery.value = '',
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

  /// Option card to unselect topic ("None")
  Widget _buildNoneTopicCard(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    return Obx(() {
      final isSelected =
          controller.selectedTopicId.value.isEmpty &&
          controller.newTopicData.isEmpty;
      return InkWell(
        onTap: () {
          controller.selectTopic('');
          controller.newTopicData.clear();
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1F2937) : const Color(0xFFEFF6FF))
                : (isDark ? const Color(0xFF0D1117) : AppColors.textPrimary),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : (isDark
                        ? const Color(0xFF30363D)
                        : const Color(0xFFE5E7EB)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF21262D)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.block_rounded,
                  color: subtextColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "None (Don't add to topic)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Publish as a standalone video without linking to a topic',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Draft Topic option card
  Widget _buildDraftTopicCard(
    BuildContext context,
    bool isDark,
    Color borderColor,
  ) {
    return Obx(() {
      final isSelected = controller.selectedTopicId.value == 'new_topic_draft';
      final title =
          controller.newTopicData['title'] as String? ?? 'Untitled Draft';

      return InkWell(
        onTap: () {
          controller.selectTopic('new_topic_draft');
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D1537) : const Color(0xFFFDF4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brandHover,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_document,
                  color: AppColors.brandHover,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Draft: $title',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandHover,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'UNSAVED DRAFT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandHover,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This new topic will be created when you publish your video',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.brand : AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.brandHover,
                  size: 22,
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Topic Item Card displaying thumbnail, title, counts, creator channel & lock state
  Widget _buildTopicCard(
    BuildContext context,
    Topic topic,
    bool isSelected,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color surfaceColor,
  ) {
    final isPrivate = topic.visibilityType == TopicVisibilityType.private;
    final isChannelOnly =
        topic.visibilityType == TopicVisibilityType.channelOnly;

    final imageSrc = topic.thumbnailUrl ?? topic.coverImage;

    return InkWell(
      onTap: () => _handleTopicSelection(context, topic),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail with fallback icon & lock badge overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 58,
                    height: 58,
                    color: isDark
                        ? const Color(0xFF21262D)
                        : const Color(0xFFE5E7EB),
                    child: imageSrc != null && imageSrc.isNotEmpty
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                imageSrc,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _buildFallbackThumbnail(isDark),
                              ),
                              Container(
                                color: Colors.black.withValues(alpha: 0.65),
                              ),
                              Image.network(
                                imageSrc,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    _buildFallbackThumbnail(isDark),
                              ),
                            ],
                          )
                        : _buildFallbackThumbnail(isDark),
                  ),
                ),

                // Visibility badge overlay
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isPrivate
                          ? AppColors.warning
                          : (isChannelOnly
                                ? AppColors.info
                                : AppColors.success),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      isPrivate
                          ? Icons.lock_rounded
                          : (isChannelOnly
                                ? Icons.group_rounded
                                : Icons.public_rounded),
                      size: 10,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Visibility Chip
                      _buildVisibilityChip(topic.visibilityType),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Followers & Videos Count Row
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 13,
                        color: subtextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${FormatUtils.formatCount(topic.followerCount)} followers',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subtextColor,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(color: subtextColor, fontSize: 12),
                        ),
                      ),
                      Icon(
                        Icons.video_library_outlined,
                        size: 13,
                        color: subtextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${FormatUtils.formatCount(topic.videoCount)} videos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Channel Name (For Public or Channel topics)
                  _buildCreatorChannelInfo(topic, isDark, subtextColor),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Radio/Selection Icon
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.textPrimary,
                  size: 16,
                ),
              )
            else if (isPrivate)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  color: AppColors.warning,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Renders fallback thumbnail gradient with icon
  Widget _buildFallbackThumbnail(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1F2937), const Color(0xFF111827)]
              : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.topic_rounded,
          color: Color(0xFF3B82F6),
          size: 26,
        ),
      ),
    );
  }

  /// Visibility Chip (Public / Private / Channel Only)
  Widget _buildVisibilityChip(TopicVisibilityType type) {
    var label = 'Public';
    var color = AppColors.success;
    var icon = Icons.public_rounded;

    if (type == TopicVisibilityType.private) {
      label = 'Private';
      color = AppColors.warning;
      icon = Icons.lock_rounded;
    } else if (type == TopicVisibilityType.channelOnly) {
      label = 'Channel';
      color = AppColors.info;
      icon = Icons.group_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays Creator Channel details for public topics
  Widget _buildCreatorChannelInfo(
    Topic topic,
    bool isDark,
    Color subtextColor,
  ) {
    if (topic.channelId == null || topic.channelId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final channelMeta = controller.getChannelMetadata(topic.channelId!);
      final channelName = channelMeta?['name'] ?? 'TruthWorld Creator';

      return Row(
        children: [
          const Icon(
            Icons.account_circle_outlined,
            size: 13,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Created by $channelName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Create New Topic Card Action button
  Widget _buildCreateTopicActionCard(
    BuildContext context,
    bool isDark,
    Color borderColor,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onCreateNewTopicRequested(isDark);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Create New Topic',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles selection of a topic (and prompts for PIN if topic is private)
  void _handleTopicSelection(BuildContext context, Topic topic) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCreator =
        topic.creatorId == currentUserId ||
        (controller.selectedChannel.value != null &&
            topic.channelId == controller.selectedChannel.value!.id);

    // If public or channelOnly or created by current user -> select immediately
    if (topic.visibilityType != TopicVisibilityType.private || isCreator) {
      controller.selectTopic(topic.slug);
      controller.newTopicData.clear();
      HapticFeedback.lightImpact();
      Navigator.pop(context);
      Get.snackbar(
        'Topic Selected',
        'Video will save to "${topic.title}"',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // If topic is private and user is not creator -> Require PIN / Password
    _showPrivateTopicPinDialog(context, topic);
  }

  /// Security Modal Dialog for entering PIN / Password for Private Topics
  void _showPrivateTopicPinDialog(BuildContext context, Topic topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinController = TextEditingController();
    final isObscured = true.obs;
    final errorMessage = ''.obs;
    final isVerifying = false.obs;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark
              ? const Color(0xFF161B22)
              : AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private Topic PIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Passcode required to save video',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.bgPage54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter PIN / Password for "${topic.title}":',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondary
                      : const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),

              Obx(
                () => TextField(
                  controller: pinController,
                  obscureText: isObscured.value,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: isObscured.value ? 2.0 : 0.5,
                    color: isDark ? AppColors.textPrimary : AppColors.bgPage,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter topic passcode...',
                    prefixIcon: const Icon(
                      Icons.key_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured.value
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: isDark
                            ? AppColors.textSecondary
                            : Colors.black45,
                      ),
                      onPressed: isObscured.toggle,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0D1117)
                        : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: errorMessage.isNotEmpty
                            ? AppColors.error
                            : (isDark
                                  ? const Color(0xFF30363D)
                                  : const Color(0xFFE5E7EB)),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: errorMessage.isNotEmpty
                            ? AppColors.error
                            : AppColors.warning,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),

              Obx(() {
                if (errorMessage.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          errorMessage.value,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.bgPage54,
                ),
              ),
            ),
            Obx(
              () => ElevatedButton.icon(
                onPressed: isVerifying.value
                    ? null
                    : () async {
                        final inputPasscode = pinController.text.trim();
                        if (inputPasscode.isEmpty) {
                          errorMessage.value = 'Passcode cannot be empty';
                          return;
                        }

                        isVerifying.value = true;
                        errorMessage.value = '';

                        final success = await controller.unlockPrivateTopic(
                          topic.slug,
                          inputPasscode,
                        );
                        isVerifying.value = false;

                        if (success) {
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx); // Close PIN dialog
                          }
                          if (context.mounted) {
                            Navigator.pop(context); // Close Bottom Sheet
                          }
                        } else {
                          errorMessage.value =
                              'Incorrect PIN / Password for this topic';
                        }
                      },
                icon: isVerifying.value
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 16),
                label: Text(
                  isVerifying.value ? 'Verifying...' : 'Unlock & Select',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
