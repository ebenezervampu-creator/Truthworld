import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Topic Recommendation Item helper
class TopicMatchInfo {
  const TopicMatchInfo({
    required this.topic,
    required this.matchPercentage,
    required this.reason,
    required this.isTopRecommendation,
  });

  final Topic topic;
  final int matchPercentage;
  final String reason;
  final bool isTopRecommendation;
}

/// Dynamic Smart Topic Selection & Video Saving Component
/// Ranks topics dynamically using Firebase Cloud Functions / Smart Recommendation Engine
/// specifically for the active video's title, category, description, and tags.
/// Adheres strictly to AppTheme, AppTextStyles, White Icons Rule, and responsive design.
class TopicSelectionBottomSheet extends StatelessWidget {
  const TopicSelectionBottomSheet({
    required this.controller,
    required this.onCreateNewTopicRequested,
    super.key,
    this.onTopicSelected,
  });

  final dynamic controller;
  final Function(bool isDark) onCreateNewTopicRequested;
  final Function(Topic? topic)? onTopicSelected;

  /// Present as modal bottom sheet
  static void show(
    BuildContext context,
    dynamic controller, {
    required Function(bool isDark) onCreateNewTopic,
    Function(Topic? topic)? onTopicSelected,
  }) {
    if (controller != null && controller.topicSearchQuery != null) {
      controller.topicSearchQuery.value = '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TopicSelectionBottomSheet(
        controller: controller,
        onCreateNewTopicRequested: onCreateNewTopic,
        onTopicSelected: onTopicSelected,
      ),
    );
  }

  /// Present as centered popup dialog
  static Future<void> showPopupDialog(
    BuildContext context,
    dynamic controller, {
    required Function(bool isDark) onCreateNewTopic,
    Function(Topic? topic)? onTopicSelected,
  }) async {
    if (controller != null && controller.topicSearchQuery != null) {
      controller.topicSearchQuery.value = '';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 780),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
              child: TopicSelectionBottomSheet(
                controller: controller,
                onCreateNewTopicRequested: onCreateNewTopic,
                onTopicSelected: onTopicSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Header Toolbar
              _buildTopHeader(context, isDark, textColor, subtextColor, borderColor),

              // Search Input & Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _buildSearchBarAndCreateAction(
                  context,
                  isDark,
                  textColor,
                  subtextColor,
                  borderColor,
                ),
              ),

              // Scrollable Content
              Expanded(
                child: Obx(() {
                  final isLoading = controller.isTopicsLoading?.value ?? false;
                  if (isLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Recommending best topics for your video...',
                            style: AppTextStyles.bodyMedium.copyWith(color: subtextColor),
                          ),
                        ],
                      ),
                    );
                  }

                  final query =
                      (controller.topicSearchQuery?.value ?? '').trim().toLowerCase();
                  final allTopics =
                      List<Topic>.from(controller.availableTopics ?? []);

                  // Rank topics dynamically for the video
                  final rankedMatches = _computeRankedTopicMatches(allTopics);

                  // Filter topics by user query
                  final filteredMatches = rankedMatches.where((match) {
                    if (query.isEmpty) return true;
                    final t = match.topic;
                    if (t.title.toLowerCase().contains(query)) return true;
                    if (t.slug.toLowerCase().contains(query)) return true;
                    if (t.handle.toLowerCase().contains(query)) return true;
                    if (t.category.toLowerCase().contains(query)) return true;
                    if (t.description.toLowerCase().contains(query)) return true;
                    return false;
                  }).toList();

                  final selectedId = controller.selectedTopicId?.value ?? '';

                  // Top Hero Topic (Dynamic #1 Recommendation for this video)
                  TopicMatchInfo? featuredMatch;
                  if (selectedId.isNotEmpty) {
                    featuredMatch = rankedMatches.firstWhereOrNull(
                      (m) => m.topic.slug == selectedId || m.topic.id == selectedId,
                    );
                  }
                  featuredMatch ??= filteredMatches.isNotEmpty
                      ? filteredMatches.first
                      : (rankedMatches.isNotEmpty ? rankedMatches.first : null);

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      // "None" Topic Option Chip
                      _buildNoneTopicChip(context, isDark, textColor, subtextColor, borderColor),
                      const SizedBox(height: 16),

                      // Draft Topic Option Card (if active draft exists)
                      if (controller.newTopicData != null && controller.newTopicData.isNotEmpty) ...[
                        _buildDraftTopicCard(context, isDark, borderColor),
                        const SizedBox(height: 16),
                      ],

                      // 1. TOP HERO CONTAINER (#1 Recommended Topic for this Video)
                      if (featuredMatch != null && query.isEmpty) ...[
                        _buildHeroTopicCard(
                          context,
                          featuredMatch,
                          selectedId == featuredMatch.topic.slug || selectedId == featuredMatch.topic.id,
                          isDark,
                          textColor,
                          subtextColor,
                          borderColor,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 2. MIDDLE SECTION HEADER
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add this video to another topic',
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Topics ranked by relevance for your video',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. TOPIC CARDS LIST (Ranked topics below section header)
                      if (filteredMatches.isEmpty)
                        _buildEmptyState(query, textColor, subtextColor, isDark, borderColor)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredMatches.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final match = filteredMatches[index];
                            final isSelected =
                                selectedId == match.topic.slug || selectedId == match.topic.id;
                            return _buildTopicListItemCard(
                              context,
                              match,
                              isSelected,
                              isDark,
                              textColor,
                              subtextColor,
                              borderColor,
                            );
                          },
                        ),
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

  /// Calculates dynamic topic recommendations for the active video
  List<TopicMatchInfo> _computeRankedTopicMatches(List<Topic> topics) {
    if (topics.isEmpty) return [];

    // Check if controller has getRankedTopicsForCurrentVideo method
    try {
      if (controller != null && controller.getRankedTopicsForCurrentVideo != null) {
        final ranked = controller.getRankedTopicsForCurrentVideo();
        if (ranked != null && ranked.isNotEmpty) {
          final results = <TopicMatchInfo>[];
          for (var i = 0; i < ranked.length; i++) {
            final r = ranked[i];
            results.add(
              TopicMatchInfo(
                topic: r.topic,
                matchPercentage: r.matchPercentage,
                reason: r.recommendationReason,
                isTopRecommendation: i == 0,
              ),
            );
          }
          return results;
        }
      }
    } catch (_) {}

    // Smart fallback recommendation ranking
    final videoTitle = (controller.titleController?.text ?? '').trim().toLowerCase();
    final videoCat = (controller.selectedCategory?.value ?? '').trim().toLowerCase();

    final fallback = <TopicMatchInfo>[];
    for (var i = 0; i < topics.length; i++) {
      final t = topics[i];
      final topicCat = t.category.toLowerCase();
      var score = 70;
      var reason = 'Suggested topic knowledge hub';

      if (videoCat.isNotEmpty && (videoCat == topicCat || videoCat.contains(topicCat) || topicCat.contains(videoCat))) {
        score += 25;
        reason = 'Category match (${t.category})';
      }

      if (videoTitle.isNotEmpty && t.title.toLowerCase().split(' ').any((w) => w.length > 3 && videoTitle.contains(w))) {
        score += 15;
        reason = 'Matches video title keywords';
      }

      final pct = score.clamp(64, 98);
      fallback.add(
        TopicMatchInfo(
          topic: t,
          matchPercentage: pct,
          reason: reason,
          isTopRecommendation: i == 0,
        ),
      );
    }

    fallback.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return fallback;
  }

  /// Top Header Bar
  Widget _buildTopHeader(
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
          width: 40,
          height: 4.5,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
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
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.topic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Video to Topic',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'AI Topic Recommendation Hub',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (controller.fetchAvailableTopics != null) {
                    controller.fetchAvailableTopics();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                tooltip: 'Refresh recommendations',
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),
      ],
    );
  }

  /// Search Bar with Create Action
  Widget _buildSearchBarAndCreateAction(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              onChanged: (val) {
                if (controller.topicSearchQuery != null) {
                  controller.topicSearchQuery.value = val;
                }
              },
              style: AppTextStyles.bodyMedium.copyWith(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search topics by title, category, handle...',
                hintStyle: AppTextStyles.caption.copyWith(color: subtextColor, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                suffixIcon: (controller.topicSearchQuery?.value ?? '').isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 18),
                        onPressed: () => controller.topicSearchQuery.value = '',
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onCreateNewTopicRequested(isDark);
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          label: Text(
            'New Topic',
            style: AppTextStyles.buttonText.copyWith(color: Colors.white, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  /// "None" Option Chip
  Widget _buildNoneTopicChip(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    final String selectedId = controller.selectedTopicId?.value ?? '';
    final isSelected = selectedId.isEmpty &&
        (controller.newTopicData == null || controller.newTopicData.isEmpty);

    return InkWell(
      onTap: () {
        if (controller.selectTopic != null) {
          controller.selectTopic('');
        } else if (controller.selectedTopicId != null) {
          controller.selectedTopicId.value = '';
        }
        if (controller.newTopicData != null) {
          controller.newTopicData.clear();
        }
        if (onTopicSelected != null) {
          onTopicSelected!(null);
        }
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
              : (isDark ? const Color(0xFF111722) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "None (Don't save video to any topic)",
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Publish video as a standalone upload',
                    style: AppTextStyles.caption.copyWith(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  /// Draft Topic Option Card
  Widget _buildDraftTopicCard(
    BuildContext context,
    bool isDark,
    Color borderColor,
  ) {
    final String selectedId = controller.selectedTopicId?.value ?? '';
    final isSelected = selectedId == 'new_topic_draft';
    final title = controller.newTopicData['title'] as String? ?? 'Untitled Draft';

    return InkWell(
      onTap: () {
        if (controller.selectTopic != null) {
          controller.selectTopic('new_topic_draft');
        } else if (controller.selectedTopicId != null) {
          controller.selectedTopicId.value = 'new_topic_draft';
        }
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D1537) : const Color(0xFFFDF4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFA855F7),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_document, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Draft: $title',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF7E22CE),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW DRAFT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Topic will be created upon video publish',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFFA855F7), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  /// 1. TOP HERO CONTAINER (#1 Recommended Topic dynamically calculated for video)
  Widget _buildHeroTopicCard(
    BuildContext context,
    TopicMatchInfo match,
    bool isSelected,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    final topic = match.topic;
    final imageSrc = topic.thumbnailUrl ?? topic.coverImage;
    final categoryText =
        topic.category.isNotEmpty ? topic.category.toUpperCase() : 'GENERAL';
    final dateStr = _formatTopicDate(topic.createdAt);

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
              // Dynamic Recommendation Badge Overlay (BEST MATCH • 98% Match)
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
                  // Topic Large Image Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: isNarrow ? 100 : 140,
                      height: isNarrow ? 100 : 140,
                      color: const Color(0xFF1E293B),
                      child: imageSrc != null && imageSrc.isNotEmpty
                          ? Image.network(
                              imageSrc,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildFallbackThumbnail(),
                            )
                          : _buildFallbackThumbnail(),
                    ),
                  ),

                  const SizedBox(width: 18),

                  // Right side details column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Tag
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

                        // Topic Title
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

                        // Topic Description
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

                        // Date Metadata Row
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

              // Bottom Stats & Primary Action Button Row
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsRow(topic),
                    const SizedBox(height: 14),
                    _buildHeroActionButton(topic, isSelected, context),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatsRow(topic),
                    const SizedBox(width: 16),
                    _buildHeroActionButton(topic, isSelected, context),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  /// Hero Stats Row
  Widget _buildStatsRow(Topic topic) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Video Count
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

        // Followers Count
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

  /// Primary Action Button
  Widget _buildHeroActionButton(Topic topic, bool isSelected, BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _handleTopicSelection(context, topic),
      icon: Icon(
        isSelected ? Icons.check_rounded : Icons.add_rounded,
        size: 18,
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
      ),
      label: Text(
        isSelected ? 'Added to topic' : 'Add video to this topic',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF0EA5E9) : Colors.white,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  /// 3. TOPIC LIST CARDS (Ranked by relevance to video)
  Widget _buildTopicListItemCard(
    BuildContext context,
    TopicMatchInfo match,
    bool isSelected,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
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
              // Topic Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 52,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  child: imageSrc != null && imageSrc.isNotEmpty
                      ? Image.network(
                          imageSrc,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildFallbackThumbnailSmall(),
                        )
                      : _buildFallbackThumbnailSmall(),
                ),
              ),

              const SizedBox(width: 14),

              // Title, Description & Recommendation Badge
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

                        // Recommended Badge (No percentage)
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

              // Right side stats & Add button
              if (!isCompact) ...[
                // Stat 1: Video Count
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

                // Stat 2: Follower Count
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

              // Action button: "+ Add" / "Added"
              OutlinedButton.icon(
                onPressed: () => _handleTopicSelection(context, topic),
                icon: Icon(
                  isSelected ? Icons.check_rounded : Icons.add_rounded,
                  size: 16,
                  color: isSelected ? Colors.white : textColor,
                ),
                label: Text(
                  isSelected ? 'Added' : 'Add',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? const Color(0xFF0EA5E9)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  foregroundColor: isSelected ? Colors.white : textColor,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0EA5E9) : borderColor,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Empty state widget
  Widget _buildEmptyState(
    String query,
    Color textColor,
    Color subtextColor,
    bool isDark,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            query.isEmpty ? 'No topics found' : 'No matching topics for "$query"',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a new topic to organize and save your videos.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 13, color: subtextColor),
          ),
        ],
      ),
    );
  }

  /// Fallback Thumbnail for Top Hero Card
  Widget _buildFallbackThumbnail() {
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

  /// Fallback Thumbnail for Topic Item Cards
  Widget _buildFallbackThumbnailSmall() {
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

  /// Helper to format date string e.g. "Aug 14, 2026"
  String _formatTopicDate(DateTime? dateTime) {
    final dt = dateTime ?? DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Handle Topic Selection
  void _handleTopicSelection(BuildContext context, Topic topic) {
    if (controller.selectTopic != null) {
      controller.selectTopic(topic.slug.isNotEmpty ? topic.slug : topic.id);
    } else if (controller.selectedTopicId != null) {
      controller.selectedTopicId.value = topic.slug.isNotEmpty ? topic.slug : topic.id;
    }
    if (controller.newTopicData != null) {
      controller.newTopicData.clear();
    }
    if (onTopicSelected != null) {
      onTopicSelected!(topic);
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }
}
