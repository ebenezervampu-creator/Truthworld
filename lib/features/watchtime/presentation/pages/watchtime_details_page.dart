import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/watchtime/presentation/controllers/watchtime_details_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchtimeDetailsPage extends StatelessWidget {
  const WatchtimeDetailsPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
    this.video,
  });

  final String channelId;
  final bool isDarkMode;
  final Video? video;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      WatchtimeDetailsController(channelId: channelId),
      tag: channelId.isNotEmpty ? channelId : 'default_watchtime',
    );

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'Watchtime Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.appBarSurface,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Obx(() {
        if (controller.isLoading && controller.videoItems.isEmpty) {
          return const StudioLoadingIndicator(
            message: 'Loading watch time details...',
          );
        }

        if (controller.isError) {
          return Center(
            child: Text(
              controller.errorMessage.isNotEmpty
                  ? controller.errorMessage
                  : 'Unable to load watch time details. Please try again later.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        if (controller.videoItems.isEmpty) {
          return const Center(
            child: Text(
              'No videos found.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          itemCount: controller.videoItems.length,
          itemBuilder: (context, index) {
            final item = controller.videoItems[index];
            return Card(
              color: AppColors.bgSurface,
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: ListTile(
                title: Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      'Total Views: ${item.totalViews}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Unique Users: ${item.uniqueUsers}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Total Watch Seconds: ${item.totalWatchSeconds}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Avg Watch Seconds: ${item.avgWatchSeconds.toStringAsFixed(1)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Completion Rate: ${item.completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Full Watched: ${item.fullWatched}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Half Watched: ${item.halfWatched}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Under 20 Sec: ${item.under20Sec}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
