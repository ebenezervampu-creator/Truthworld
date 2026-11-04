import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_dialog_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

void showModernizedPlaylistDialog({
  required BuildContext context,
  required String videoId,
}) {
  if (Get.isRegistered<PlaylistDialogController>()) {
    Get.find<PlaylistDialogController>().resetForm();
  }
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ModernizedPlaylistDialog(
        videoId: videoId,
        animation: animation,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  ).then((_) {
    if (Get.isRegistered<PlaylistDialogController>()) {
      Get.find<PlaylistDialogController>().resetForm();
    }
  });
}

class _ModernizedPlaylistDialog extends StatelessWidget {
  const _ModernizedPlaylistDialog({
    required this.videoId,
    required this.animation,
  });
  final String videoId;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlaylistDialogController>(
      init: PlaylistDialogController(),
      builder: (dialogController) => _ModernizedPlaylistDialogView(
        videoId: videoId,
        controller: dialogController,
      ),
    );
  }
}

class _ModernizedPlaylistDialogView extends StatelessWidget {
  const _ModernizedPlaylistDialogView({
    required this.videoId,
    required this.controller,
  });

  final String videoId;
  final PlaylistDialogController controller;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final dialogWidth = isTablet ? 480.0 : min(screenSize.width * 0.92, 440.0);
    final dialogMaxHeight = min(screenSize.height * 0.85, 620.0);
    final playlistController = Get.isRegistered<PlaylistController>()
        ? Get.find<PlaylistController>()
        : Get.put(PlaylistController());

    return Center(
      child: ScaleTransition(
        scale: controller.scaleAnimation,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(
              maxHeight: dialogMaxHeight,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, isTablet),
                  const Divider(height: 1, color: AppColors.bgDivider),
                  Flexible(
                    child: _buildScrollableBody(
                      context,
                      playlistController,
                      isTablet,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.bgDivider),
                  _buildFooter(context, playlistController, isTablet),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isTablet,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 18,
        vertical: isTablet ? 18 : 16,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Icon(
              Icons.playlist_add_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Save to playlist',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select playlists or create a new one',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgSurfaceHover,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableBody(
    BuildContext context,
    PlaylistController playlistController,
    bool isTablet,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Create new playlist section
          _buildCreatePlaylistSection(context, isTablet),

          const SizedBox(height: 14),

          // Playlists List
          Obx(() {
            final userPrivatePlaylists = playlistController.playlists.toList();
            final userPublicPlaylists = playlistController.publicPlaylists
                .where((p) => p.ownerId == uid)
                .toList();

            final allPlaylists = <PlaylistModel>[];
            final seenIds = <String>{};

            // Watch Later always at top of list
            if (uid.isNotEmpty) {
              final watchLaterPlaylist =
                  playlistController.getWatchLaterPlaylist();
              if (watchLaterPlaylist != null) {
                allPlaylists.add(watchLaterPlaylist);
                seenIds.add('watchlater');
              }
            }

            for (final p in [...userPrivatePlaylists, ...userPublicPlaylists]) {
              if (seenIds.add(p.id)) {
                allPlaylists.add(p);
              }
            }

            if (allPlaylists.isEmpty) {
              return _buildEmptyState(isTablet);
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allPlaylists.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final playlist = allPlaylists[index];
                return _buildPlaylistItem(
                  playlist,
                  playlistController,
                  isTablet,
                  index,
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCreatePlaylistSection(
    BuildContext context,
    bool isTablet,
  ) {
    return Obx(() {
      final isExpanded = controller.showCreateForm.value;

      if (!isExpanded) {
        return Material(
          color: AppColors.bgSurfaceHover,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: controller.toggleCreateForm,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create new playlist',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final isPublic = controller.isPublicNewPlaylist.value;
      final isCreating = controller.isCreatingPlaylist.value;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceHover,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New playlist',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: controller.toggleCreateForm,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.newPlaylistCtrl,
              maxLength: 100,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(100),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Enter playlist title...',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.bgPage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.brand,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) async {
                await controller.createNewPlaylist(videoId);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Privacy:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Private',
                    style: TextStyle(
                      color: !isPublic ? Colors.black : AppColors.textPrimary,
                      fontWeight:
                          !isPublic ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  selected: !isPublic,
                  selectedColor: Colors.white,
                  backgroundColor: AppColors.bgPage,
                  side: BorderSide(
                    color: !isPublic
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (val) {
                    if (val) controller.isPublicNewPlaylist.value = false;
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Public',
                    style: TextStyle(
                      color: isPublic ? Colors.black : AppColors.textPrimary,
                      fontWeight:
                          isPublic ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  selected: isPublic,
                  selectedColor: Colors.white,
                  backgroundColor: AppColors.bgPage,
                  side: BorderSide(
                    color: isPublic
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (val) {
                    if (val) controller.isPublicNewPlaylist.value = true;
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          await controller.createNewPlaylist(videoId);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPlaylistItem(
    PlaylistModel playlist,
    PlaylistController playlistController,
    bool isTablet,
    int index,
  ) {
    return Obx(() {
      final isWatchLater = playlist.id == 'watchlater';
      final isInPlaylist = isWatchLater
          ? playlistController.isInWatchLater(videoId)
          : playlist.videoIds.contains(videoId);

      final isToggling = controller.isPlaylistToggling(playlist.id);

      final videoCount = isWatchLater
          ? playlistController.watchLaterVideoIds.length
          : playlist.effectiveVideoCount;
      final videoCountText =
          '$videoCount ${videoCount == 1 ? "video" : "videos"}';
      final visibilityText = playlist.isPublic ? 'Public' : 'Private';

      return Material(
        color: isInPlaylist
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.bgSurfaceHover.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isToggling
              ? null
              : () async {
                  controller.selectPlaylist(playlist);
                  await controller.togglePlaylistMembership(
                    playlist: playlist,
                    videoId: videoId,
                  );
                },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 14 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isInPlaylist
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                // Icon or thumbnail
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    image: (!isWatchLater && playlist.thumbnailUrl.isNotEmpty)
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                              playlist.thumbnailUrl,
                            ),
                            fit: BoxFit.cover,
                            onError: (_, _) {},
                          )
                        : null,
                  ),
                  child: (!isWatchLater && playlist.thumbnailUrl.isNotEmpty)
                      ? null
                      : Icon(
                          isWatchLater
                              ? Icons.watch_later_rounded
                              : Icons.playlist_play_rounded,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                ),

                const SizedBox(width: 14),

                // Playlist title and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.playlistName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            playlist.isPublic
                                ? Icons.public_rounded
                                : Icons.lock_outline_rounded,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$visibilityText • $videoCountText',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Interactive Checkbox / Loading Indicator
                if (isToggling)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isInPlaylist ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isInPlaylist
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        width: 1.8,
                      ),
                    ),
                    child: isInPlaylist
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.black,
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState(bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Icon(
              Icons.playlist_play_rounded,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No playlists found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a new playlist above to organize your videos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    PlaylistController playlistController,
    bool isTablet,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 18,
        vertical: isTablet ? 16 : 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
