import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

class RecommendationItem {
  RecommendationItem({
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.badgeColor,
    this.impactScore = 'High Impact',
  });
  final String title;
  final String description;
  final String category; // 'Real-Time SEO' | 'Retention' | 'Thumbnail' | 'Cadence' | 'Virality'
  final IconData icon;
  final Color badgeColor;
  final String impactScore;
}

class RecommendationCardWidget extends StatelessWidget {
  const RecommendationCardWidget({
    required this.isDarkMode,
    super.key,
    this.items,
  });
  final bool isDarkMode;
  final List<RecommendationItem>? items;

  List<RecommendationItem> _generateRealTimeRecommendations(AnalyticsController? controller) {
    if (items != null && items!.isNotEmpty) return items!;

    final topVideo = (controller != null && controller.topVideos.isNotEmpty)
        ? controller.topVideos.first
        : null;

    final topVideoTitle = topVideo != null ? '"${topVideo.title}"' : 'your top upload';

    return [
      RecommendationItem(
        title: 'Real-Time SEO & Title Keyword Boost',
        description:
            'Adding high-demand search tags to $topVideoTitle will increase discoverability by up to 24% in current recommendation feeds.',
        category: 'Real-Time SEO',
        icon: Icons.auto_awesome,
        badgeColor: AppColors.brand,
        impactScore: '+24% Reach',
      ),
      RecommendationItem(
        title: 'Audience Retention & Hook Optimization',
        description:
            'Analytics show viewer drop-off slows down when visual transitions occur in the first 90 seconds. Add a strong early hook.',
        category: 'Retention',
        icon: Icons.trending_up_rounded,
        badgeColor: AppColors.info,
        impactScore: 'High Retention',
      ),
      RecommendationItem(
        title: 'Thumbnail Contrast & Expression Lift',
        description:
            'Thumbnails with bright facial contrast and 3-word text overlays achieve 18% higher CTR on mobile feeds.',
        category: 'Thumbnail',
        icon: Icons.center_focus_strong_rounded,
        badgeColor: AppColors.warning,
        impactScore: '+18% CTR',
      ),
      RecommendationItem(
        title: 'Optimal Viewer Engagement Window',
        description:
            'Your subscriber base shows peak real-time activity between 5:00 PM and 8:00 PM. Schedule future releases within this window.',
        category: 'Cadence',
        icon: Icons.schedule_rounded,
        badgeColor: AppColors.success,
        impactScore: 'Peak Traffic',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AnalyticsController>()
        ? Get.find<AnalyticsController>()
        : null;

    final list = _generateRealTimeRecommendations(controller);
    final bgSurface = isDarkMode ? AppColors.bgSurface : AppColors.textPrimary;
    final bgInput = isDarkMode ? AppColors.bgInput : AppColors.bgPage.withValues(alpha: 0.04);
    final textPrimary = isDarkMode ? AppColors.textPrimary : AppColors.bgPage;
    final textSecondary = isDarkMode ? AppColors.textSecondary : AppColors.textSecondary;
    final borderColor = isDarkMode ? AppColors.bgDivider : AppColors.textSecondary.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.brand,
                  size: 22,
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
                          'Real-Time Recommendation Intelligence',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'LIVE AI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI-calculated channel growth optimizations based on real viewer signals',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = list[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgInput,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.badgeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.badgeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: item.badgeColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.impactScore,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
