import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_match_info.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Item card for ranked topics in the topics list view.
class TopicListItemCard extends StatelessWidget {
  const TopicListItemCard({
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF38BDF8)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 480;

          return Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 52,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  child: imageSrc != null && imageSrc.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageSrc,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const TopicFallbackThumbnailSmall(),
                        )
                      : const TopicFallbackThumbnailSmall(),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic.title,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (topic.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        topic.description,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people_outline_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${FormatUtils.formatCount(topic.followerCount)} followers',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Text('•', style: TextStyle(color: subtextColor, fontSize: 10)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${FormatUtils.formatCount(topic.videoCount)} videos',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        if (topic.handle.isNotEmpty) ...[
                          Text('•', style: TextStyle(color: subtextColor, fontSize: 10)),
                          Text(
                            topic.handle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              if (!isCompact) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FormatUtils.formatCount(topic.videoCount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Videos',
                          style: TextStyle(fontSize: 10, color: subtextColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FormatUtils.formatCount(topic.followerCount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Followers',
                          style: TextStyle(fontSize: 10, color: subtextColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 14),
              ],

              OutlinedButton.icon(
                onPressed: () => TopicRecommendationEngine.handleTopicSelection(
                  context,
                  controller,
                  topic,
                  onTopicSelected,
                ),
                icon: Icon(
                  isSelected ? Icons.check_rounded : Icons.add_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  isSelected ? 'Added' : 'Add',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? const Color(0xFF18181B)
                      : (isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9)),
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.brand : borderColor,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fallback thumbnail for small topic list items.
class TopicFallbackThumbnailSmall extends StatelessWidget {
  const TopicFallbackThumbnailSmall({super.key});

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
        child: Icon(Icons.topic_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}
