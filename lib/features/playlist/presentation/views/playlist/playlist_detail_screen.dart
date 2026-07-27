import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// APP THEME COLORS & DESIGN TOKENS
// ==========================================================================
const Color ytBackground = AppColors.bgPage;
const Color ytSurface = AppColors.bgSurface;
const Color ytSurfaceLight = AppColors.bgSurfaceHover;
const Color ytSurfaceHover = AppColors.bgSurfaceHigh;
const Color ytTextPrimary = AppColors.textPrimary;
const Color ytTextSecondary = AppColors.textSecondary;
const Color ytTextTertiary = AppColors.textTertiary;
const Color ytRed = AppColors.brand;
const Color ytBorder = AppColors.searchBorder;

// ==========================================================================
// PLAYLIST DETAIL SCREEN
// ==========================================================================
class PlaylistDetailScreen extends GetView<PlaylistDetailController> {
  const PlaylistDetailScreen({super.key, this.playlist});
  final PlaylistModel? playlist;

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already registered
    if (!Get.isRegistered<PlaylistDetailController>()) {
      Get.put(PlaylistDetailController());
    }

    var activePlaylist = playlist;

    if (activePlaylist == null) {
      final args = Get.arguments;
      if (args != null) {
        if (args is PlaylistModel) {
          activePlaylist = args;
        } else if (args is Map && args['playlist'] is PlaylistModel) {
          activePlaylist = args['playlist'];
        }
      }
    }

    if (activePlaylist == null && Get.isRegistered<HomeController>()) {
      final rawPlaylist = Get.find<HomeController>().selectedPlaylist.value;
      if (rawPlaylist is PlaylistModel) {
        activePlaylist = rawPlaylist;
      }
    }

