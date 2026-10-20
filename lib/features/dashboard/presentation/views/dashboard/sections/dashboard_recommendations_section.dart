import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
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
        'action': 'Customize',
        'onTap': () => controller.setSelectedIndex(6),
      });
    }

    // 3. Upload frequency check
    final effectiveVideos = videos.isNotEmpty
        ? videos
        : (Get.isRegistered<VideoManagementController>()
            ? Get.find<VideoManagementController>().channelVideos.toList()
            : <Video>[]);

    final hasUploadedVideos = effectiveVideos.isNotEmpty ||
        (ch != null && ch.videoCount > 0) ||
        ((stats['videos'] is int && (stats['videos'] as int) > 0) ||
            (stats['videos'] is String &&
                stats['videos'] != '0' &&
                stats['videos'].toString().isNotEmpty));

    if (effectiveVideos.isNotEmpty) {
      final now = DateTime.now();
      final latest = effectiveVideos.first;
      final effectiveDate =
          latest.uploadedAt.toDate().isAfter(latest.createdAt.toDate())
              ? latest.uploadedAt.toDate()
              : latest.createdAt.toDate();
      final daysSince = now.difference(effectiveDate).inDays;
      if (daysSince > 14) {
        recs.add({
          'title': 'Upload New Content',
          'description':
              "It's been $daysSince days since your last upload. Consistent uploads boost discoverability and subscriber retention.",
          'icon': Icons.cloud_upload_rounded,
          'action': 'Upload Now',
          'onTap': () => Get.toNamed('/upload'),
        });
      }
    } else if (!controller.rxIsLoading.value &&
        ch != null &&
        !hasUploadedVideos) {
      recs.add({
        'title': 'Upload Your First Video',
        'description':
            "You haven't uploaded any videos yet. Start creating content to grow your channel.",
        'icon': Icons.cloud_upload_rounded,
        'action': 'Upload Now',
        'onTap': () => Get.toNamed('/upload'),
      });
    }

    // 4. Engagement check — low average views
    if (effectiveVideos.length >= 3) {
      final avgViews = effectiveVideos.fold(0, (acc, v) => acc + v.viewCount) /
          effectiveVideos.length;
      if (avgViews < 10) {
        recs.add({
          'title': 'Boost Video Visibility',
          'description':
              'Your recent videos have modest view counts. Try optimizing your titles, tags, and thumbnails.',
          'icon': Icons.trending_up_rounded,
          'action': 'View Content',
          'onTap': () => controller.setSelectedIndex(2),
        });
      }
    }

    // 5. Monetization readiness
    final subscriberCount = ch?.subscriberCount ?? 0;
    if (subscriberCount >= 50 && ch != null) {
      recs.add({
        'title': 'Explore Channel Memberships',
        'description':
            'You have an engaged audience. Set up membership tiers to earn recurring revenue from supporters.',
        'icon': Icons.card_membership_rounded,
        'action': 'Set Up Tiers',
        'onTap': () => controller.setSelectedIndex(18),
      });
    }

    // 6. Subtitles check
    if (effectiveVideos.length >= 2) {
      recs.add({
        'title': 'Add Multi-Language Subtitles',
        'description':
            'Videos with subtitles reach a global audience. Auto-generate or add multilingual subtitles.',
        'icon': Icons.subtitles_rounded,
        'action': 'Manage Subtitles',
        'onTap': () => controller.setSelectedIndex(10),
      });
    }

    return recs;
  }

  @override
  Widget build(BuildContext context) {
    final recommendations =
        generateRecommendations(channel, videos, stats, controller);

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recommendations',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Text(
                '${recommendations.length}',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.05 : (isTablet ? 1.25 : 1.45),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recommendations.length,
          itemBuilder: (context, index) {
            final rec = recommendations[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 150)),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final onTap = recommendation['onTap'];
            if (onTap is VoidCallback) {
              onTap();
            }
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceHover,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    recommendation['icon'] as IconData,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  recommendation['title'] as String,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    recommendation['description'] as String,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
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
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      recommendation['action'] as String,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
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
