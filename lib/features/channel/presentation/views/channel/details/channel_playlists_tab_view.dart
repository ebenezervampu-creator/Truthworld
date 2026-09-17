import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_state_widgets.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Fallback container when playlist thumbnail is missing or loading fails.
class ChannelPlaylistThumbnailFallback extends StatelessWidget {
  const ChannelPlaylistThumbnailFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ytSurfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.playlist_play_rounded,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Thumbnail image for playlist card with video fallback lookup.
class ChannelPlaylistThumbnailImage extends StatelessWidget {
  const ChannelPlaylistThumbnailImage({required this.playlist, super.key});

  final PlaylistModel playlist;

  @override
  Widget build(BuildContext context) {
    if (playlist.thumbnailUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: playlist.thumbnailUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (context, url, error) =>
              const ChannelPlaylistThumbnailFallback(),
        ),
      );
    } else if (playlist.videoIds.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(playlist.videoIds.first)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final videoThumb = data?['thumbnailUrl'] as String?;
            if (videoThumb != null && videoThumb.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: videoThumb,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) =>
                      const ChannelPlaylistThumbnailFallback(),
                ),
              );
            }
          }
          return const ChannelPlaylistThumbnailFallback();
        },
      );
    }
    return const ChannelPlaylistThumbnailFallback();
  }
}

/// A single playlist card.
class ChannelPlaylistCard extends StatelessWidget {
  const ChannelPlaylistCard({
    required this.playlist,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final PlaylistModel playlist;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final width = isDesktop ? 200.0 : (isTablet ? 180.0 : 160.0);

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          Get.toNamed('/playlist-detail', arguments: {'playlist': playlist});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: ytSurface,
                ),
                child: Stack(
                  children: [
                    ChannelPlaylistThumbnailImage(playlist: playlist),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.bgPage.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 40,
                        color: AppColors.bgPage.withValues(alpha: 0.6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.playlist_play,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            Text(
                              '${playlist.videoIds.length}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.playlistName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ytTextPrimary,
              ),
            ),
            const Text(
              'View full playlist',
              style: TextStyle(fontSize: 12, color: ytTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid view of playlist cards for playlists tab.
class ChannelPlaylistGrid extends StatelessWidget {
  const ChannelPlaylistGrid({
    required this.playlists,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final List<PlaylistModel> playlists;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) => ChannelPlaylistCard(
        playlist: playlists[index],
        isDesktop: isDesktop,
        isTablet: isTablet,
      ),
    );
  }
}

/// Playlists section displayed on the Channel Home tab.
class ChannelPlaylistsSection extends GetView<ChannelController> {
  const ChannelPlaylistsSection({
    required this.channel,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final Channel channel;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getPlaylistsStream(channel.channelId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final playlists = snapshot.data!.docs
            .take(5)
            .map(PlaylistModel.fromDocumentSnapshot)
            .where((p) => p.thumbnailUrl.trim().isNotEmpty)
            .toList();

        if (playlists.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Created playlists',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ytTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: isDesktop ? 200 : (isTablet ? 180 : 160),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                itemBuilder: (context, index) => ChannelPlaylistCard(
                  playlist: playlists[index],
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Full Playlists tab content.
class ChannelPlaylistsTabView extends GetView<ChannelController> {
  const ChannelPlaylistsTabView({
    required this.channel,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final Channel channel;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getPlaylistsStream(channel.channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ChannelDetailsStateWidgets.buildShimmerGrid(
            isDesktop: isDesktop,
            isTablet: isTablet,
          );
        }
        if (snapshot.hasError) {
          return ChannelDetailsStateWidgets.buildErrorState(
            'Unable to load playlists. Please try again.',
            () => controller.update(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ChannelDetailsStateWidgets.buildEmptyTabState(
            icon: Icons.playlist_play,
            title: 'No playlists yet',
            subtitle: "This channel hasn't created any playlists",
          );
        }

        final playlists = snapshot.data!.docs
            .map(PlaylistModel.fromDocumentSnapshot)
            .where((p) => p.thumbnailUrl.trim().isNotEmpty)
            .toList();

        if (playlists.isEmpty) {
          return ChannelDetailsStateWidgets.buildEmptyTabState(
            icon: Icons.playlist_play,
            title: 'No playlists yet',
            subtitle: "This channel hasn't created any playlists",
          );
        }

        return ChannelPlaylistGrid(
          playlists: playlists,
          isDesktop: isDesktop,
          isTablet: isTablet,
        );
      },
    );
  }
}
