import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_match_info.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top Hero card highlighting the #1 AI-recommended topic for the active video.
class TopicHeroCard extends StatelessWidget {
  const TopicHeroCard({
    required this.match,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.subtextColor,
    required this.borderColor,
    required this.controller,
    super.key,
    this.onTopicSelected,
  });

  final TopicMatchInfo match;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final Color subtextColor;
  final Color borderColor;
  final dynamic controller;
  final Function(Topic? topic)? onTopicSelected;

  @override
  Widget build(BuildContext context) {
    final topic = match.topic;
    final imageSrc = topic.thumbnailUrl ?? topic.coverImage;
    final categoryText =
        topic.category.isNotEmpty ? topic.category.toUpperCase() : 'GENERAL';
    final dateStr = TopicRecommendationEngine.formatTopicDate(topic.createdAt);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F141C) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Recommendation Badge Overlay
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'BEST MATCH FOR YOUR VIDEO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${match.reason})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content row (Image on left, details on right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: isNarrow ? 100 : 140,
                      height: isNarrow ? 100 : 140,
                      color: const Color(0xFF1E293B),
                      child: imageSrc != null && imageSrc.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageSrc,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const TopicFallbackThumbnail(),
                            )
                          : const TopicFallbackThumbnail(),
                    ),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          topic.title,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontSize: isNarrow ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (topic.description.isNotEmpty)
                          Text(
                            topic.description,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                              color: const Color(0xFF94A3B8),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TopicHeroStatsRow(topic: topic),
                    const SizedBox(height: 14),
                    TopicHeroActionButton(
                      topic: topic,
                      isSelected: isSelected,
                      controller: controller,
                      onTopicSelected: onTopicSelected,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TopicHeroStatsRow(topic: topic),
                    const SizedBox(width: 16),
                    TopicHeroActionButton(
                      topic: topic,
                      isSelected: isSelected,
                      controller: controller,
                      onTopicSelected: onTopicSelected,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Stats indicators for video count and follower count.
class TopicHeroStatsRow extends StatelessWidget {
  const TopicHeroStatsRow({
    required this.topic,
    super.key,
  });

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  FormatUtils.formatCount(topic.videoCount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Videos',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 16),
        Container(width: 1, height: 28, color: const Color(0xFF334155)),
        const SizedBox(width: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  FormatUtils.formatCount(topic.followerCount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Followers',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Action trigger button to add active video to recommended hero topic.
class TopicHeroActionButton extends StatelessWidget {
  const TopicHeroActionButton({
    required this.topic,
    required this.isSelected,
    required this.controller,
    super.key,
    this.onTopicSelected,
  });

  final Topic topic;
  final bool isSelected;
  final dynamic controller;
  final Function(Topic? topic)? onTopicSelected;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => TopicRecommendationEngine.handleTopicSelection(
        context,
        controller,
        topic,
        onTopicSelected,
      ),
      icon: Icon(
        isSelected ? Icons.check_rounded : Icons.add_rounded,
        size: 18,
        color: isSelected ? Colors.white : Colors.black,
      ),
      label: Text(
        isSelected ? 'Added to topic' : 'Add video to this topic',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF18181B) : AppColors.brand,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        side: BorderSide(
          color: isSelected ? const Color(0xFF27272A) : Colors.transparent,
        ),
      ),
    );
  }
}

/// Fallback placeholder thumbnail with gradient.
class TopicFallbackThumbnail extends StatelessWidget {
  const TopicFallbackThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.topic_rounded, color: Colors.white, size: 40),
      ),
    );
  }
}