    if (activePlaylist == null) {
      return Scaffold(
        backgroundColor: ytBackground,
        appBar: AppBar(
          backgroundColor: ytBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: ytTextPrimary),
            onPressed: Get.back,
          ),
          title: const Text(
            'Playlist',
            style: TextStyle(
              color: ytTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _buildErrorState('Playlist data is missing.', Get.back),
      );
    }

    controller.reset();

    return Scaffold(
      backgroundColor: ytBackground,
      appBar: AppBar(
        backgroundColor: ytBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ytTextPrimary),
          onPressed: Get.back,
        ),
        title: Text(
          activePlaylist.playlistName,
          style: const TextStyle(
            color: ytTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildContent(context, activePlaylist),
    );
  }

  Widget _buildContent(BuildContext context, PlaylistModel playlist) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

        if (isDesktop) {
          return _buildDesktopLayout(context, playlist);
        } else {
          return _buildMobileTabletLayout(context, playlist, isTablet: isTablet);
        }
      },
    );
  }

  // ==========================================================================
  // DESKTOP LAYOUT (2-column: sidebar + video list)
  // ==========================================================================
  Widget _buildDesktopLayout(BuildContext context, PlaylistModel playlist) {
    return Row(
      children: [
        // Left sidebar with playlist info
        Container(
          width: 360,
          color: ytSurface,
          child: _buildPlaylistSidebar(context, playlist, isDesktop: true),
        ),
        // Right side video list
        Expanded(
          child: _buildVideoListSection(context, playlist, isDesktop: true),
        ),
      ],
    );
  }

  // ==========================================================================
  // MOBILE/TABLET LAYOUT (stacked)
  // ==========================================================================
  Widget _buildMobileTabletLayout(BuildContext context, PlaylistModel playlist, {bool isTablet = false}) {
    return CustomScrollView(
      slivers: [
        // Playlist header section
        SliverToBoxAdapter(
          child: _buildPlaylistHeader(context, playlist, isTablet: isTablet),
        ),
        // Filter tabs
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterTabDelegate(
            _buildFilterTabs(),
            maxHeight: 48,
          ),
        ),
        // Video list
        SliverToBoxAdapter(
          child: _buildVideoList(context, playlist, isTablet: isTablet),
        ),
      ],
    );
  }

  // ==========================================================================
  // PLAYLIST SIDEBAR (Desktop)
  // ==========================================================================
  Widget _buildPlaylistSidebar(BuildContext context, PlaylistModel playlist, {bool isDesktop = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large thumbnail
          _buildLargeThumbnail(playlist),
          const SizedBox(height: 20),
          // Playlist title
          Text(
            playlist.playlistName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ytTextPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Channel name with avatar
          _buildChannelInfo(playlist),
          const SizedBox(height: 12),
          // Stats
          _buildPlaylistStats(playlist),
          const SizedBox(height: 24),
          // Action buttons
          _buildActionButtons(context, playlist, isDesktop: true),
          const SizedBox(height: 16),
          // Description
          if (playlist.description.isNotEmpty)
            _buildDescription(playlist),
        ],
      ),
    );
  }

  // ==========================================================================
  // PLAYLIST HEADER (Mobile/Tablet)
  // ==========================================================================
  Widget _buildPlaylistHeader(BuildContext context, PlaylistModel playlist, {bool isTablet = false}) {
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          _buildThumbnail(playlist, isTablet: isTablet),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.playlistName,
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 20,
                    fontWeight: FontWeight.w700,
                    color: ytTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildChannelInfo(playlist),
                const SizedBox(height: 8),
                _buildPlaylistStats(playlist),
                const SizedBox(height: 16),
                _buildActionButtons(context, playlist, isTablet: isTablet),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // THUMBNAIL WIDGETS
  // ==========================================================================
  Widget _buildLargeThumbnail(PlaylistModel playlist) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: ytSurfaceLight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: playlist.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: playlist.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildThumbnail(PlaylistModel playlist, {bool isTablet = false}) {
    final width = isTablet ? 200.0 : 160.0;
    
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: ytSurfaceLight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: playlist.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: playlist.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildPlaceholder(),
                    errorWidget: (context, url, error) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: ytSurfaceLight,
      child: Center(
        child: Icon(
          Icons.playlist_play,
          size: 48,
          color: ytTextTertiary,
        ),
      ),
    );
  }

  // ==========================================================================
  // CHANNEL INFO
  // ==========================================================================
  Widget _buildChannelInfo(PlaylistModel playlist) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('channels')
          .doc(playlist.channelId)
          .get(),
      builder: (context, snapshot) {
        var channelName = 'Unknown Channel';
        var avatarUrl = '';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final channelData = snapshot.data!.data()! as Map<String, dynamic>;
          channelName = (channelData['name'] ?? channelData['channelName']) ?? 'Unknown Channel';
          avatarUrl = channelData['avatarUrl'] ?? '';
        }

        return InkWell(
          onTap: () {
            // Navigate to channel
          },
          child: Row(
            children: [
              UserAvatar(
                radius: 16,
                photoUrl: avatarUrl,
                displayName: channelName,
                backgroundColor: ytSurfaceLight,
                textColor: ytTextSecondary,
                fontSize: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  channelName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ytTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // PLAYLIST STATS
  // ==========================================================================
  Widget _buildPlaylistStats(PlaylistModel playlist) {
    return FutureBuilder<List<Video>>(
      future: _fetchVideos(playlist),
      builder: (context, snapshot) {
        final videoCount = playlist.videoCount;
        final viewCount = snapshot.hasData 
            ? snapshot.data!.fold<int>(0, (total, v) => total + v.views)
            : 0;
        final lastUpdated = timeago.format(playlist.updatedAt.toDate());

        return Text(
          '$videoCount videos • ${_formatViews(viewCount)} views • Updated $lastUpdated',
          style: const TextStyle(
            fontSize: 12,
            color: ytTextTertiary,
          ),
        );
      },
    );
  }

  // ==========================================================================
  // ACTION BUTTONS
  // ==========================================================================
  Widget _buildActionButtons(BuildContext context, PlaylistModel playlist, {bool isDesktop = false, bool isTablet = false}) {
    return Row(
      children: [
        // Play all button (white)
        Expanded(
          flex: 2,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: ytTextPrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _playAllVideos(playlist),
                borderRadius: BorderRadius.circular(18),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, color: ytBackground, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Play all',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ytBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Shuffle button (dark)
        Expanded(
          flex: 2,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: ytSurfaceLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _shuffleVideos(playlist),
                borderRadius: BorderRadius.circular(18),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shuffle, color: ytTextPrimary, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Shuffle',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ytTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 8),
          // Download button (circular)
          _buildActionButtonIcon(
            icon: Icons.download,
            onTap: () => _downloadPlaylist(playlist),
            tooltip: 'Download',
          ),
          const SizedBox(width: 8),
          // Share button (circular)
          _buildActionButtonIcon(
            icon: Icons.share,
            onTap: () {
              Get.find<MainController>().sharePlaylist(
                playlist.id,
                playlist.playlistName,
                thumbnailUrl: playlist.thumbnailUrl,
              );
            },
            tooltip: 'Share',
          ),
        ] else ...[
          const SizedBox(width: 8),
          // Share button for mobile/tablet
          _buildActionButtonIcon(
            icon: Icons.share,
            onTap: () {
              Get.find<MainController>().sharePlaylist(
                playlist.id,
                playlist.playlistName,
                thumbnailUrl: playlist.thumbnailUrl,
              );
            },
            tooltip: 'Share',
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtonIcon({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: ytSurfaceLight,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        type: MaterialType.circle,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              color: ytTextPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // DESCRIPTION
  // ==========================================================================
  Widget _buildDescription(PlaylistModel playlist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          playlist.description,
          style: const TextStyle(
            fontSize: 14,
            color: ytTextSecondary,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (playlist.description.length > 100)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Show more',
              style: TextStyle(
                fontSize: 12,
                color: ytTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================================================
  // FILTER TABS
  // ==========================================================================
  Widget _buildFilterTabs() {
    return Obx(() {
      final filters = ['All', 'Videos', 'Shorts'];
      final selectedFilter = controller.filterValue.value.isEmpty 
          ? 'All' 
          : controller.filterValue.value;

      return Container(
        color: ytBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: filters.map((filter) {
            final isSelected = selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    controller.setFilterValue(filter == 'All' ? '' : filter);
                  }
                },
                backgroundColor: ytSurface,
                selectedColor: ytTextPrimary,
                labelStyle: TextStyle(
                  color: isSelected ? ytBackground : ytTextPrimary,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? ytTextPrimary : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  // ==========================================================================
  // VIDEO LIST SECTION
  // ==========================================================================
  Widget _buildVideoListSection(BuildContext context, PlaylistModel playlist, {bool isDesktop = false}) {
    return Column(
      children: [
        // Filter tabs
        _buildFilterTabs(),
        const Divider(color: ytBorder, height: 1),
        // Video list
        Expanded(
          child: _buildVideoList(context, playlist, isDesktop: isDesktop),
        ),
      ],
    );
  }

  // ==========================================================================
  // VIDEO LIST
  // ==========================================================================
  Widget _buildVideoList(BuildContext context, PlaylistModel playlist, {bool isDesktop = false, bool isTablet = false}) {
    if (playlist.videoCount == 0 && playlist.videoIds.isEmpty) {
      return _buildEmptyState();
    }

    return FutureBuilder<List<Video>>(
      future: _fetchVideos(playlist),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildVideoShimmer();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorState('Failed to load videos', () => controller.setLoading(true));
        }

        final videos = snapshot.data!;
        
        // Apply filter
        final filteredVideos = videos.where((video) {
          final filter = controller.filterValue.value.toLowerCase();
          if (filter.isEmpty || filter == 'all') return true;
          if (filter == 'shorts') return video.isShort;
          if (filter == 'videos') return !video.isShort;
          return true;
        }).toList();

        if (filteredVideos.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          shrinkWrap: !isDesktop,
          physics: isDesktop
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : (isTablet ? 24 : 16),
            vertical: 8,
          ),
          itemCount: filteredVideos.length,
          itemBuilder: (context, index) {
            final video = filteredVideos[index];
            return _buildVideoListItem(
              context,
              index + 1,
              video,
              isDesktop: isDesktop,
              isTablet: isTablet,
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // VIDEO LIST ITEM (with number indicator)
  // ==========================================================================
  Widget _buildVideoListItem(
    BuildContext context,
    int index,
    Video video, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final thumbnailWidth = isDesktop ? 160.0 : (isTablet ? 200.0 : 140.0);

    return InkWell(
      onTap: () {
        MiniplayerNavigationHelper.navigateToVideoScreen(
          video: video,
          routeArguments: {'video': video},
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Duration Overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: thumbnailWidth,
                    height: thumbnailWidth * 9 / 16,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: thumbnailWidth,
                      height: thumbnailWidth * 9 / 16,
                      color: ytSurfaceLight,
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: thumbnailWidth,
                      height: thumbnailWidth * 9 / 16,
                      color: ytSurfaceLight,
                      child: const Icon(Icons.play_circle_outline, color: ytTextSecondary),
                    ),
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
            // Details (Title & Metadata)
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
                            color: ytTextPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: ytTextPrimary,
                          size: 18,
                        ),
                        onPressed: () => _showVideoOptions(context, video),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channelName} • ${_formatViews(video.views)} views',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ytTextSecondary,
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

  // ==========================================================================
  // LOADING & EMPTY STATES
  // ==========================================================================
  Widget _buildVideoShimmer({bool isDesktop = false}) {
    return Shimmer.fromColors(
      baseColor: ytSurface,
      highlightColor: ytSurfaceLight,
      child: ListView.builder(
        shrinkWrap: !isDesktop,
        physics: isDesktop
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Container(
                width: 140,
                height: 79,
                decoration: BoxDecoration(
                  color: ytSurfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, color: ytSurfaceLight),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 100, color: ytSurfaceLight),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_remove, size: 64, color: ytTextTertiary),
            SizedBox(height: 16),
            Text(
              'No videos found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: ytTextPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This playlist is empty',
              style: TextStyle(
                fontSize: 14,
                color: ytTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: ytTextTertiary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: ytTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ytTextPrimary,
                foregroundColor: ytBackground,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // ACTIONS
  // ==========================================================================
  void _playAllVideos(PlaylistModel playlist) {
    HapticFeedback.lightImpact();
    // Play all videos logic
  }

  void _shuffleVideos(PlaylistModel playlist) {
    HapticFeedback.lightImpact();
    // Shuffle play logic
  }

  void _downloadPlaylist(PlaylistModel playlist) {
    HapticFeedback.lightImpact();
    // Download logic
  }

  void _showVideoOptions(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ytSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ytTextTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: ytTextPrimary),
              title: const Text('Play next', style: TextStyle(color: ytTextPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: ytTextPrimary),
              title: const Text('Add to queue', style: TextStyle(color: ytTextPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.download, color: ytTextPrimary),
              title: const Text('Download', style: TextStyle(color: ytTextPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.share, color: ytTextPrimary),
              title: const Text('Share', style: TextStyle(color: ytTextPrimary)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================
  Future<List<Video>> _fetchVideos(PlaylistModel playlist) async {
    try {
      final playlistController = Get.find<PlaylistController>();
      var videoIds = await playlistController.fetchPlaylistVideoIds(
        playlist.id,
        playlist.isPublic,
        ownerId: playlist.ownerId,
      );

      if (videoIds.isEmpty && playlist.videoIds.isNotEmpty) {
        videoIds = playlist.videoIds;
      }

      if (videoIds.isEmpty) return [];

      final videos = <Video>[];
      const batchSize = 10;
      for (var i = 0; i < videoIds.length; i += batchSize) {
        final batchIds = videoIds.skip(i).take(batchSize).toList();
        final snapshot = await FirebaseFirestore.instance
            .collection('videos')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();
        videos.addAll(snapshot.docs.map(Video.fromDocumentSnapshot));
      }

      final videoMap = {for (final v in videos) v.id: v};
      return videoIds.map((id) => videoMap[id]).whereType<Video>().toList();
    } catch (e) {
      debugPrint('Error fetching playlist videos: $e');
      return [];
    }
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }
}

// ==========================================================================
// FILTER TAB DELEGATE
// ==========================================================================
class _FilterTabDelegate extends SliverPersistentHeaderDelegate {

  _FilterTabDelegate(this.child, {required this.maxHeight});
  final Widget child;
  final double maxHeight;

  @override
  double get minExtent => maxHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: ytBackground,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}





