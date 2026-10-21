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
      child: ColoredBox(
        color: AppColors.bgPage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.bgDivider,
                  ),
                ),
              ),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3.0,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelPadding: EdgeInsets.symmetric(horizontal: 16.0),
                labelStyle: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                tabs: [
                  Tab(text: 'Videos', height: 46),
                  Tab(text: 'Community', height: 46),
                  Tab(text: 'Drafts', height: 46),
                  Tab(text: 'Scheduled', height: 46),
                  Tab(text: 'Trash', height: 46),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  VideosTab(
                    controller: controller,
                    isDarkMode: isDarkMode,
                    searchQuery: searchQuery,
                  ),
                  PostsTab(
                    controller: controller,
                    searchQuery: searchQuery,
                  ),
                  DraftsTab(
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                    controller: controller,
                    searchQuery: searchQuery,
                  ),
                  ScheduledTab(
                    controller: controller,
                    searchQuery: searchQuery,
                  ),
                  TrashTab(
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                    searchQuery: searchQuery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
