import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart';
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart';
import 'package:truthworld/features/subscriptions/presentation/views/Subscriptions/subscriptions.dart';
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// DASHBOARD WRAPPER CONTROLLER
// ==========================================================================
class DashboardWrapperController extends GetxController {

  DashboardWrapperController({
    required this.dashboardType,
    this.initialTabIndex = 0,
  });
  final String dashboardType; // 'library', 'explore', 'following', 'support'
  final int initialTabIndex;

  late TabController tabController;
  final selectedTabIndex = 0.obs;

  List<String> get tabLabels {
    switch (dashboardType) {
      case 'library':
        return [
          'Your Library',
          'Watch Later',
          'Liked Videos',
          'Playlists',
          if (AuthService.to.hasChannel.value) 'My Videos',
          'History',
        ];
      case 'explore':
        return ['Explore Pages', 'Categories', 'Trending', 'New & Popular'];
      case 'following':
        return ['Following', 'Subscriptions', 'Channels'];
      case 'support':
        return [
          'Help & Support',
          'FAQ',
          'Contact Us',
          'Terms',
          'Privacy Policy',
        ];
      default:
        return ['Tab 1', 'Tab 2'];
    }
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void selectTab(int index) {
    selectedTabIndex.value = index;
    tabController.animateTo(index);
  }
}

// ==========================================================================
// DASHBOARD WRAPPER SCREEN
// ==========================================================================
class DashboardWrapper extends StatefulWidget {

  const DashboardWrapper({
    required this.dashboardType, super.key,
    this.initialTabIndex = 0,
  });
  final String dashboardType;
  final int initialTabIndex;

  @override
  State<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends State<DashboardWrapper>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final homeController = Get.find<HomeController>();

  @override
  void initState() {
    super.initState();
    final tabLabels = _getTabLabels();
    _tabController = TabController(
      length: tabLabels.length,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> _getTabLabels() {
    switch (widget.dashboardType) {
      case 'library':
        return [
          'Your Library',
          'Watch Later',
          'Liked Videos',
          'Playlists',
          if (AuthService.to.hasChannel.value) 'My Videos',
          'History',
        ];
      case 'explore':
        return ['Explore Pages', 'Categories', 'Trending', 'New & Popular'];
      case 'following':
        return ['Following', 'Subscriptions', 'Channels'];
      case 'support':
        return [
          'Help & Support',
          'FAQ',
          'Contact Us',
          'Terms',
          'Privacy Policy',
        ];
      default:
        return ['Tab 1', 'Tab 2'];
    }
  }

  Widget _buildTabContent(int index) {
    switch (widget.dashboardType) {
      case 'library':
        final tabs = <Widget>[
          const ColoredBox(
            color: AppColors.bgPage,
            child: Center(
              child: Text(
                'Your Library',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
            ),
          ),
          const LikedVideoScreen(),
          const PlaylistScreen(),
          if (AuthService.to.hasChannel.value) const MyVideos(),
          const WatchHistory(),
        ];
        if (index < tabs.length) {
          return tabs[index];
        }
        return const SizedBox.shrink();
      case 'explore':
        return ColoredBox(
          color: AppColors.bgPage,
          child: Center(
            child: Text(
              'Explore Pages - Tab ${index + 1}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ),
        );
      case 'following':
        switch (index) {
          case 0:
            return const ColoredBox(
              color: AppColors.bgPage,
              child: Center(
                child: Text(
                  'Following',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
                ),
              ),
            );
          case 1:
            return SubscriptionsPage();
          case 2:
            return const ColoredBox(
              color: AppColors.bgPage,
              child: Center(
                child: Text(
                  'Channels',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
                ),
              ),
            );
          default:
            return const SizedBox.shrink();
        }
      case 'support':
        return ColoredBox(
          color: AppColors.bgPage,
          child: Center(
            child: Text(
              'Support - Tab ${index + 1}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tabLabels = _getTabLabels();

      // If tab count changed, we need a new TabController
      if (_tabController.length != tabLabels.length) {
        _tabController.dispose();
        _tabController = TabController(
          length: tabLabels.length,
          vsync: this,
          initialIndex: widget.initialTabIndex.clamp(0, tabLabels.length - 1),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgInput,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _getAppBarTitle(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE8E8E8),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFB8B8B8)),
            onPressed: Get.back,
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF1976D2),
            unselectedLabelColor: const Color(0xFFB8B8B8),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
            indicatorColor: const Color(0xFF1976D2),
            indicatorWeight: 3,
            tabs: tabLabels.map((label) => Tab(text: label)).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: List.generate(
            tabLabels.length,
            _buildTabContent,
          ),
        ),
      );
    });
  }

  String _getAppBarTitle() {
    switch (widget.dashboardType) {
      case 'library':
        return 'Your Library';
      case 'explore':
        return 'Explore';
      case 'following':
        return 'Following';
      case 'support':
        return 'Help & Support';
      default:
        return 'Dashboard';
    }
  }
}







