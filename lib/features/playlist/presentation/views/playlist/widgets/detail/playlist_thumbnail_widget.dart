import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';

/// Thumbnail widget for playlist detail screen, supporting large desktop sidebar and mobile/tablet header.
class PlaylistThumbnailWidget extends StatelessWidget {
  const PlaylistThumbnailWidget({
    required this.playlist,
    super.key,
    this.fallbackThumbnailUrl,
    this.isLarge = false,
    this.isTablet = false,
  });

  final PlaylistModel playlist;
  final String? fallbackThumbnailUrl;
  final bool isLarge;
  final bool isTablet;

  String _resolveThumbnail() {
    if (playlist.thumbnailUrl.trim().isNotEmpty) {
      return playlist.thumbnailUrl.trim();
    }
    if (fallbackThumbnailUrl != null &&
        fallbackThumbnailUrl!.trim().isNotEmpty) {
      return fallbackThumbnailUrl!.trim();
    }
    final isWatchLater = playlist.id == 'watchlater' ||
        playlist.playlistName.toLowerCase().trim() == 'watch later';
    if (isWatchLater && Get.isRegistered<PlaylistController>()) {
      final ctrl = Get.find<PlaylistController>();
      if (ctrl.firstVideoThumbnail.value.trim().isNotEmpty) {
        return ctrl.firstVideoThumbnail.value.trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _resolveThumbnail();

    if (isLarge) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: ytSurfaceLight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const PlaylistThumbnailPlaceholder(),
                    errorWidget: (context, url, error) =>
                        const PlaylistThumbnailPlaceholder(),
                  )
                : const PlaylistThumbnailPlaceholder(),
          ),
        ),
      );
    }

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
            child: thumb.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const PlaylistThumbnailPlaceholder(),
                    errorWidget: (context, url, error) =>
                        const PlaylistThumbnailPlaceholder(),
                  )
                : const PlaylistThumbnailPlaceholder(),
          ),
        ),
      ),
    );
  }
}

/// Fallback placeholder when no playlist thumbnail is provided or loading fails.
class PlaylistThumbnailPlaceholder extends StatelessWidget {
  const PlaylistThumbnailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: ytSurfaceLight,
      child: Center(
        child: Icon(
          Icons.playlist_play,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }
}
