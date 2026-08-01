import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/animated_interaction_buttons.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Topic Hero Widget
///
/// Clean UI design:
/// 1. Complete Topic Thumbnail without any title/text overlaid on it.
/// 2. Topic Title & Collapsible description ("show more / show less").
/// 3. Community icon + text row with Video count, Follow/Following button, and Notification Bell settings.
class TopicHeroWidget extends StatefulWidget {
  const TopicHeroWidget({
    required this.isDesktop,
    required this.isTablet,
    super.key,
    this.topic,
    this.onCommunityTap,
    this.onCommentsTap,
  });
  final Topic? topic;
  final bool isDesktop;
  final bool isTablet;
  final VoidCallback? onCommunityTap;
  final VoidCallback? onCommentsTap;

  @override
  State<TopicHeroWidget> createState() => _TopicHeroWidgetState();
}

class _TopicHeroWidgetState extends State<TopicHeroWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.topic == null) {
      return _buildSkeleton();
    }

    final topic = widget.topic!;
    final horizontalPadding = widget.isDesktop
        ? 48.0
        : (widget.isTablet ? 32.0 : 16.0);
    final imageHeight = widget.isDesktop
        ? 360.0
        : (widget.isTablet ? 260.0 : 200.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Complete Topic Thumbnail (NO title or text on it)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: _buildThumbnail(topic),
            ),
          ),
        ),

        // 2. Topic Details Section (Title, Category, Collapsible Description)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Category Badge & Title Row
              Row(
                children: [
                  _buildCategoryBadge(topic),
                ],
              ),
              const SizedBox(height: 10),

              // Title (Tappable to expand description)
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Text(
                  topic.title,
                  style: TextStyle(
                    fontSize: widget.isDesktop
                        ? 32
                        : (widget.isTablet ? 26 : 22),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Collapsible Description ("show more / show less")
              if (topic.description.isNotEmpty)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.description,
                          style: TextStyle(
                            fontSize: widget.isDesktop ? 16 : 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: _isExpanded ? 100 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded ? 'Show less' : '...more',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.brand,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 3. Videos Count Chip + Comments Chip + Follow/Following & Bell Settings Row
              _buildCommunityAndActionsRow(context, topic),

              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider, height: 1),
            ],
          ),
        ),
      ],
    );
  }

  /// Thumbnail without any overlay text
  Widget _buildThumbnail(Topic topic) {
    final bgUrl = (topic.coverImage != null && topic.coverImage!.isNotEmpty)
        ? topic.coverImage
        : (topic.thumbnailUrl != null && topic.thumbnailUrl!.isNotEmpty)
        ? topic.thumbnailUrl
        : null;

    if (bgUrl != null) {
      return Image.network(
        bgUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildGradientFallback(),
      );
    }
    return _buildGradientFallback();
  }

  Widget _buildGradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brand.withValues(alpha: 0.4),
            AppColors.brand.withValues(alpha: 0.15),
            AppColors.bgSurface,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.topic_rounded,
          size: 64,
          color: AppColors.brand,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(Topic topic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        topic.category.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.brand,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Actions Row with Videos Count Chip, Comments Chip (tappable), Follow/Following & Bell dropdown
  Widget _buildCommunityAndActionsRow(BuildContext context, Topic topic) {
    final followingController = Get.find<FollowingTopicsController>();

    return Obx(() {
      final isFollowed = followingController.isTopicFollowed(topic.id);
      final currentBellSetting =
          followingController.topicNotificationSettings[topic.id] ?? 'all';
      final commentsHandler = widget.onCommentsTap ?? widget.onCommunityTap;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Chip 1: Videos Count Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.bgDivider.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.video_collection_outlined,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${topic.videoCount} ${topic.videoCount == 1 ? 'Video' : 'Videos'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Chip 2: Comments Chip (Tappable to scroll to comments)
            InkWell(
              onTap: commentsHandler,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${topic.commentCount} ${topic.commentCount == 1 ? 'Comment' : 'Comments'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Follow / Following Button
            AnimatedFollowTopicButton(
              isFollowed: isFollowed,
              onPressed: () => followingController.toggleFollowTopic(topic),
            ),

            // Bell Icon Notification Option (when Following)
            if (isFollowed) ...[
              const SizedBox(width: 8),
              Container(
                height: 36,
                width: 36,
                decoration: const BoxDecoration(
                  color: AppColors.bgSurfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        _showNotificationSettingsDialog(context, topic.id),
                    child: Icon(
                      _getBellIcon(currentBellSetting),
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  IconData _getBellIcon(String setting) {
    switch (setting) {
      case 'personalized':
        return Icons.notifications_outlined;
      case 'none':
        return Icons.notifications_off_outlined;
      case 'all':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  void _showNotificationSettingsDialog(BuildContext context, String topicId) {
    final followingController = Get.find<FollowingTopicsController>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return FutureBuilder<String>(
          future: followingController.fetchTopicNotificationSetting(topicId),
          builder: (context, snapshot) {
            final currentSetting = snapshot.data ?? 'all';
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const Text(
                    'Topic Notification Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationOption(
                    context,
                    followingController,
                    topicId,
                    title: 'All notifications',
                    subtitle: 'Receive all notifications for this topic',
                    icon: Icons.notifications_active_rounded,
                    value: 'all',
                    currentSetting: currentSetting,
                  ),
                  _buildNotificationOption(
                    context,
                    followingController,
                    topicId,
                    title: 'Personalized',
                    subtitle: 'Receive occasional highlights & updates',
                    icon: Icons.notifications_outlined,
                    value: 'personalized',
                    currentSetting: currentSetting,
                  ),
                  _buildNotificationOption(
                    context,
                    followingController,
                    topicId,
                    title: 'None',
                    subtitle: 'Turn off notifications for this topic',
                    icon: Icons.notifications_off_outlined,
                    value: 'none',
                    currentSetting: currentSetting,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationOption(
    BuildContext context,
    FollowingTopicsController controller,
    String topicId, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String currentSetting,
  }) {
    final isSelected = currentSetting == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: isSelected ? AppColors.brand : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.brand : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Colors.white)
          : null,
      onTap: () {
        Navigator.pop(context);
        controller.updateTopicNotificationSetting(topicId, value);
      },
    );
  }

  Widget _buildSkeleton() {
    final height = widget.isDesktop ? 360.0 : (widget.isTablet ? 260.0 : 200.0);

    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceHover,
      highlightColor: AppColors.bgDivider,
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.textPrimary,
      ),
    );
  }
}
