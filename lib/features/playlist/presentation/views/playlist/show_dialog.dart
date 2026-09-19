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
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppTheme.colors.background54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B5CF6),
            brightness: Theme.of(context).brightness,
          ),
        ),
        child: _ModernizedPlaylistDialog(
          videoId: videoId,
          animation: animation,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final dialogWidth = isTablet ? 500.0 : screenSize.width * 0.9;
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
              maxHeight: screenSize.height * 0.8,
              minHeight: 400,
            ),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, colorScheme, isTablet),
                Flexible(
                  child: _buildContent(
                    context,
                    colorScheme,
                    playlistController,
                    isTablet,
                  ),
                ),
                _buildActions(
                  context,
                  colorScheme,
                  playlistController,
                  isTablet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              color: AppColors.textPrimary,
              size: isTablet ? 28 : 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to Playlist',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 20,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a playlist or create a new one',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.8,
                    ),
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
            ),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    PlaylistController playlistController,
    bool isTablet,
  ) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Create new playlist section
          _buildCreatePlaylistSection(context, colorScheme, isTablet),

          const SizedBox(height: 24),

          // Divider with text
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: colorScheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Or choose existing',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: colorScheme.secondary.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Existing playlists
          Flexible(
            child: _buildPlaylistsList(
              colorScheme,
              playlistController,
              isTablet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePlaylistSection(
    BuildContext context,
    ColorScheme colorScheme,
    bool isTablet,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.textPrimary,
                size: isTablet ? 24 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Create New Playlist',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final isPublic = controller.isPublicNewPlaylist.value;
            return Row(
              children: [
                Text(
                  'Privacy: ',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Private'),
                  selected: !isPublic,
                  onSelected: (val) {
                    if (val) controller.isPublicNewPlaylist.value = false;
                  },
                  selectedColor: colorScheme.secondaryContainer,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Public'),
                  selected: isPublic,
                  onSelected: (val) {
                    if (val) controller.isPublicNewPlaylist.value = true;
                  },
                  selectedColor: colorScheme.secondaryContainer,
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: controller.newPlaylistCtrl,
            inputFormatters: [TruthworldTextInputFormatters.englishOnly],
            decoration: InputDecoration(
              hintText: 'Enter playlist name',
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.secondary,
                  width: 1.5,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isTablet ? 16 : 12,
              ),
              suffixIcon: Obx(
                () => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: controller.isCreatingPlaylist.value
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.secondary,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: () async {
                            final success =
                                await controller.createNewPlaylist(videoId);
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(
                            Icons.add_rounded,
                            color: AppColors.textPrimary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.secondary.withValues(
                              alpha: 0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: colorScheme.onSurface,
            ),
            onSubmitted: (_) async {
              final success = await controller.createNewPlaylist(videoId);
              if (success && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsList(
    ColorScheme colorScheme,
    PlaylistController playlistController,
    bool isTablet,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Obx(() {
      final userPrivatePlaylists = playlistController.playlists.toList();
      final userPublicPlaylists = playlistController.publicPlaylists
          .where((p) => p.ownerId == uid)
          .toList();

      final allPlaylists = <PlaylistModel>[];
      final seenIds = <String>{};

      // Watch Later playlist included at top of private playlists
      if (uid.isNotEmpty) {
        final watchLaterPlaylist = playlistController.getWatchLaterPlaylist();
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
        return _buildEmptyState(colorScheme, isTablet);
      }

      return FadeTransition(
        opacity: controller.listAnimation,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: allPlaylists.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final playlist = allPlaylists[index];
            return _buildPlaylistItem(
              playlist,
              colorScheme,
              playlistController,
              isTablet,
              index,
            );
          },
        ),
      );
    });
  }

  Widget _buildPlaylistItem(
    PlaylistModel playlist,
    ColorScheme colorScheme,
    PlaylistController playlistController,
    bool isTablet,
    int index,
  ) {
    return Obx(() {
      final isSelected =
          controller.selectedPlaylistId.value == playlist.id;

      final isWatchLater = playlist.id == 'watchlater';
      final isInPlaylist = isWatchLater
          ? playlistController.isInWatchLater(videoId)
          : playlist.videoIds.contains(videoId);

      final videoCountText = isWatchLater
          ? '${playlistController.watchLaterVideoIds.length} videos'
          : '${playlist.videoCount} videos';

      final subtitle =
          '$videoCountText • ${playlist.isPublic ? "Public" : "Private"}${isInPlaylist ? " • Added" : ""}';

      return AnimatedContainer(
        duration: Duration(milliseconds: 200 + (index * 50)),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => controller.selectPlaylist(playlist),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.tertiaryContainer.withValues(alpha: 0.3)
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.tertiary
                      : colorScheme.outline.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Playlist icon / thumbnail
                  Container(
                    width: isTablet ? 40 : 36,
                    height: isTablet ? 40 : 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.tertiary.withValues(alpha: 0.2)
                          : AppTheme.colors.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      image: (!isWatchLater && playlist.thumbnailUrl.isNotEmpty)
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                playlist.thumbnailUrl,
                              ),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {},
                            )
                          : null,
                    ),
                    child: isSelected
                        ? Container(
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          )
                        : Icon(
                            isWatchLater
                                ? Icons.watch_later_outlined
                                : Icons.playlist_play_rounded,
                            color: AppColors.textPrimary,
                            size: isTablet ? 24 : 20,
                          ),
                  ),

                  const SizedBox(width: 12),

                  // Playlist info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.playlistName,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? colorScheme.tertiary
                                : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selection / Checkmark indicator
                  AnimatedScale(
                    scale: isSelected ? 1.0 : (isInPlaylist ? 0.8 : 0.0),
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.tertiary
                            : colorScheme.secondary.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.textPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isTablet) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.playlist_add_outlined,
              size: isTablet ? 48 : 40,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No playlists yet',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first playlist above',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    ColorScheme colorScheme,
    PlaylistController playlistController,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Obx(
              () {
                final selectedId = controller.selectedPlaylistId.value;
                final isSelected = selectedId.isNotEmpty;
                final isWatchLater = selectedId == 'watchlater';
                final isInWatchLater =
                    isWatchLater &&
                    playlistController.isInWatchLater(videoId);
                final isInPlaylist =
                    !isWatchLater &&
                    isSelected &&
                    (controller.selectedPlaylist?.videoIds.contains(videoId) ??
                        false);

                var buttonText = 'Add Video';
                if (isWatchLater) {
                  buttonText = isInWatchLater
                      ? 'Remove from Watch Later'
                      : 'Add to Watch Later';
                } else if (isInPlaylist) {
                  buttonText = 'Remove from Playlist';
                }

                return ElevatedButton(
                  onPressed:
                      isSelected && !controller.isAddingToPlaylist.value
                      ? () async {
                          final success =
                              await controller.addVideoToPlaylist(videoId);
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: controller.isAddingToPlaylist.value
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          buttonText,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
