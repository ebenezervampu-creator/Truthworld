import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

class SavedAdsPage extends StatefulWidget {
  const SavedAdsPage({super.key});

  @override
  State<SavedAdsPage> createState() => _SavedAdsPageState();
}

class _SavedAdsPageState extends State<SavedAdsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interacted Ads',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your liked and bookmarked advertiser sponsor layers',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.warning,
                labelColor: AppColors.warning,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.bookmark_rounded), text: 'Saved'),
                  Tab(icon: Icon(Icons.thumb_up_rounded), text: 'Liked'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSavedTab(),
                  _buildLikedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedTab() {
    return Obx(() {
      final savedIds = AdService.to.savedAdIds;
      final hiddenIds = AdService.to.hiddenAdIds;
      final savedAds = AdService.to.customCampaigns
          .where(
            (ad) =>
                savedIds.contains(ad.id) &&
                ad.status == 'active' &&
                !hiddenIds.contains(ad.id),
          )
          .toList();

      if (savedAds.isEmpty) {
        return _buildEmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No Bookmarks Yet',
          subtitle: 'Ads you save while browsing will appear here.',
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 600
                  ? 2
                  : 1;
          return MasonryGridView.count(
            padding: const EdgeInsets.all(24),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            itemCount: savedAds.length,
            itemBuilder: (context, index) {
              final ad = savedAds[index];
              return HomepageAdCard(ad: ad);
            },
          );
        },
      );
    });
  }

  Widget _buildLikedTab() {
    return Obx(() {
      final likedIds = AdService.to.likedAdIds;
      final hiddenIds = AdService.to.hiddenAdIds;
      final likedAds = AdService.to.customCampaigns
          .where(
            (ad) =>
                likedIds.contains(ad.id) &&
                ad.status == 'active' &&
                !hiddenIds.contains(ad.id),
          )
          .toList();

      if (likedAds.isEmpty) {
        return _buildEmptyState(
          icon: Icons.thumb_up_alt_outlined,
          title: 'No Liked Ads',
          subtitle: 'Give a thumbs up to ads you support to view them here.',
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 600
                  ? 2
                  : 1;
          return MasonryGridView.count(
            padding: const EdgeInsets.all(24),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            itemCount: likedAds.length,
            itemBuilder: (context, index) {
              final ad = likedAds[index];
              return HomepageAdCard(ad: ad);
            },
          );
        },
      );
    });
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
