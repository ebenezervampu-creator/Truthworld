import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/utils/playlist_navigation.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/delete_playlist_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/edit_playlist_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/manage_playlist_videos_modal.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean 16:9 placeholder thumbnail for playlists matching YouTube Studio styling.
class PlaylistDefaultThumbnail extends StatelessWidget {
  const PlaylistDefaultThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurfaceHover,
      child: const Center(
        child: Icon(
          Icons.playlist_play_rounded,
          color: AppColors.textSecondary,
          size: 38,
        ),
      ),
    );
  }
}

/// YouTube-style stacked thumbnail widget visually indicating a collection of videos.
class PlaylistThumbnailStacked extends StatelessWidget {
  const PlaylistThumbnailStacked({
    required this.playlist,
    this.onTap,
    this.height,
    super.key,
  });

  final PlaylistModel playlist;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final videoCountText = playlist.videoCount == 1
        ? '1 video'
        : '${playlist.videoCount} videos';

    final isHovered = false.obs;

    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ?? () => PlaylistNavigation.openPlaylistDetail(playlist),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Top Layer 2 (backmost stacked card edge - YouTube style)
                Positioned(
                  top: -5,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                  ),
                ),

                // Top Layer 1 (middle stacked card edge - YouTube style)
                Positioned(
                  top: -2.5,
                  left: 7,
                  right: 7,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(9),
                        topRight: Radius.circular(9),
                      ),
                    ),
                  ),
                ),

                // Main Thumbnail Container
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        if (playlist.thumbnailUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: playlist.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const PlaylistDefaultThumbnail(),
                            errorWidget: (_, _, _) =>
                                const PlaylistDefaultThumbnail(),
                          )
                        else
                          const PlaylistDefaultThumbnail(),

                        // Subtle bottom vignette gradient
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // YouTube-style video count badge at bottom right
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 0.5,
                              ),
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
                                  videoCountText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: TWTypography.uiFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Desktop Hover Overlay: YouTube "Play all" scrim
                        Obx(() {
                          if (!isHovered.value) {
                            return const SizedBox.shrink();
                          }
                          return Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Play all',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: TWTypography.uiFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Action menu dropdown for playlists with rich actions.
class PlaylistMenuButton extends StatelessWidget {
  const PlaylistMenuButton({
    required this.playlist,
    required this.channelId,
    super.key,
  });

  final PlaylistModel playlist;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppColors.textSecondary,
        size: 18,
      ),
      tooltip: 'More actions',
      padding: EdgeInsets.zero,
      splashRadius: 18,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      elevation: 6,
      onSelected: (action) {
        if (action == 'view') {
          PlaylistNavigation.openPlaylistDetail(playlist);
        } else if (action == 'manage') {
          ManagePlaylistVideosModal.show(
            context,
            playlist: playlist,
            channelId: channelId,
          );
        } else if (action == 'edit') {
          EditPlaylistDialog.show(context, playlist: playlist);
        } else if (action == 'copy') {
          final controller = Get.isRegistered<PlaylistsManagementController>()
              ? Get.find<PlaylistsManagementController>()
              : Get.put(PlaylistsManagementController());
          controller.copyPlaylistLink(playlist);
        } else if (action == 'delete') {
          DeletePlaylistConfirmationDialog.show(context, playlist: playlist);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: AppColors.textPrimary,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Play & View',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: TWTypography.uiFamily,
                ),
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
                color: AppColors.textPrimary,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Manage & Reorder Videos',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: TWTypography.uiFamily,
                ),
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
                color: AppColors.textPrimary,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Edit Metadata',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: TWTypography.uiFamily,
                ),
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
                color: AppColors.textPrimary,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Copy Share Link',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: TWTypography.uiFamily,
                ),
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
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: TWTypography.uiFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// YouTube-style visibility badge widget (clean, modern, no neon colors).
class PlaylistVisibilityIndicator extends StatelessWidget {
  const PlaylistVisibilityIndicator({
    required this.visibility,
    super.key,
  });

  final PlaylistVisibility visibility;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;

    switch (visibility) {
      case PlaylistVisibility.public:
        icon = Icons.public_rounded;
        label = 'Public';
      case PlaylistVisibility.unlisted:
        icon = Icons.link_rounded;
        label = 'Unlisted';
      case PlaylistVisibility.private:
        icon = Icons.lock_outline_rounded;
        label = 'Private';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontFamily: TWTypography.uiFamily,
          ),
        ),
      ],
    );
  }
}

/// Redesigned YouTube-style Grid Card for a channel playlist.
class PlaylistGridCard extends StatelessWidget {
  const PlaylistGridCard({
    required this.playlist,
    required this.channelId,
    super.key,
  });

