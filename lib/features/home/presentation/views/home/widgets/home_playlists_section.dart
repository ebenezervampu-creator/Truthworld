import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';

/// Personalized playlists & topics section widget extracted from home.dart
class PersonalizedPlaylistsSection extends StatelessWidget {
  const PersonalizedPlaylistsSection({
    required this.horizontalPadding,
    super.key,
  });

  final double horizontalPadding;

  void _navigateToTagPage(BuildContext context, Topic topic) {
    if (!topic.isValidTopic || topic.slug.trim().isEmpty) return;
    if (Get.isRegistered<TopicController>()) {
      Get.find<TopicController>().topic.value = topic;
    } else {
      Get.find<TopicController>().topic.value = topic;
    }

    unawaited(
      Get.toNamed(
        topic.topicRoute,
        arguments: {'slug': topic.slug, 'fromCard': true, 'topic': topic},
      ),
    );
  }

  double _calculatePersonalizationScore(
    Topic topic,
    UserInterestProfile? profile,
  ) {
    var score = topic.trendingScore > 0
        ? topic.trendingScore
        : (topic.videoCount.toDouble());

    if (profile != null) {
      final slug = topic.slug.toLowerCase();
      if (profile.followedTopicSlugs.contains(slug) ||
          profile.followedTopicSlugs.contains(topic.id)) {
        score += 100.0;
      }
      final topicAffinity =
          profile.topicAffinities[slug] ??
          profile.topicAffinities['topic:$slug'] ??
          0.0;
      score += topicAffinity * 50.0;

      final catAffinity =
          profile.categoryAffinities[topic.category] ??
          profile.categoryAffinities[topic.category.toLowerCase()] ??
          0.0;
      score += catAffinity * 30.0;
    }

    return score;
  }

