import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/playlist_screen_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

// Re-export all widgets and dialogs for 100% backward compatibility
export 'package:truthworld/features/playlist/presentation/views/playlist/widgets/playlist_screen_widgets.dart';

// Backward compatibility constants
const Color kPrimaryDark = AppColors.brand;
const Color kSecondaryDark = AppColors.brandVariant;
const double kBorderRadius = 16.0;
const double kSmallPadding = 8.0;
const double kMediumPadding = 16.0;
const double kLargePadding = 24.0;
const Color kDarkBackground = AppColors.bgPage;
const Color kDarkSurface = AppColors.bgSurface;
const Color kDarksurfaceContainerHighest = AppColors.bgSurfaceHover;

/// Modern, modular, high-performance playlist management screen for TruthWorld.
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({
    super.key,
    this.videoId,
    this.videoThumbnail,
    this.videoTitle,
    this.isDashboard = false,
  });

  final String? videoId;
  final String? videoThumbnail;
  final String? videoTitle;
  final bool isDashboard;

  PlaylistController get _playlistController {
    if (!Get.isRegistered<PlaylistController>()) {
      return Get.put(PlaylistController());
    }
    return Get.find<PlaylistController>();
  }

  void _showCreatePlaylistModal() {
    Get.to(() => CreatePlaylistScreen(initialVideoId: videoId));
  }

  Future<void> _refreshPlaylists() async {
    _playlistController.refreshPlaylistsTick();
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'index':
        return 'Custom order';
      case 'name':
        return 'Name';
      case 'videos':
        return 'Videos';
      case 'created':
        return 'Created';
      case 'recent':
      default:
        return 'Recently updated';
    }
  }

  List<PlaylistModel> _sortPlaylists(List<PlaylistModel> playlists) {
    final isAsc = _playlistController.isAscending.value;
    switch (_playlistController.sortBy.value) {
      case 'index':
        playlists.sort((a, b) =>
            isAsc ? a.sortIndex.compareTo(b.sortIndex) : b.sortIndex.compareTo(a.sortIndex));
      case 'name':
        playlists.sort((a, b) =>
            isAsc ? a.playlistName.compareTo(b.playlistName) : b.playlistName.compareTo(a.playlistName));
      case 'videos':
        playlists.sort((a, b) =>
            isAsc ? a.videoCount.compareTo(b.videoCount) : b.videoCount.compareTo(a.videoCount));
      case 'created':
        playlists.sort((a, b) =>
            isAsc ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));
      case 'recent':
      default:
        playlists.sort((a, b) =>
            isAsc ? a.updatedAt.compareTo(b.updatedAt) : b.updatedAt.compareTo(a.updatedAt));
    }
    return playlists;
  }

  Widget _buildPlaylistsSectionHeader({
    required bool isPublic,
    required int count,
    required PlaylistController controller,
    required BuildContext context,
  }) {
    final sortLabel = _getSortLabel(controller.sortBy.value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    isPublic ? 'Public Playlists' : 'Private Playlists',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => showPlaylistSortBottomSheet(
              context: context,
              controller: controller,
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.bgSurfaceHigh,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.swap_vert_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    sortLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _playlistController;

    return Obx(() {
      final refreshTick = controller.refreshTick.value;
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1150;
      final isDesktop = screenWidth >= 1150;
      final isPublic = controller.selectedPlaylistType.value == 'public';

      final isLoaded = isPublic
          ? (controller.user.isEmpty || controller.isPublicPlaylistsLoaded.value)
          : (controller.user.isEmpty || controller.isPlaylistsLoaded.value);

      var sourcePlaylists = isPublic
          ? List<PlaylistModel>.from(controller.publicPlaylists)
          : List<PlaylistModel>.from(controller.playlists);

      // Prepend or synchronize Watch Later for private playlists
      if (!isPublic && controller.user.isNotEmpty) {
        final wlIndex = sourcePlaylists.indexWhere((p) =>
            p.id == 'watchlater' ||
            p.playlistName.toLowerCase().trim() == 'watch later');
        final liveCount = controller.watchLaterVideoIds.length;
        final liveThumb = controller.firstVideoThumbnail.value;

        if (wlIndex >= 0) {
          final existing = sourcePlaylists[wlIndex];
          sourcePlaylists[wlIndex] = existing.copyWith(
            id: 'watchlater',
            name: 'Watch Later',
            playlistName: 'Watch Later',
            videoIds: List<String>.from(controller.watchLaterVideoIds),
            videoCount: liveCount,
            thumbnailUrl:
                liveThumb.isNotEmpty ? liveThumb : existing.thumbnailUrl,
          );
        } else if (controller.watchLaterVideoIds.isNotEmpty) {
          final wl = controller.getWatchLaterPlaylist();
          if (wl != null) {
            sourcePlaylists.insert(0, wl);
          }
        }
      }

      if (controller.searchQuery.value.isNotEmpty) {
        sourcePlaylists = sourcePlaylists.where((p) {
          return p.playlistName.toLowerCase().contains(
            controller.searchQuery.value.toLowerCase(),
          );
        }).toList();
      }

      sourcePlaylists = _sortPlaylists(sourcePlaylists);

      int crossAxisCount;
      if (screenWidth >= 1150) {
        crossAxisCount = 4;
      } else if (screenWidth >= 780) {
        crossAxisCount = 3;
      } else if (screenWidth >= 520) {
        crossAxisCount = 2;
      } else {
        crossAxisCount = screenWidth >= 360 ? 2 : 1;
      }

      final availableWidth = screenWidth - 32.0;
      final cardWidth =
          (availableWidth - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
      final thumbWidth = cardWidth - 24.0;
      final thumbHeight = thumbWidth * (9.0 / 16.0);
      final cardHeight = thumbHeight + 104.0;
      final childAspectRatio = (cardWidth / cardHeight).clamp(0.65, 1.45);

      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            key: ValueKey(refreshTick),
            color: Colors.white,
            backgroundColor: AppColors.bgSurface,
            onRefresh: _refreshPlaylists,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: PlaylistHeaderBar(
                    controller: controller,
                    isMobile: isMobile,
                    isDashboard: isDashboard,
                    onCreatePlaylist: _showCreatePlaylistModal,
                  ),
                ),
                SliverToBoxAdapter(
                  child: PlaylistTypeSelectionCards(
                    selectedType: controller.selectedPlaylistType,
                    onTypeSelected: (type) =>
                        controller.selectedPlaylistType.value = type,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildPlaylistsSectionHeader(
                    isPublic: isPublic,
                    count: sourcePlaylists.length,
                    controller: controller,
                    context: context,
                  ),
                ),
                if (!isLoaded)
                  SliverToBoxAdapter(
                    child: PlaylistShimmerLoading(
                      isListView: false,
                      isMobile: isMobile,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                  )
                else if (sourcePlaylists.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: controller.searchQuery.value.isNotEmpty
                        ? const PlaylistNoResultsWidget()
                        : PlaylistEmptyStateWidget(isPublic: isPublic),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final playlist = sourcePlaylists[index];
                          return PlaylistScreenCard(
                            playlist: playlist,
                            onTap: () {
                              Get.toNamed(
                                '/playlist-detail?playlistId=${playlist.id}',
                                arguments: {'playlist': playlist},
                              );
                            },
                            onOptionsTap: () {
                              showPlaylistOptionsSheet(
                                context: context,
                                playlist: playlist,
                                playlistController: controller,
                              );
                            },
                          );
                        },
                        childCount: sourcePlaylists.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// Preserve original theme configuration for backward compatibility
class AppTheme {
  static final ThemeData darkTheme = ThemeData.dark().copyWith();
}
