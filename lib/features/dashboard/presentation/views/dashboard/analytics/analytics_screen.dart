import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';

class AnalyticsScreen extends StatelessWidget {
  final String channelId;
  final bool isDarkMode;

  const AnalyticsScreen({
    super.key,
    required this.channelId,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final AnalyticsController controller = Get.put(
      AnalyticsController(channelId: channelId),
    );

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(child: Text('Error: ${controller.errorMessage.value}'));
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Channel Analytics',
                style: GoogleFonts.roboto(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 32),
              _buildTopVideosSection(controller.topVideos),
              SizedBox(height: 16),
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
              SizedBox(height: 32),
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
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16),
        if (topVideos.isEmpty)
          Text(
            'No video data available yet.',
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: topVideos.length,
            separatorBuilder: (context, index) => Divider(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
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
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${NumberFormat.compact().format(video.views)} views',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
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






