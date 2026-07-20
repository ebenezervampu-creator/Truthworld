import 'package:truthworld/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';


// ==========================================================================
// YOUTUBE-STYLE THEME COLORS (Standardized)
// ==========================================================================

final Color bgColor = Colors.black;
final Color surfaceColor = AppColors.bgPage;
final Color cardColor = const Color(0xFF1E1E1E);
final Color primaryText = Colors.white;
final Color secondaryText = AppColors.textSecondary;
final Color buttonBg = AppColors.bgSurfaceHover;

class WatchHistory extends StatefulWidget {
  final bool isDashboard;
  const WatchHistory({super.key, this.isDashboard = false});

  @override
  State<WatchHistory> createState() => _WatchHistoryState();
}

class _WatchHistoryState extends State<WatchHistory>
    with TickerProviderStateMixin {
  late final WatchHistoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(WatchHistoryController());
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        if (widget.isDashboard) {
                          Get.find<HomeController>().sideNavSelectedIndex.value = HomeController.indexLibrary;
                        } else {
                          Get.back();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Watch history',
                      style: GoogleFonts.roboto(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.search, color: primaryText),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, color: primaryText),
                      onPressed: _showHistorySettingsBottomSheet,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
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
              return SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No watch history found',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            final List<Video> videos = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Video(
                id: data['videoId'] ?? doc.id,
                channelId: data['channelId'] ?? '',
                channelName: data['channelName'] ?? '',
                channelAvatarUrl: data['channelImage'] ?? '',
                title: data['title'] ?? 'Unknown Video',
                description: data['description'] ?? '',
                thumbnailUrl: data['thumbnailUrl'] ?? '',
                videoUrl: data['videoUrl'] ?? '',
                ownerId: data['ownerId'] ?? '',
                views: data['views'] ?? 0,
                likeCount: data['likeCount'] ?? 0,
                duration: data['duration'] ?? '0:00',
                uploadedAt:
                    (data['watchedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                language: data['language'] ?? 'en',
                category: data['category'] ?? 'General',
                tags: List<String>.from(data['tags'] ?? []),
                factCheckUrl: data['factCheckUrl'] ?? '',
                mediaSubtitles: {},
                audioTracks: {},
                chapters: [],
              );
            }).toList();

            return Obx(() {
              List<Video> displayVideos = List.from(videos);

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

              return SliverList(
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
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ),
                      ...dateVideos.map(
                        (video) => _WatchHistoryListCard(video: video),
                      ),
                    ],
                  );
                }, childCount: groupedVideos.length),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Podcasts', 'Music', 'Gaming', 'News'];
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
                selectedColor: Colors.white,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: GoogleFonts.roboto(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          Text(
            'Sign in to see your history',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Get.toNamed('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showHistorySettingsBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
            Text(
              'History Settings',
              style: GoogleFonts.roboto(
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
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _controller.isHistoryPaused.value
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: _controller.isHistoryPaused.value
                        ? Colors.orange
                        : Colors.blue,
                  ),
                ),
                title: Text(
                  'Pause Watch History',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
                subtitle: Text(
                  _controller.isHistoryPaused.value
                      ? 'Your viewing history is currently paused'
                      : 'New videos you watch will be saved to your history',
                  style: GoogleFonts.roboto(color: secondaryText),
                ),
                trailing: Switch.adaptive(
                  value: _controller.isHistoryPaused.value,
                  onChanged: (_) => _controller.toggleHistoryPaused(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.grey[800],
                ),
              ),
            ),
            const Divider(height: 32, color: Colors.white12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  color: Colors.orange,
                ),
              ),
              title: Text(
                'Clear Last 24 Hours',
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
              onTap: () {
                Get.back();
                _controller.deleteLast24Hours();
              },
            ),
            const Divider(height: 32, color: Colors.white12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.red,
                ),
              ),
              title: Text(
                'Clear All History',
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
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
  final Video video;
  const _WatchHistoryListCard({required this.video});

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
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: Colors.white,
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
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: primaryText,
                          size: 18,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channelName} • ${video.views} views',
                    style: GoogleFonts.roboto(
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






