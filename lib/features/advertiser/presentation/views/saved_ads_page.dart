import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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
                    'Your liked, bookmarked, and commented advertiser sponsor layers',
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
                  Tab(icon: Icon(Icons.chat_bubble_rounded), text: 'Comments'),
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
                  _buildCommentsTab(),
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
      final savedAds = AdService.to.customCampaigns
          .where((ad) => savedIds.contains(ad.id) && ad.status == 'active')
          .toList();

      if (savedAds.isEmpty) {
        return _buildEmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No Bookmarks Yet',
          subtitle: 'Ads you save while browsing will appear here.',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: savedAds.length,
        itemBuilder: (context, index) {
          final ad = savedAds[index];
          return ScrollAdCard(ad: ad);
        },
      );
    });
  }

  Widget _buildLikedTab() {
    return Obx(() {
      final likedIds = AdService.to.likedAdIds;
      final likedAds = AdService.to.customCampaigns
          .where((ad) => likedIds.contains(ad.id) && ad.status == 'active')
          .toList();

      if (likedAds.isEmpty) {
        return _buildEmptyState(
          icon: Icons.thumb_up_alt_outlined,
          title: 'No Liked Ads',
          subtitle: 'Give a thumbs up to ads you support to view them here.',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: likedAds.length,
        itemBuilder: (context, index) {
          final ad = likedAds[index];
          return ScrollAdCard(ad: ad);
        },
      );
    });
  }

  Widget _buildCommentsTab() {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      return _buildEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign In Required',
        subtitle: 'Please sign in to view your commented ads.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ad_comments')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.warning),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No Comments Made',
            subtitle: 'Comment on video or banner ads to track responses.',
          );
        }

        final comments = docs
            .map((doc) => AdComment.fromMap(doc.data(), doc.id))
            .toList();
        comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            final ad = AdService.to.customCampaigns.firstWhereOrNull(
              (a) => a.id == comment.adId,
            );

            if (ad == null) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ad Detail Summary
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: ad.gradientColors),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: AppColors.textPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ad.advertiser,
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              ad.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.textTertiary,
                          size: 14,
                        ),
                        onPressed: () =>
                            AdService.to.showAdPromoDialog(context, ad),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.bgDivider, height: 24),

                  // User's Comment
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Comment:',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            ClickableUrlText(
                              text: comment.text,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Advertiser Reply (if present)
                  if (comment.replyText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.campaign_rounded,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${comment.repliedBy ?? 'Sponsor'} (Advertiser Reply)',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClickableUrlText(
                            text: comment.replyText!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
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
