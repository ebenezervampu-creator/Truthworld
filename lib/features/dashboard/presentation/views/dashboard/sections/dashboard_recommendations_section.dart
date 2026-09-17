import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardRecommendationsSection extends StatelessWidget {
  final bool isDarkMode;
  final bool isMobile;
  final bool isDesktop;
  final bool isTablet;
  final Channel? channel;
  final List<Video> videos;
  final Map<String, dynamic> stats;
  final DashboardController controller;

  const DashboardRecommendationsSection({
    required this.isDarkMode,
    required this.isMobile,
    required this.isDesktop,
    required this.isTablet,
    required this.channel,
    required this.videos,
    required this.stats,
    required this.controller,
    super.key,
  });

  static List<Map<String, dynamic>> generateRecommendations(
    Channel? ch,
    List<Video> videos,
    Map<String, dynamic> stats,
    DashboardController controller,
  ) {
    final recs = <Map<String, dynamic>>[];

    // 1. Banner check
    if (ch != null && ch.bannerUrl.isEmpty) {
      recs.add({
        'title': 'Add a Channel Banner',
        'description':
            'Channels with banners get up to 25% more subscribers. Upload a banner to make your channel stand out.',
        'icon': Icons.image_rounded,
        'color': const Color(0xFF10B981),
        'action': 'Customize',
        'onTap': () => controller.setSelectedIndex(6),
      });
    }

    // 2. Channel description check
    if (ch != null && ch.description.trim().length < 30) {
      recs.add({
        'title': 'Improve Channel Description',
        'description':
            'A detailed description helps viewers find your channel. Add keywords and tell viewers what to expect.',
        'icon': Icons.description_rounded,
        'color': const Color(0xFF8B5CF6),
        'action': 'Customize',
        'onTap': () => controller.setSelectedIndex(6),
      });
    }

    // 3. Upload frequency check
    if (videos.isNotEmpty) {
      final now = DateTime.now();
      final lastUpload = videos.first.createdAt.toDate();
      final daysSince = now.difference(lastUpload).inDays;
      if (daysSince > 14) {
        recs.add({
          'title': 'Upload New Content',
          'description':
              "It's been $daysSince days since your last upload. Consistent uploads boost discoverability and subscriber retention.",
          'icon': Icons.cloud_upload_rounded,
          'color': const Color(0xFFF59E0B),
          'action': 'Upload Now',
          'onTap': () => Get.toNamed('/upload'),
        });
      }
    } else if (ch != null) {
      recs.add({
        'title': 'Upload Your First Video',
        'description':
            "You haven't uploaded any videos yet. Start creating content to grow your channel.",
        'icon': Icons.cloud_upload_rounded,
        'color': const Color(0xFFF59E0B),
        'action': 'Upload Now',
        'onTap': () => Get.toNamed('/upload'),
      });
    }

    // 4. Engagement check — low average views
    if (videos.length >= 3) {
      final avgViews =
          videos.fold(0, (acc, v) => acc + v.viewCount) / videos.length;
      if (avgViews < 10) {
        recs.add({
          'title': 'Boost Video Visibility',
          'description':
              'Your recent videos average ${avgViews.toStringAsFixed(0)} views. Try sharing on social media and adding trending topics to increase reach.',
          'icon': Icons.trending_up_rounded,
          'color': const Color(0xFF3B82F6),
          'action': 'View Analytics',
          'onTap': () => controller.setSelectedIndex(3),
        });
      }
    }

    // 5. Tags/Topics check — videos with no tags
    if (videos.isNotEmpty) {
      final untaggedCount = videos
          .where((v) => v.tags.isEmpty && v.topics.isEmpty)
          .length;
      if (untaggedCount > 0) {
        recs.add({
          'title': 'Add Tags & Topics',
          'description':
              '$untaggedCount of your recent videos have no tags or topics. Adding them improves search discoverability.',
          'icon': Icons.label_rounded,
          'color': const Color(0xFFEC4899),
          'action': 'Manage Content',
          'onTap': () => controller.setSelectedIndex(2),
        });
      }
    }

    // 6. Thumbnail check — missing thumbnails
    if (videos.isNotEmpty) {
      final noThumbCount = videos.where((v) => v.thumbnailUrl.isEmpty).length;
      if (noThumbCount > 0) {
        recs.add({
          'title': 'Add Video Thumbnails',
          'description':
              '$noThumbCount of your videos are missing custom thumbnails. Eye-catching thumbnails can increase CTR by up to 30%.',
          'icon': Icons.filter_rounded,
          'color': const Color(0xFF14B8A6),
          'action': 'Manage Content',
          'onTap': () => controller.setSelectedIndex(2),
        });
      }
    }

    // 7. Create a Topic
    if (ch != null && videos.length >= 3) {
      recs.add({
        'title': 'Organize with Topics',
        'description':
            'Group your ${videos.length} videos into Topics to help viewers discover related content more easily.',
        'icon': Icons.topic_rounded,
        'color': const Color(0xFF6366F1),
        'action': 'Create Topic',
        'onTap': () => controller.setSelectedIndex(14),
      });
    }

    // 8. Social links check
    if (ch != null &&
        (ch.socialLinks == null || (ch.socialLinks?.isEmpty ?? true))) {
      recs.add({
        'title': 'Add Social Links',
        'description':
            'Connect your social media accounts to your channel to build a cross-platform audience.',
        'icon': Icons.link_rounded,
        'color': const Color(0xFF0EA5E9),
        'action': 'Customize',
        'onTap': () => controller.setSelectedIndex(6),
      });
    }

    return recs.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = generateRecommendations(
      channel,
      videos,
      stats,
      controller,
    );

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommendations',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.0 : (isTablet ? 1.2 : 1.5),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recommendations.length,
          itemBuilder: (context, index) {
            final rec = recommendations[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (index * 200)),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: DashboardRecommendationCard(
                      recommendation: rec,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class DashboardRecommendationCard extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final bool isDarkMode;

  const DashboardRecommendationCard({
    required this.recommendation,
    required this.isDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final onTap = recommendation['onTap'];
            if (onTap is VoidCallback) {
              onTap();
            }
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (recommendation['color'] as Color).withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    recommendation['icon'] as IconData,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  recommendation['title'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    recommendation['description'] as String,
                    style: TextStyle(
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final onTap = recommendation['onTap'];
                      if (onTap is VoidCallback) {
                        onTap();
                      }
                      HapticFeedback.lightImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: recommendation['color'] as Color,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      recommendation['action'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
