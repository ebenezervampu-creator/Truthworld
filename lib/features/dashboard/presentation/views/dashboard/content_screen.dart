import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_widgets.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'content/content_widgets.dart';

class ContentScreen extends StatelessWidget {
  const ContentScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
    this.searchQuery = '',
    this.initialIndex = 0,
  });

  final String channelId;
  final bool isDarkMode;
  final String searchQuery;
  final int initialIndex;

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
      length: 5,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgPage,
          elevation: 0,
          toolbarHeight: 0, // Hide the app bar title portion, only keep TabBar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.bgDivider),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TabBar(
                isScrollable: true,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: TWTypography.brandFamily,
                ),
                unselectedLabelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: 'Videos'),
                  Tab(text: 'Posts'),
                  Tab(text: 'Drafts'),
                  Tab(text: 'Scheduled'),
                  Tab(text: 'Trash'),
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
            TrashTab(channelId: channelId, isDarkMode: isDarkMode, searchQuery: searchQuery),
          ],
        ),
      ),
    );
  }
}