  @override
  Widget build(BuildContext context) {
    final homeController = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : null;
    final profileService = Get.isRegistered<UserInterestProfileService>()
        ? Get.find<UserInterestProfileService>()
        : null;

    return Obx(() {
      final selectedCategory = homeController?.selectedCategory.value ?? 'All';
      final isFlipCoin = selectedCategory == 'Flip Coin' ||
          selectedCategory == '🪙 Flip Coin';
      final isUnexplored = selectedCategory == 'Unexplored' ||
          selectedCategory == '🧭 Unexplored';
      final isAll = selectedCategory == 'All' || isFlipCoin || isUnexplored;

      final userProfile = profileService?.profile.value;

      final sourceTopics = (homeController?.forYouTopics.isNotEmpty ?? false)
          ? homeController!.forYouTopics
          : ((homeController?.featuredTopics.isNotEmpty ?? false)
              ? homeController!.featuredTopics
              : <Topic>[]);

      final isLoading = (homeController?.isLoadingForYouTopics.value ?? false) &&
          sourceTopics.isEmpty;

      if (isLoading) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Shimmer.fromColors(
            baseColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            highlightColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.1),
            child: Container(
              height: 215,
              decoration: BoxDecoration(
                color: modernDarkProfessionalTheme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }

      // Filter by category if a specific category is selected
      var topicsList = <Topic>[];
      if (!isAll) {
        final catLower = selectedCategory.toLowerCase().trim();
        topicsList = sourceTopics.where((t) {
          if (!t.isValidTopic || t.videoCount <= 0) return false;
          final tCat = t.category.toLowerCase().trim();
          final tSlug = t.slug.toLowerCase().trim();
          final tTitle = t.title.toLowerCase().trim();
          return tCat == catLower ||
              tCat.contains(catLower) ||
              catLower.contains(tCat) ||
              tSlug.contains(catLower) ||
              tTitle.contains(catLower);
        }).toList();
      } else {
        topicsList = sourceTopics
            .where((t) => t.isValidTopic && t.videoCount > 0)
            .toList();
      }

      if (topicsList.isEmpty) {
        return const SizedBox.shrink();
      }

      // Personalize and sort by user interest score
      topicsList.sort((a, b) {
        if (isUnexplored && userProfile != null) {
          final slugA = a.slug.isNotEmpty ? a.slug.toLowerCase() : a.id.toLowerCase();
          final slugB = b.slug.isNotEmpty ? b.slug.toLowerCase() : b.id.toLowerCase();
          final unexpA = !userProfile.exploredTopicSlugs.contains(slugA) &&
              !userProfile.topicAffinities.containsKey('topic:$slugA');
          final unexpB = !userProfile.exploredTopicSlugs.contains(slugB) &&
              !userProfile.topicAffinities.containsKey('topic:$slugB');
          if (unexpA && !unexpB) return -1;
          if (!unexpA && unexpB) return 1;

          final scoreA = _calculatePersonalizationScore(a, userProfile);
          final scoreB = _calculatePersonalizationScore(b, userProfile);
          return scoreB.compareTo(scoreA);
        }
        if (isFlipCoin && userProfile != null) {
          final slugA = a.slug.isNotEmpty ? a.slug.toLowerCase() : a.id.toLowerCase();
          final slugB = b.slug.isNotEmpty ? b.slug.toLowerCase() : b.id.toLowerCase();
          final unexpA = !userProfile.exploredTopicSlugs.contains(slugA) &&
              !userProfile.topicAffinities.containsKey('topic:$slugA');
          final unexpB = !userProfile.exploredTopicSlugs.contains(slugB) &&
              !userProfile.topicAffinities.containsKey('topic:$slugB');
          if (unexpA && !unexpB) return -1;
          if (!unexpA && unexpB) return 1;

          final scoreA = _calculatePersonalizationScore(a, userProfile);
          final scoreB = _calculatePersonalizationScore(b, userProfile);
          return scoreA.compareTo(scoreB);
        }
        final scoreA = _calculatePersonalizationScore(a, userProfile);
        final scoreB = _calculatePersonalizationScore(b, userProfile);
        return scoreB.compareTo(scoreA);
      });

      final sectionTitle = isFlipCoin
          ? 'The Other Side of the Coin'
          : (isUnexplored
              ? 'Unexplored Horizons: What You Love Next'
              : (isAll ? 'For You Topics' : '$selectedCategory Topics'));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.topic_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sectionTitle,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: GoogleFonts.roboto(
                          color: const Color(0xFF00E676),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 215,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: topicsList.length,
              itemBuilder: (context, index) {
                final topic = topicsList[index];
                final imageUrl = (topic.coverImage?.isNotEmpty ?? false)
                    ? topic.coverImage!
                    : ((topic.thumbnailUrl?.isNotEmpty ?? false)
                          ? topic.thumbnailUrl!
                          : '');

                return Container(
                  width: 270,
                  margin: const EdgeInsets.only(right: 16),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _navigateToTagPage(context, topic),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.bgSurfaceContainerHighest,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Uncropped Thumbnail Container (Preserves full aspect ratio)
                            Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(15),
                                    ),
                                    child: imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            memCacheWidth: 480,
                                            maxWidthDiskCache: 480,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const ColoredBox(color: AppColors.bgSurface),
                                            errorWidget: (context, url, error) =>
                                                const ColoredBox(color: AppColors.bgSurface),
                                          )
                                        : ColoredBox(
                                            color: AppColors.bgSurface,
                                            child: Icon(
                                              Icons.topic_rounded,
                                              color: Colors.white.withValues(alpha: 0.6),
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                ),

                                // Category & Video count Badges Overlay
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  right: 10,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Text(
                                          topic.category.isNotEmpty
                                              ? topic.category
                                              : 'Topic',
                                          style: GoogleFonts.roboto(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (topic.videoCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.15),
                                            ),
                                          ),
                                          child: Text(
                                            '${topic.videoCount} videos',
                                            style: GoogleFonts.roboto(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Card Footer: Title & Navigation Arrow
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      topic.title,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

// Backward-compatibility aliases
typedef HomePlaylistsSection = PersonalizedPlaylistsSection;
