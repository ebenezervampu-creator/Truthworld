import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_widgets.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart' show DashboardController;
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'content/content_widgets.dart';

class ContentScreen extends StatelessWidget {
  const ContentScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
    this.searchQuery = '',
  });

  final String channelId;
  final bool isDarkMode;
  final String searchQuery;

  VideoManagementController get controller {
    final ctrl = Get.isRegistered<VideoManagementController>()
        ? Get.find<VideoManagementController>()
        : Get.put(VideoManagementController());
    ctrl.ensureInitialized(channelId);
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          toolbarHeight: 0, // Hide the app bar title portion, only keep TabBar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      isScrollable: true,
                      indicatorColor: AppColors.brand,
                      indicatorWeight: 3,
                      labelColor: AppColors.textPrimary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: const [
                        Tab(text: 'Videos'),
                        Tab(text: 'Posts'),
                        Tab(text: 'Drafts'),
                        Tab(text: 'Scheduled'),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Trash & Restore',
                    child: TextButton.icon(
                      onPressed: () {
                        if (Get.isRegistered<DashboardController>()) {
                          Get.find<DashboardController>().setSelectedIndex(13);
                        } else {
                          Get.to<dynamic>(
                            () => TrashRestoreScreen(
                              channelId: channelId,
                              isDarkMode: isDarkMode,
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.auto_delete_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Trash',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.bgInput,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.bgDivider),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            VideosTab(controller: controller, isDarkMode: isDarkMode, searchQuery: searchQuery),
            PostsTab(controller: controller, searchQuery: searchQuery),
            DraftsTab(channelId: channelId, isDarkMode: isDarkMode, controller: controller, searchQuery: searchQuery),
            ScheduledTab(controller: controller, searchQuery: searchQuery),
          ],
        ),
      ),
    );
  }
}
