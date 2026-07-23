import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/recommendation_card_widget.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {

  const AnalyticsScreen({
    required this.channelId, required this.isDarkMode, super.key,
  });
  final String channelId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      AnalyticsController(channelId: channelId),
    );

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(child: Text('Error: ${controller.errorMessage.value}'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Channel Analytics',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              RecommendationCardWidget(isDarkMode: isDarkMode),
              const SizedBox(height: 32),
              _buildTopVideosSection(controller.topVideos),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Get.to(() => const CreatorAnalyticsDashboard(),
                    arguments: {
                      'channelId': channelId,
                      'channelName': 'My Channel',
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'View Creator Analytics Dashboard',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Color(0xFFDC2626), size: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopVideosSection(List<Video> topVideos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performing Videos (by views)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? AppColors.textPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (topVideos.isEmpty)
          Text(
            'No video data available yet.',
            style: TextStyle(
              color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage54,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topVideos.length,
            separatorBuilder: (context, index) => Divider(
              color: isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
            ),
            itemBuilder: (context, index) {
              final video = topVideos[index];
              return ListTile(
                leading: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  video.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${NumberFormat.compact().format(video.views)} views',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  Get.to(() => const CreatorAnalyticsDashboard(),
                    arguments: {
                      'channelId': channelId,
                      'videoId': video.id,
                      'videoTitle': video.title,
                    },
                  );
                },
              );
            },
          ),
      ],
    );
  }
}






