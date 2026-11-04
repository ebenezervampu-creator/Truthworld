import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_barrel.dart';
import 'package:truthworld/features/video/data/models/video.dart';

export 'widgets/detail/playlist_detail_barrel.dart';

/// Modernized, declarative Playlist Detail Screen supporting desktop, tablet, and mobile layouts.
class PlaylistDetailScreen extends GetView<PlaylistDetailController> {
  const PlaylistDetailScreen({super.key, this.playlist});
  final PlaylistModel? playlist;

  @override
  Widget build(BuildContext context) {
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
          activePlaylist = args['playlist'] as PlaylistModel;
        }
      }
    }

    if (activePlaylist == null && Get.isRegistered<HomeController>()) {
      final rawPlaylist = Get.find<HomeController>().selectedPlaylist.value;
      if (rawPlaylist is PlaylistModel) {
        activePlaylist = rawPlaylist;
      }
    }

    // Safely sync post-frame without triggering markNeedsBuild during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (activePlaylist != null) {
        controller.syncPlaylist(activePlaylist);
      } else {
        final playlistId =
            Get.parameters['playlistId'] ??
            Get.parameters['list'] ??
            Get.parameters['id'];
        if (playlistId != null &&
            playlistId.isNotEmpty &&
            controller.activePlaylist.value?.id != playlistId) {
          controller.loadPlaylistFromDeepLink(playlistId);
        }
      }
    });

    return Scaffold(
      backgroundColor: ytBackground,
      appBar: AppBar(
        backgroundColor: ytBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ytTextPrimary),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Get.back();
            } else {
              RouteStackObserver.navigateToHome();
            }
          },
        ),
        title: Obx(() {
          final current =
              controller.activePlaylist.value ?? activePlaylist;
          return Text(
            current?.playlistName ?? '',
            style: const TextStyle(
              color: ytTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          );
        }),
      ),
      body: Obx(() {
        final current =
            controller.activePlaylist.value ?? activePlaylist;
        if (current == null) {
          return const ShimmerPlaylistDetail();
        }
        return _buildContent(context, current);
      }),
    );
  }

  Widget _buildContent(BuildContext context, PlaylistModel playlist) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

        if (isDesktop) {
          return _buildDesktopLayout(context, playlist);
        } else {
          return _buildMobileTabletLayout(
            context,
            playlist,
            isTablet: isTablet,
          );
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, PlaylistModel playlist) {
    return Row(
      children: [
        Container(
          width: 360,
          color: ytSurface,
          child: PlaylistDetailSidebar(playlist: playlist, isDesktop: true),
        ),
        Expanded(
          child: _buildVideoListSection(context, playlist, isDesktop: true),
        ),
      ],
    );
  }

  Widget _buildMobileTabletLayout(
    BuildContext context,
    PlaylistModel playlist, {
    bool isTablet = false,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PlaylistDetailHeader(playlist: playlist, isTablet: isTablet),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: PlaylistFilterTabDelegate(
            child: PlaylistFilterTabs(controller: controller),
            maxHeight: 48,
          ),
        ),
        SliverToBoxAdapter(
          child: _buildVideoList(context, playlist, isTablet: isTablet),
        ),
      ],
    );
  }

  Widget _buildVideoListSection(
    BuildContext context,
    PlaylistModel playlist, {
    bool isDesktop = false,
  }) {
    return Column(
      children: [
        PlaylistFilterTabs(controller: controller),
        const Divider(color: ytBorder, height: 1),
        Expanded(
          child: _buildVideoList(context, playlist, isDesktop: isDesktop),
        ),
      ],
    );
  }

  Widget _buildVideoList(
    BuildContext context,
    PlaylistModel playlist, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    if (playlist.effectiveVideoCount == 0 &&
        playlist.videoIds.isEmpty &&
        playlist.id != 'watchlater') {
      return const PlaylistDetailEmptyState();
    }

    return FutureBuilder<List<Video>>(
      future: fetchPlaylistVideos(playlist),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return PlaylistVideoShimmer(isDesktop: isDesktop);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PlaylistDetailErrorState(
            message: 'Unable to load playlist videos. Please try again.',
            onRetry: () => controller.setLoading(true),
          );
        }

        final videos = snapshot.data!;

        if (videos.isNotEmpty &&
            (playlist.thumbnailUrl.trim().isEmpty ||
                playlist.effectiveVideoCount != videos.length)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final active = controller.activePlaylist.value ?? playlist;
            final firstThumb = videos.first.thumbnailUrl.trim();
            if (active.thumbnailUrl.trim().isEmpty ||
                active.effectiveVideoCount != videos.length) {
              controller.activePlaylist.value = active.copyWith(
                thumbnailUrl: active.thumbnailUrl.trim().isNotEmpty
                    ? active.thumbnailUrl
                    : firstThumb,
                videoCount: videos.length,
              );
            }
            if (Get.isRegistered<PlaylistController>() &&
                firstThumb.isNotEmpty &&
                (playlist.id == 'watchlater' ||
                    playlist.playlistName.toLowerCase().trim() ==
                        'watch later')) {
              Get.find<PlaylistController>().setWatchLaterThumbnail(firstThumb);
            }
          });
        }

        return Obx(() {
          final filter = controller.filterValue.value.toLowerCase();
          final filteredVideos = videos.where((video) {
            if (filter.isEmpty || filter == 'all') return true;
            if (filter == 'shorts') return video.isShort;
            if (filter == 'videos') return !video.isShort;
            return true;
          }).toList();

          if (filteredVideos.isEmpty) {
            return const PlaylistDetailEmptyState();
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
              return PlaylistVideoListItem(
                index: index + 1,
                video: video,
                playlist: playlist,
                isDesktop: isDesktop,
                isTablet: isTablet,
              );
            },
          );
        });
      },
    );
  }
}
