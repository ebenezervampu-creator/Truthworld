import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/playlist_card.dart';
import 'package:truthworld/core/services/auth_service.dart';
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

/// Modern, modular, high-performance playlist management screen for Truthworld.
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

  List<PlaylistModel> _sortPlaylists(List<PlaylistModel> playlists) {
    final isAsc = _playlistController.isAscending.value;
    switch (_playlistController.sortBy.value) {
      case 'index':
        playlists.sort((a, b) => isAsc ? a.sortIndex.compareTo(b.sortIndex) : b.sortIndex.compareTo(a.sortIndex));
      case 'name':
        playlists.sort((a, b) => isAsc ? a.playlistName.compareTo(b.playlistName) : b.playlistName.compareTo(a.playlistName));
      case 'videos':
        playlists.sort((a, b) => isAsc ? a.videoIds.length.compareTo(b.videoIds.length) : b.videoIds.length.compareTo(a.videoIds.length));
      case 'created':
      case 'recent':
      default:
        playlists.sort((a, b) => isAsc ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));
    }
    return playlists;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _playlistController;

    return Obx(() {
      final isCreator = AuthService.to.hasChannel.value;
      final refreshTick = controller.refreshTick.value;
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1200;
      final isDesktop = screenWidth >= 1200;
      final isPublic = isCreator && controller.selectedPlaylistType.value == 'public';

      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: PlaylistHeaderBar(
                controller: controller,
                isMobile: isMobile,
                isDashboard: isDashboard,
                onCreatePlaylist: _showCreatePlaylistModal,
              ),
            ),
            if (isCreator)
              SliverToBoxAdapter(
                child: PlaylistTypeSelectionCards(
                  selectedType: controller.selectedPlaylistType,
                  onTypeSelected: (type) => controller.selectedPlaylistType.value = type,
                ),
              ),
            SliverFillRemaining(
              child: RefreshIndicator(
                key: ValueKey(refreshTick),
                color: Colors.white,
                backgroundColor: AppColors.bgSurface,
                onRefresh: _refreshPlaylists,
                child: _buildPlaylistsTab(
                  controller: controller,
                  isPublic: isPublic,
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPlaylistsTab({
    required PlaylistController controller,
    required bool isPublic,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    return Obx(() {
      final isLoaded = isPublic
          ? (controller.user.isEmpty || controller.isPublicPlaylistsLoaded.value)
          : (controller.user.isEmpty || controller.isPlaylistsLoaded.value);

      if (!isLoaded) {
        return PlaylistShimmerLoading(
          isListView: controller.isListView.value,
          isMobile: isMobile,
          isTablet: isTablet,
          isDesktop: isDesktop,
        );
      }

      final sourcePlaylists = isPublic
          ? controller.publicPlaylists
          : controller.playlists;

      if (sourcePlaylists.isEmpty) {
        return PlaylistEmptyStateWidget(isPublic: isPublic);
      }

      var playlists = sourcePlaylists
          .where((p) => p.thumbnailUrl.trim().isNotEmpty)
          .toList();

      if (controller.searchQuery.value.isNotEmpty) {
        playlists = playlists.where((playlist) {
          return playlist.playlistName.toLowerCase().contains(
            controller.searchQuery.value.toLowerCase(),
          );
        }).toList();
      }

      playlists = _sortPlaylists(playlists);

      if (playlists.isEmpty) {
        return const PlaylistNoResultsWidget();
      }

      return _buildPlaylistGrid(
        playlists: playlists,
        isMobile: isMobile,
        isTablet: isTablet,
        isDesktop: isDesktop,
      );
    });
  }

  Widget _buildPlaylistGrid({
    required List<PlaylistModel> playlists,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final crossAxisCount = isMobile
        ? 2
        : isTablet
            ? 3
            : 4;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 0.82 : 0.92,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return PlaylistCard(
          playlist: playlist,
          onTap: () {
            Get.toNamed('/playlist-detail', arguments: {'playlist': playlist});
          },
          onOptionsTap: () {
            showPlaylistOptionsSheet(
              context: context,
              playlist: playlist,
              playlistController: _playlistController,
            );
          },
        );
      },
    );
  }
}

// Preserve original theme configuration for backward compatibility
class AppTheme {
  static final ThemeData darkTheme = ThemeData.dark().copyWith();
}
