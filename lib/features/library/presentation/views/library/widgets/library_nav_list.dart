import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_profile_header.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Navigation list displaying profile header, empty states, and library entry points.
class LibraryNavList extends StatelessWidget {
  const LibraryNavList({
    required this.userId,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final String userId;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Profile Header
          SliverToBoxAdapter(
            child: LibraryProfileHeader(userId: userId),
          ),

          // 2. Main Navigation Tiles & Dynamic Empty State
          Obx(() {
            final hasHome = Get.isRegistered<HomeController>();
            final homeController = hasHome ? Get.find<HomeController>() : null;
            final authService = AuthService.to;
            final hasChannel = authService.hasChannel.value;

            final isLibraryEmpty = homeController != null &&
                !homeController.hasWatchHistory.value &&
                !homeController.hasPlaylists.value &&
                !homeController.hasFollowedTopics.value &&
                !homeController.hasLikedVideos.value &&
                !homeController.hasClips.value &&
                !homeController.hasUploadedVideos.value;

            final items = <Widget>[];

            // If library is empty, show empty placeholder
            if (isLibraryEmpty) {
              items.add(
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open_outlined,
                        size: 64,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your library is empty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasChannel
                            ? 'Configure your settings to get started.'
                            : 'Configure your settings or create a channel to get started.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                AppNavigator.toSettings();
                              },
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 18,
                                color: primaryText,
                              ),
                              label: const Text(
                                'Settings',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryText,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: buttonBg,
                                side: BorderSide(
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          if (!hasChannel) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  AppNavigator.toChannelWizard();
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                  color: primaryText,
                                ),
                                label: const Text(
                                  'Create Channel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: primaryText,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: buttonBg,
                                  side: BorderSide(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
              items.add(const Divider());
            }

            // Always display the Text and icon for every Tab
            items.addAll([
              const LibraryListTile(
                icon: Icons.history_rounded,
                title: 'History',
                onTap: AppNavigator.toWatchHistory,
              ),
              const LibraryListTile(
                icon: Icons.video_collection_outlined,
                title: 'My videos',
                onTap: AppNavigator.toMyVideos,
              ),
              LibraryListTile(
                icon: Icons.subscriptions_outlined,
                title: 'Subscriptions',
                onTap: () {
                  if (Get.isRegistered<HomeController>()) {
                    Get.find<HomeController>().onSideNavItemSelect(
                      HomeController.indexSubscriptions,
                    );
                  } else {
                    AppNavigator.toSubscriptions();
                  }
                },
              ),
              const LibraryListTile(
                icon: Icons.playlist_play_rounded,
                title: 'Playlists',
                onTap: AppNavigator.toPlaylists,
              ),
              const LibraryListTile(
                icon: Icons.people_outline_rounded,
                title: 'Following Topics',
                onTap: AppNavigator.toFollowingTopics,
              ),
              const LibraryListTile(
                icon: Icons.thumb_up_outlined,
                title: 'Liked videos',
                onTap: AppNavigator.toLikedVideos,
              ),
              const LibraryListTile(
                icon: Icons.bookmark_outline_rounded,
                title: 'Saved posts',
                onTap: AppNavigator.toSavedPosts,
              ),
              const LibraryListTile(
                icon: Icons.comment_outlined,
                title: 'Saved comments',
                onTap: AppNavigator.toSavedComments,
              ),
              const LibraryListTile(
                icon: Icons.content_cut_rounded,
                title: 'Clips',
                onTap: AppNavigator.toClips,
              ),
              const LibraryListTile(
                icon: Icons.file_download_outlined,
                title: 'Downloads',
                trailing: Icon(
                  Icons.check_circle,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                onTap: AppNavigator.toDownloads,
              ),
              const LibraryListTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: AppNavigator.toSettings,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: AppColors.bgDivider, height: 1),
              ),
              Obx(() {
                final isPremium = AuthService.to.isPremiumUser.value;
                final planId = AuthService.to.premiumPlanId.value;
                var planLabel = 'Premium Taken';
                if (planId == 'audio_monthly') {
                  planLabel = r'Premium Taken ($0.50 Audio)';
                } else if (planId == 'individual_monthly') {
                  planLabel = r'Premium Taken ($2 Premium)';
                } else if (planId == '4k_factchecked_monthly') {
                  planLabel = r'Premium Taken ($3 Fact-Checked)';
                } else if (planId == 'family_monthly') {
                  planLabel = r'Premium Taken ($5 Family)';
                }

                return LibraryListTile(
                  icon: isPremium
                      ? Icons.workspace_premium
                      : Icons.workspace_premium_outlined,
                  title: isPremium ? planLabel : 'Get Premium',
                  trailing: isPremium
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successContainer,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: AppNavigator.toPremium,
                );
              }),
              if (!hasChannel)
                const LibraryListTile(
                  icon: Icons.add_circle_outline,
                  title: 'Create Channel to upload videos',
                  onTap: AppNavigator.toChannelWizard,
                ),
            ]);

            return SliverList(
              delegate: SliverChildListDelegate(items),
            );
          }),
        ],
      ),
    );
  }
}

/// Reusable list tile component in Library navigation.
class LibraryListTile extends StatelessWidget {
  const LibraryListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.textPrimary,
                size: 24,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
