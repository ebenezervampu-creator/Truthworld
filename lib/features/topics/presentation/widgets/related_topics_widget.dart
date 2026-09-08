import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/pages/topic_page.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Related Topics Widget
///
/// Displays horizontal scrollable list of related topics
/// - Chips for compact view
/// - Cards for detailed view
/// - Navigation to topic page on tap
class RelatedTopicsWidget extends StatelessWidget {
  const RelatedTopicsWidget({
    required this.topics,
    required this.isDesktop,
    required this.isTablet,
    super.key,
  });
  final List<Topic> topics;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final validTopics = topics
        .where((t) => t.isValidTopic && t.videoCount > 0)
        .toList();
    if (validTopics.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          _buildSectionHeader(),
          const SizedBox(height: 16),

          // Horizontal list
          SizedBox(
            height: isDesktop ? 140 : (isTablet ? 120 : 100),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: validTopics.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final topic = validTopics[index];
                return _buildTopicCard(topic);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Related Topics',
          style: TextStyle(
            fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTopicCard(Topic topic) {
    final width = isDesktop ? 280.0 : (isTablet ? 240.0 : 200.0);

    return InkWell(
      onTap: () => Get.to(
        () => const TopicPage(),
        arguments: {'slug': topic.slug},
        preventDuplicates: false,
      ),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
              AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.2),
            ],
          ),
          border: Border.all(
            color: AppColors.bgSurfaceContainerHighest,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or gradient
              _buildBackground(topic),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.bgPage.withValues(alpha: 0.8),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        topic.title,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Video count
                      Text(
                        '${topic.videoCount} videos',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(Topic topic) {
    final bgUrl = (topic.coverImage != null && topic.coverImage!.isNotEmpty)
        ? topic.coverImage
        : (topic.thumbnailUrl != null && topic.thumbnailUrl!.isNotEmpty)
        ? topic.thumbnailUrl
        : null;

    if (bgUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            bgUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildGradientBackground();
            },
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.65),
          ),
          Image.network(
            bgUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildGradientBackground();
            },
          ),
        ],
      );
    }
    return _buildGradientBackground();
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brand.withValues(alpha: 0.15),
            AppColors.brand.withValues(alpha: 0.1),
          ],
        ),
      ),
    );
  }
}

/// Compact chip-style related topics (alternative design)
class RelatedTopicsChips extends StatelessWidget {
  const RelatedTopicsChips({
    required this.topics,
    required this.isDesktop,
    super.key,
  });
  final List<Topic> topics;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 16,
        vertical: 16,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: topics.map(_buildChip).toList(),
      ),
    );
  }

  Widget _buildChip(Topic topic) {
    return ActionChip(
      onPressed: () => Get.to(
        () => const TopicPage(),
        arguments: {'slug': topic.slug},
        preventDuplicates: false,
      ),
      backgroundColor: AppColors.bgSurfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      side: const BorderSide(
        color: AppColors.bgSurfaceContainerHighest,
      ),
      label: Text(
        topic.title,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      avatar: const Icon(
        Icons.topic_rounded,
        size: 18,
        color: Colors.white,
      ),
    );
  }
}
