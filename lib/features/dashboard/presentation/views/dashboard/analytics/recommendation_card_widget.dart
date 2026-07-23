import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class RecommendationItem {

  RecommendationItem({
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.accentColor,
  });
  final String title;
  final String description;
  final String category; // 'Performance' | 'Discoverability' | 'Thumbnail' | 'SEO' | 'Cadence'
  final IconData icon;
  final Color accentColor;
}

class RecommendationCardWidget extends StatelessWidget {

  const RecommendationCardWidget({
    required this.isDarkMode, super.key,
    this.items,
  });
  final bool isDarkMode;
  final List<RecommendationItem>? items;

  List<RecommendationItem> get defaultRecommendations => [
        RecommendationItem(
          title: 'Optimize Title Keywords for Search',
          description:
              'Including specific topic tags in your video titles increased click-through rate by 18% in your last 3 uploads.',
          category: 'SEO',
          icon: Icons.search,
          accentColor: const Color(0xFF3B82F6),
        ),
        RecommendationItem(
          title: 'High Audience Drop-off at 01:45',
          description:
              'Consider adding a hook or visual transition around the 1:30 mark to retain viewers longer.',
          category: 'Performance',
          icon: Icons.trending_up,
          accentColor: const Color(0xFFEF4444),
        ),
        RecommendationItem(
          title: 'Thumbnail Contrast Enhancement',
          description:
              'Thumbnails with bright facial expressions & bold text overlays perform 24% better in topic recommendation feeds.',
          category: 'Thumbnail',
          icon: Icons.image_search,
          accentColor: const Color(0xFFF59E0B),
        ),
        RecommendationItem(
          title: 'Optimal Upload Window Identified',
          description:
              'Your subscriber base is most active on Wednesdays & Saturdays between 5:00 PM and 8:00 PM.',
          category: 'Cadence',
          icon: Icons.schedule,
          accentColor: const Color(0xFF10B981),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final list = (items != null && items!.isNotEmpty) ? items! : defaultRecommendations;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1D24) : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.textPrimary.withValues(alpha: 0.08) : AppColors.bgPage.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommendation Intelligence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'AI-driven insights to boost channel reach',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = list[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF222630) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: item.accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage,
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