  final PlaylistModel playlist;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final hasDescription = playlist.description.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. YouTube Stacked Thumbnail Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: PlaylistThumbnailStacked(
              playlist: playlist,
              onTap: () => PlaylistNavigation.openPlaylistDetail(playlist),
            ),
          ),

          // 2. Info & Controls Container
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and 3-dots Menu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              PlaylistNavigation.openPlaylistDetail(playlist),
                          borderRadius: BorderRadius.circular(4),
                          child: Text(
                            playlist.name.isNotEmpty
                                ? playlist.name
                                : 'Untitled Playlist',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.25,
                              fontFamily: TWTypography.brandFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      PlaylistMenuButton(
                        playlist: playlist,
                        channelId: channelId,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Visibility & Last Updated Meta Row (YouTube Style)
                  Row(
                    children: [
                      PlaylistVisibilityIndicator(
                        visibility: playlist.visibility,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '•',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Updated ${timeago.format(playlist.updatedAt.toDate())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontFamily: TWTypography.uiFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Description (Clean snippet)
                  Expanded(
                    child: Text(
                      hasDescription
                          ? playlist.description
                          : 'No description provided.',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasDescription
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                        fontStyle:
                            hasDescription ? FontStyle.normal : FontStyle.italic,
                        height: 1.3,
                        fontFamily: TWTypography.uiFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // YouTube Studio Toolstrip Action Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ManagePlaylistVideosModal.show(
                            context,
                            playlist: playlist,
                            channelId: channelId,
                          ),
                          icon: const Icon(
                            Icons.video_collection_outlined,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          label: const Text(
                            'Manage Videos',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: TWTypography.uiFamily,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.bgSurfaceHover,
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Edit details',
                        onPressed: () => EditPlaylistDialog.show(
                          context,
                          playlist: playlist,
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.bgSurfaceHover,
                          padding: const EdgeInsets.all(7),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Play playlist',
                        onPressed: () =>
                            PlaylistNavigation.openPlaylistDetail(playlist),
                        icon: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.bgSurfaceHover,
                          padding: const EdgeInsets.all(7),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
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
}

/// Redesigned YouTube Studio List Row for a channel playlist.
class PlaylistListCard extends StatelessWidget {
  const PlaylistListCard({
    required this.playlist,
    required this.channelId,
    super.key,
  });

  final PlaylistModel playlist;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final videoCountText = playlist.videoCount == 1
        ? '1 video'
        : '${playlist.videoCount} videos';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          if (isCompact) {
            // Adaptive vertical layout on narrow screens/phones
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: PlaylistThumbnailStacked(
                        playlist: playlist,
                        onTap: () =>
                            PlaylistNavigation.openPlaylistDetail(playlist),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name.isNotEmpty
                                ? playlist.name
                                : 'Untitled Playlist',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: TWTypography.brandFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          PlaylistVisibilityIndicator(
                            visibility: playlist.visibility,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$videoCountText • Updated ${timeago.format(playlist.updatedAt.toDate())}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                              fontFamily: TWTypography.uiFamily,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PlaylistMenuButton(
                      playlist: playlist,
                      channelId: channelId,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ManagePlaylistVideosModal.show(
                          context,
                          playlist: playlist,
                          channelId: channelId,
                        ),
                        icon: const Icon(
                          Icons.video_collection_outlined,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                        label: const Text(
                          'Manage Videos',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: TWTypography.uiFamily,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.bgSurfaceHover,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Edit details',
                      onPressed: () => EditPlaylistDialog.show(
                        context,
                        playlist: playlist,
                      ),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.bgSurfaceHover,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          // Full Desktop/Tablet Row Layout
          return Row(
            children: [
              // Stacked Thumbnail
              SizedBox(
                width: 140,
                child: PlaylistThumbnailStacked(
                  playlist: playlist,
                  onTap: () => PlaylistNavigation.openPlaylistDetail(playlist),
                ),
              ),
              const SizedBox(width: 16),

              // Title, Visibility, Description & Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                PlaylistNavigation.openPlaylistDetail(playlist),
                            borderRadius: BorderRadius.circular(4),
                            child: Text(
                              playlist.name.isNotEmpty
                                  ? playlist.name
                                  : 'Untitled Playlist',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: TWTypography.brandFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHover,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: PlaylistVisibilityIndicator(
                            visibility: playlist.visibility,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playlist.description.isNotEmpty
                          ? playlist.description
                          : 'No description provided.',
                      style: TextStyle(
                        fontSize: 12,
                        color: playlist.description.isNotEmpty
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                        fontStyle: playlist.description.isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                        fontFamily: TWTypography.uiFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$videoCountText • Updated ${timeago.format(playlist.updatedAt.toDate())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Action Buttons
              OutlinedButton.icon(
                onPressed: () => ManagePlaylistVideosModal.show(
                  context,
                  playlist: playlist,
                  channelId: channelId,
                ),
                icon: const Icon(
                  Icons.video_collection_outlined,
                  size: 14,
                  color: AppColors.textPrimary,
                ),
                label: const Text(
                  'Manage Videos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: TWTypography.uiFamily,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.bgSurfaceHover,
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Edit details',
                onPressed: () => EditPlaylistDialog.show(
                  context,
                  playlist: playlist,
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.bgSurfaceHover,
                  padding: const EdgeInsets.all(9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PlaylistMenuButton(
                playlist: playlist,
                channelId: channelId,
              ),
            ],
          );
        },
      ),
    );
  }
}
