import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/playlist_navigation.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modernized Playlists Management Tab for Truthworld Studio.
/// Visual architecture, fonts, colors, and layout fully aligned with Studio standards.
class PlaylistsManagementScreen extends StatelessWidget {
  const PlaylistsManagementScreen({
    super.key,
    this.channelId,
    this.isDarkMode = true,
    this.searchQuery = '',
  });

  final String? channelId;
  final bool isDarkMode;
  final String searchQuery;

  BuildContext get context => Get.context!;

  PlaylistsManagementController get _controller =>
      Get.isRegistered<PlaylistsManagementController>()
          ? Get.find<PlaylistsManagementController>()
          : Get.put(PlaylistsManagementController());

  TextEditingController get _searchController => _controller.searchController;

  String get activeChannelId {
    if (channelId != null && channelId!.isNotEmpty) {
      return channelId!;
    }
    if (Get.isRegistered<AuthService>() &&
        AuthService.to.userChannel?.id != null) {
      return AuthService.to.userChannel!.id;
    }
    return AuthService.to.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          // Studio Header & Summary Metrics Bar
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF27272A)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Action Buttons Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Playlists',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Manage and curate your channel playlists and series.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showCreatePlaylistDialog(context),
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'New Playlist',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF27272A),
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF3F3F46),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Playlists',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Manage and curate your channel playlists and series.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showCreatePlaylistDialog(context),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'New Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27272A),
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF3F3F46),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Metric Summary Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return Obx(() {
                        return GridView.count(
                          crossAxisCount: isMobile ? 2 : 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          childAspectRatio: isMobile ? 1.8 : 2.4,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMetricSummaryCard(
                              title: 'Total Playlists',
                              value: '${_controller.totalPlaylistsCount}',
                              icon: Icons.playlist_play_rounded,
                              onTap: () => _controller.setFilterMode('all'),
                              isSelected:
                                  _controller.activeFilterMode.value == 'all',
                            ),
                            _buildMetricSummaryCard(
                              title: 'Linked Videos',
                              value: '${_controller.totalVideosCount}',
                              icon: Icons.video_library_rounded,
                              onTap: () => _controller.setFilterMode('all'),
                            ),
                            _buildMetricSummaryCard(
                              title: 'Public Playlists',
                              value: '${_controller.publicPlaylistsCount}',
                              icon: Icons.public_rounded,
                              onTap: () => _controller.setFilterMode('public'),
                              isSelected:
                                  _controller.activeFilterMode.value == 'public',
                            ),
                            _buildMetricSummaryCard(
                              title: 'Unlisted / Private',
                              value:
                                  '${_controller.unlistedPlaylistsCount + _controller.privatePlaylistsCount}',
                              icon: Icons.lock_outline_rounded,
                              onTap: () => _controller.setFilterMode('unlisted'),
                              isSelected:
                                  _controller.activeFilterMode.value ==
                                      'unlisted' ||
                                  _controller.activeFilterMode.value ==
                                      'private',
                            ),
                          ],
                        );
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Studio Search & Control Bar
                  _buildStudioSearchBar(),
                ],
              ),
            ),
          ),

          // Main Playlists Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<List<PlaylistModel>>(
                stream: _controller.fetchChannelPlaylists(activeChannelId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerGrid();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final playlists = snapshot.data ?? [];

                  // Update controller reactive list safely
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_controller.playlistsList.length != playlists.length) {
                      _controller.playlistsList.assignAll(playlists);
                    }
                  });

                  return Obx(() {
                    final filtered = _controller.filteredPlaylists;

                    if (filtered.isEmpty) {
                      return _buildEmptyState(_controller.searchQuery.value.isNotEmpty);
                    }

                    if (_controller.isGridView.value) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          var crossAxisCount = 1;
                          if (width >= 1200) {
                            crossAxisCount = 4;
                          } else if (width >= 850) {
                            crossAxisCount = 3;
                          } else if (width >= 550) {
                            crossAxisCount = 2;
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                            itemBuilder: (context, index) {
                              final playlist = filtered[index];
                              return _buildPlaylistGridCard(playlist);
                            },
                          );
                        },
                      );
                    } else {
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final playlist = filtered[index];
                          return _buildPlaylistListCard(playlist);
                        },
                      );
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // METRICS & SEARCH BAR WIDGETS
  // ==========================================================================

  Widget _buildMetricSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF27272A)
                : const Color(0xFF141417),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF52525B)
                  : const Color(0xFF27272A),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF202024),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudioSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;

          final searchField = TextField(
            controller: _searchController,
            onChanged: _controller.updateSearchQuery,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search playlists by name or description...',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 18,
              ),
              suffixIcon: Obx(() {
                if (_controller.searchQuery.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _controller.updateSearchQuery('');
                  },
                );
              }),
              filled: true,
              fillColor: const Color(0xFF0F0F0F),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF52525B)),
              ),
            ),
          );

          final filterControls = Obx(() {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Filter Chips
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Public', 'public'),
                _buildFilterChip('Unlisted', 'unlisted'),
                _buildFilterChip('Private', 'private'),

                // Sort Dropdown
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _controller.activeSortMode.value,
                      dropdownColor: const Color(0xFF1E1E22),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'recent',
                          child: Text('Recently Updated'),
                        ),
                        DropdownMenuItem(
                          value: 'videos_desc',
                          child: Text('Most Videos'),
                        ),
                        DropdownMenuItem(
                          value: 'title_asc',
                          child: Text('Title (A-Z)'),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text('Oldest First'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) _controller.setSortMode(val);
                      },
                    ),
                  ),
                ),

                // View Toggle (Grid / List)
                IconButton(
                  tooltip: _controller.isGridView.value
                      ? 'Switch to List View'
                      : 'Switch to Grid View',
                  icon: Icon(
                    _controller.isGridView.value
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _controller.toggleViewMode,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0F0F),
                    side: const BorderSide(color: Color(0xFF27272A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          });

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                filterControls,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 14),
              filterControls,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String mode) {
    final isSelected = _controller.activeFilterMode.value == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _controller.setFilterMode(mode),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      backgroundColor: const Color(0xFF0F0F0F),
      selectedColor: const Color(0xFF27272A),
      side: BorderSide(
        color: isSelected ? const Color(0xFF52525B) : const Color(0xFF27272A),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      showCheckmark: false,
    );
  }

  // ==========================================================================
  // PLAYLIST CARDS (GRID & LIST)
  // ==========================================================================

  Widget _buildPlaylistGridCard(PlaylistModel playlist) {
    final visibilityColor = playlist.visibility == PlaylistVisibility.public
        ? Colors.green
        : (playlist.visibility == PlaylistVisibility.unlisted
            ? Colors.amber
            : const Color(0xFF94A3B8));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Header with Badge & Hover Overlay
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: playlist.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _buildDefaultThumbnail(),
                      )
                    : _buildDefaultThumbnail(),
              ),
              // Video Count Pill Overlay
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${playlist.videoCount} videos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Visibility Pill Overlay
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: visibilityColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        playlist.visibility == PlaylistVisibility.public
                            ? Icons.public_rounded
                            : (playlist.visibility ==
                                    PlaylistVisibility.unlisted
                                ? Icons.link_rounded
                                : Icons.lock_outline_rounded),
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        playlist.visibility.name.toUpperCase(),
                        style: TextStyle(
                          color: visibilityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Metadata & Controls
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          playlist.name.isNotEmpty
                              ? playlist.name
                              : 'Untitled Playlist',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildPlaylistMenu(playlist),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.description.isNotEmpty
                        ? playlist.description
                        : 'No description provided.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  const Divider(height: 12, color: Color(0xFF27272A)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Updated ${timeago.format(playlist.updatedAt.toDate())}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showManageVideosModal(context, playlist),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.video_collection_outlined,
                                color: Colors.white,
                                size: 13,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Manage',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistListCard(PlaylistModel playlist) {
    final visibilityColor = playlist.visibility == PlaylistVisibility.public
        ? Colors.green
        : (playlist.visibility == PlaylistVisibility.unlisted
            ? Colors.amber
            : const Color(0xFF94A3B8));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 16:9 Thumbnail Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 140,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (playlist.thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: playlist.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _buildDefaultThumbnail(),
                    )
                  else
                    _buildDefaultThumbnail(),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${playlist.videoCount} videos',
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
            ),
          ),
          const SizedBox(width: 16),

          // Metadata Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        playlist.name.isNotEmpty
                            ? playlist.name
                            : 'Untitled Playlist',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: visibilityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: visibilityColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        playlist.visibility.name.toUpperCase(),
                        style: TextStyle(
                          color: visibilityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  playlist.description.isNotEmpty
                      ? playlist.description
                      : 'No description provided.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Updated ${timeago.format(playlist.updatedAt.toDate())}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action Buttons
          OutlinedButton.icon(
            onPressed: () => _showManageVideosModal(context, playlist),
            icon: const Icon(
              Icons.video_collection_outlined,
              size: 14,
              color: Colors.white,
            ),
            label: const Text(
              'Manage Videos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E22),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF27272A)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildPlaylistMenu(playlist),
        ],
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return const ColoredBox(
      color: Color(0xFF1F1F23),
      child: Center(
        child: Icon(
          Icons.playlist_play_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildPlaylistMenu(PlaylistModel playlist) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Colors.white,
        size: 18,
      ),
      color: const Color(0xFF1C1C20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      onSelected: (action) {
        if (action == 'view') {
          PlaylistNavigation.openPlaylistDetail(playlist);
        } else if (action == 'manage') {
          _showManageVideosModal(context, playlist);
        } else if (action == 'edit') {
          _showEditPlaylistDialog(context, playlist);
        } else if (action == 'copy') {
          _controller.copyPlaylistLink(playlist);
        } else if (action == 'delete') {
          _confirmDeletePlaylist(context, playlist);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Play & View',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'manage',
          child: Row(
            children: [
              Icon(
                Icons.video_collection_outlined,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Manage & Reorder Videos',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Edit Metadata',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Copy Share Link',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Delete Playlist',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // EMPTY, LOADING & ERROR STATES
  // ==========================================================================

  Widget _buildEmptyState(bool isSearch) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 40),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: const Color(0xFF141417),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF202024),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.playlist_play_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch
                  ? 'No matching playlists found'
                  : 'No playlists created yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try adjusting your search terms or clearing active filters.'
                  : 'Group your channel videos into playlists to help viewers discover and binge your content.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSearch) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  _controller.updateSearchQuery('');
                  _controller.setFilterMode('all');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E22),
      highlightColor: const Color(0xFF2E2E34),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E22),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Error loading playlists: $message',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MODALS & DIALOGS
  // ==========================================================================

  void _showCreatePlaylistDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final selectedVisibility = PlaylistVisibility.public.obs;
    final selectedVideos = <Video>[].obs;
    final isCreating = false.obs;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF141417),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create New Playlist',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Curate your channel videos into an organized playlist series.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: titleController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Playlist Title *',
                              labelStyle: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                              hintText: 'e.g., Full Flutter Course 2026',
                              hintStyle: const TextStyle(
                                color: AppColors.textTertiary,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F0F0F),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descController,
                            maxLines: 3,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              labelStyle: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                              hintText:
                                  'What is this playlist about? Help viewers find your topics.',
                              hintStyle: const TextStyle(
                                color: AppColors.textTertiary,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F0F0F),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Obx(() {
                            return DropdownButtonFormField<PlaylistVisibility>(
                              value: selectedVisibility.value,
                              dropdownColor: const Color(0xFF1E1E22),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Visibility',
                                labelStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F0F0F),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF27272A),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF27272A),
                                  ),
                                ),
                              ),
                              items: PlaylistVisibility.values.map((vis) {
                                return DropdownMenuItem(
                                  value: vis,
                                  child: Text(vis.name.toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  selectedVisibility.value = val;
                                }
                              },
                            );
                          }),
                          const SizedBox(height: 20),

                          // Initial Videos Selection Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Initial Videos',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _openVideoPickerSheet(
                                  context,
                                  selectedVideos,
                                ),
                                icon: const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Add Videos',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Obx(() {
                            if (selectedVideos.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F0F0F),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF27272A),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No videos selected yet (you can add videos anytime)',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: selectedVideos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final vid = selectedVideos[index];
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F0F0F),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF27272A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: SizedBox(
                                          width: 48,
                                          height: 28,
                                          child: vid.thumbnailUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: vid.thumbnailUrl,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: const Color(0xFF27272A),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          vid.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        onPressed: () =>
                                            selectedVideos.removeAt(index),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Obx(() {
                        return ElevatedButton(
                          onPressed: isCreating.value
                              ? null
                              : () async {
                                  final name = titleController.text.trim();
                                  if (name.isEmpty) {
                                    AppSnackbar.show(
                                      'Required',
                                      'Please enter a playlist title.',
                                      backgroundColor: AppColors.error,
                                      colorText: AppColors.textPrimary,
                                    );
                                    return;
                                  }

                                  isCreating.value = true;
                                  final success = await _controller.createPlaylist(
                                    channelId: activeChannelId,
                                    name: name,
                                    description: descController.text.trim(),
                                    visibility: selectedVisibility.value,
                                    selectedVideoIds: selectedVideos
                                        .map((v) => v.id)
                                        .toList(),
                                  );
                                  isCreating.value = false;

                                  if (success && ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27272A),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3F3F46)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isCreating.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Create Playlist',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditPlaylistDialog(
    BuildContext context,
    PlaylistModel playlist,
  ) {
    final titleController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description);
    final selectedVisibility = playlist.visibility.obs;
    final isSaving = false.obs;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF141417),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Playlist Metadata',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Playlist Title',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F0F0F),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF27272A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF27272A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F0F0F),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF27272A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF27272A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Obx(() {
                    return DropdownButtonFormField<PlaylistVisibility>(
                      value: selectedVisibility.value,
                      dropdownColor: const Color(0xFF1E1E22),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Visibility',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF27272A),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF27272A),
                          ),
                        ),
                      ),
                      items: PlaylistVisibility.values.map((vis) {
                        return DropdownMenuItem(
                          value: vis,
                          child: Text(vis.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) selectedVisibility.value = val;
                      },
                    );
                  }),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Obx(() {
                        return ElevatedButton(
                          onPressed: isSaving.value
                              ? null
                              : () async {
                                  isSaving.value = true;
                                  final success =
                                      await _controller.updatePlaylistMetadata(
                                    playlistId: playlist.id,
                                    name: titleController.text.trim(),
                                    description: descController.text.trim(),
                                    visibility: selectedVisibility.value,
                                  );
                                  isSaving.value = false;
                                  if (success && ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27272A),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3F3F46)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isSaving.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showManageVideosModal(
    BuildContext context,
    PlaylistModel playlist,
  ) {
    final rxVideoIds = List<String>.from(playlist.videoIds).obs;
    final rxLoadedVideos = <Video>[].obs;
    final isLoadingVideos = true.obs;
    final isSaving = false.obs;

    // Load rich video models
    _controller.fetchVideosByIds(playlist.videoIds).then((videos) {
      rxLoadedVideos.assignAll(videos);
      isLoadingVideos.value = false;
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF27272A)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Videos — ${playlist.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Drag handles to reorder videos, or add more from your channel.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() {
                    return Text(
                      '${rxVideoIds.length} videos in playlist',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: () => _openVideoPickerSheet(
                      ctx,
                      rxLoadedVideos,
                      onUpdated: (selected) {
                        rxVideoIds.assignAll(selected.map((v) => v.id));
                      },
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Add Channel Videos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27272A),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reorderable Video List
              Expanded(
                child: Obx(() {
                  if (isLoadingVideos.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (rxLoadedVideos.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 48,
                            color: Colors.white,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No videos in this playlist yet.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Click "+ Add Channel Videos" to select videos.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ReorderableListView.builder(
                    itemCount: rxLoadedVideos.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = rxLoadedVideos.removeAt(oldIndex);
                      rxLoadedVideos.insert(newIndex, item);
                      rxVideoIds.assignAll(rxLoadedVideos.map((v) => v.id));
                    },
                    itemBuilder: (context, index) {
                      final video = rxLoadedVideos[index];
                      return Container(
                        key: ValueKey(video.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.drag_handle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 72,
                                height: 42,
                                child: video.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => Container(
                                          color: const Color(0xFF27272A),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFF27272A),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${video.views} views • ${timeago.format(video.createdAt.toDate())}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove from playlist',
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              onPressed: () {
                                rxLoadedVideos.removeAt(index);
                                rxVideoIds.assignAll(
                                  rxLoadedVideos.map((v) => v.id),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Save Actions
              SizedBox(
                width: double.infinity,
                child: Obx(() {
                  return ElevatedButton(
                    onPressed: isSaving.value
                        ? null
                        : () async {
                            isSaving.value = true;
                            final success =
                                await _controller.updatePlaylistVideos(
                              playlist: playlist,
                              videoIds: rxVideoIds.toList(),
                            );
                            isSaving.value = false;
                            if (success && ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27272A),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Order & Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openVideoPickerSheet(
    BuildContext context,
    RxList<Video> targetList, {
    void Function(List<Video>)? onUpdated,
  }) {
    final searchFilter = ''.obs;
    final allChannelVideos = <Video>[].obs;
    final isLoading = true.obs;
    final tempSelected = List<Video>.from(targetList).obs;

    _controller.fetchChannelVideos(activeChannelId).then((vids) {
      allChannelVideos.assignAll(vids);
      isLoading.value = false;
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF27272A)),
      ),
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Channel Videos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Obx(() {
                        if (allChannelVideos.isEmpty) return const SizedBox.shrink();
                        final isAllSelected =
                            tempSelected.length == allChannelVideos.length;
                        return TextButton(
                          onPressed: () {
                            if (isAllSelected) {
                              tempSelected.clear();
                            } else {
                              tempSelected.assignAll(allChannelVideos);
                            }
                          },
                          child: Text(
                            isAllSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (val) => searchFilter.value = val.trim().toLowerCase(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search channel videos...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F0F0F),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF27272A)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final query = searchFilter.value;
                  final displayList = query.isEmpty
                      ? allChannelVideos
                      : allChannelVideos
                          .where((v) =>
                              v.title.toLowerCase().contains(query) ||
                              v.description.toLowerCase().contains(query))
                          .toList();

                  if (displayList.isEmpty) {
                    return const Center(
                      child: Text(
                        'No channel videos found.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: displayList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final video = displayList[index];

                      return Obx(() {
                        final isSelected =
                            tempSelected.any((v) => v.id == video.id);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (isSelected) {
                                tempSelected
                                    .removeWhere((v) => v.id == video.id);
                              } else {
                                tempSelected.add(video);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFF0F0F0F),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : const Color(0xFF27272A),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      width: 56,
                                      height: 32,
                                      child: video.thumbnailUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: video.thumbnailUrl,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, _, _) =>
                                                  const ColoredBox(
                                                color: Color(0xFF27272A),
                                                child: Icon(
                                                  Icons.movie,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            )
                                          : const ColoredBox(
                                              color: Color(0xFF27272A),
                                              child: Icon(
                                                Icons.movie,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          video.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          video.duration.isNotEmpty
                                              ? video.duration
                                              : '${video.views} views',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF3F3F46)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF52525B),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    targetList.assignAll(tempSelected);
                    onUpdated?.call(tempSelected);
                    Navigator.pop(sheetCtx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27272A),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Obx(() {
                    return Text(
                      'Done (${tempSelected.length} selected)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletePlaylist(BuildContext context, PlaylistModel playlist) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141417),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Delete Playlist?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${playlist.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _controller.deletePlaylist(playlist.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
