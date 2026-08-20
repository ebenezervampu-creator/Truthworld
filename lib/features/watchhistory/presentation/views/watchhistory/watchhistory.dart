import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// YOUTUBE-STYLE THEME COLORS (Standardized)
// ==========================================================================

const Color bgColor = AppColors.bgPage;
const Color surfaceColor = AppColors.bgPage;
const Color cardColor = Color(0xFF1E1E1E);
const Color primaryText = AppColors.textPrimary;
const Color secondaryText = AppColors.textSecondary;
const Color buttonBg = AppColors.bgSurfaceHover;

class WatchHistory extends StatefulWidget {
  const WatchHistory({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<WatchHistory> createState() => _WatchHistoryState();
}

class _WatchHistoryState extends State<WatchHistory>
    with TickerProviderStateMixin {
  late final WatchHistoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<WatchHistoryController>();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(child: _buildNotLoggedInWidget(context)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: _buildMainContent(userId)),
    );
  }

  Widget _buildMainContent(String userId) {
    return CustomScrollView(
      controller: _controller.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, widget.isDashboard ? 16 : 48, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () {
                          if (widget.isDashboard) {
                            Get.find<HomeController>()
                                    .sideNavSelectedIndex
                                    .value =
                                HomeController.indexLibrary;
                          } else {
                            Get.back();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Watch history',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: primaryText),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: primaryText),
                  onPressed: _showHistorySettingsBottomSheet,
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(userId)
              .collection('watch_history')
              .orderBy('watchedAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const ShimmerVideoListCard(),
                  childCount: 6,
                ),
              );
            }

            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No watch history found',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            }

            final videos = snapshot.data!.docs.map((doc) {
              final data = doc.data()! as Map<String, dynamic>;
              final durationRaw =
                  (data['duration'] != null &&
                      data['duration'] != '0:00' &&
                      data['duration'] != '00:00')
                  ? data['duration']
                  : (data['videoDuration'] ?? data['durationMs']);
              return Video(
                id: (data['videoId'] as String?) ?? doc.id,
                channelId: (data['channelId'] as String?) ?? '',
                channelName: (data['channelName'] as String?) ?? '',
                channelAvatarUrl:
                    (data['channelImage'] as String?) ??
                    (data['channelAvatarUrl'] as String?) ??
                    '',
                title: (data['title'] as String?) ?? 'Unknown Video',
                description: (data['description'] as String?) ?? '',
                thumbnailUrl: (data['thumbnailUrl'] as String?) ?? '',
                videoUrl: (data['videoUrl'] as String?) ?? '',
                ownerId: (data['ownerId'] as String?) ?? '',
                views: (data['views'] as int?) ?? 0,
                likeCount: (data['likeCount'] as int?) ?? 0,
                duration: durationRaw,
                uploadedAt:
                    (data['watchedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                language: (data['language'] as String?) ?? 'en',
                category: (data['category'] as String?) ?? 'General',
                tags: List<String>.from(
                  (data['tags'] as Iterable<dynamic>?) ?? [],
                ),
                factCheckUrl: (data['factCheckUrl'] as String?) ?? '',
                mediaSubtitles: {},
                audioTracks: {},
                chapters: [],
              );
            }).toList();

            final categoriesSet = <String>{'All'};
            for (final v in videos) {
              if (v.category.isNotEmpty) {
                categoriesSet.add(v.category);
              }
            }
            final categories = categoriesSet.toList();

            return Obx(() {
              var displayVideos = List<Video>.from(videos);

              // Filter by category
              if (_controller.selectedCategory.value != 'All') {
                displayVideos = displayVideos
                    .where(
                      (v) => v.category == _controller.selectedCategory.value,
                    )
                    .toList();
              }

              final groupedVideos = _controller.groupVideosByDate(
                displayVideos,
              );

              return SliverMainAxisGroup(
                slivers: [
                  if (categories.length > 1)
                    SliverToBoxAdapter(child: _buildCategoryChips(categories)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final dateKey = groupedVideos.keys.elementAt(index);
                      final dateVideos = groupedVideos[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                            child: Text(
                              dateKey,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                          ),
                          ...dateVideos.map(
                            (video) => _WatchHistoryListCard(
                              video: video,
                              controller: _controller,
                            ),
                          ),
                        ],
                      );
                    }, childCount: groupedVideos.length),
                  ),
                ],
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Obx(() {
            final isSelected = _controller.selectedCategory.value == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) _controller.setCategory(category);
                },
                selectedColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildNotLoggedInWidget(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.history_rounded,
                size: 80,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign in to see your history',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Get.toNamed('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistorySettingsBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: secondaryText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'History Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _controller.isHistoryPaused.value
                        ? AppColors.warning.withValues(alpha: 0.1)
                        : AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _controller.isHistoryPaused.value
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: _controller.isHistoryPaused.value
                        ? AppColors.warning
                        : AppColors.info,
                  ),
                ),
                title: const Text(
                  'Pause Watch History',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
                subtitle: Text(
                  _controller.isHistoryPaused.value
                      ? 'Your viewing history is currently paused'
                      : 'New videos you watch will be saved to your history',
                  style: const TextStyle(color: secondaryText),
                ),
                trailing: Switch.adaptive(
                  value: _controller.isHistoryPaused.value,
                  onChanged: (_) => _controller.toggleHistoryPaused(),
                  activeThumbColor: AppColors.textPrimary,
                  activeTrackColor: AppColors.textSecondary,
                ),
              ),
            ),
            const Divider(height: 32, color: AppColors.bgDivider),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  color: AppColors.warning,
                ),
              ),
              title: const Text(
                'Clear Last 24 Hours',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
              onTap: () {
                Get.back();
                _controller.deleteLast24Hours();
              },
            ),
            const Divider(height: 32, color: AppColors.bgDivider),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: AppColors.error,
                ),
              ),
              title: const Text(
                'Clear All History',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
              onTap: () {
                Get.back();
                _controller.clearAllHistory();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _WatchHistoryListCard extends StatelessWidget {
  const _WatchHistoryListCard({required this.video, required this.controller});
  final Video video;
  final WatchHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.toNamed('/watch?v=${video.id}', arguments: {'video': video});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.bgSurfaceHover),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.bgSurfaceHover),
                  ),
                ),
                // Duration overlay
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: primaryText,
                          size: 18,
                        ),
                        onPressed: () {
                          VideoOptionsSheet.show(
                            context,
                            video,
                            onRemoveFromHistory: () =>
                                controller.deleteHistoryItem(video.id),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channelName} • ${video.views} views',
                    style: const TextStyle(
                      fontSize: 13,
                      color: secondaryText,
                    ),
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
