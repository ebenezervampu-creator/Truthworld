import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_dialog_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

final PlaylistController playlistController = Get.find<PlaylistController>();
final PlaylistDialogController playlistDialogController = Get.find<PlaylistDialogController>();

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

class _ModernizedPlaylistDialog extends StatefulWidget {
  const _ModernizedPlaylistDialog({
    required this.videoId,
    required this.animation,
  });
  final String videoId;
  final Animation<double> animation;

  @override
  State<_ModernizedPlaylistDialog> createState() =>
      _ModernizedPlaylistDialogState();
}

class _ModernizedPlaylistDialogState extends State<_ModernizedPlaylistDialog>
    with TickerProviderStateMixin {
  final TextEditingController newPlaylistCtrl = TextEditingController();
  late PlaylistDialogController _dialogController;
  final RxBool _isPublicNewPlaylist = false.obs;
  PlaylistModel? _selectedPlaylist;

  late AnimationController _scaleController;
  late AnimationController _listController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _dialogController = Get.find<PlaylistDialogController>();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _listController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _listController.dispose();
    newPlaylistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final dialogWidth = isTablet ? 500.0 : screenSize.width * 0.9;

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
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
                _buildHeader(colorScheme, isTablet),
                Flexible(child: _buildContent(colorScheme, isTablet)),
                _buildActions(colorScheme, isTablet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, bool isTablet) {
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

  Widget _buildContent(ColorScheme colorScheme, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Create new playlist section
          _buildCreatePlaylistSection(colorScheme, isTablet),

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
          Flexible(child: _buildPlaylistsList(colorScheme, isTablet)),
        ],
      ),
    );
  }

  Widget _buildCreatePlaylistSection(ColorScheme colorScheme, bool isTablet) {
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
            final isPublic = _isPublicNewPlaylist.value;
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
                    if (val) _isPublicNewPlaylist.value = false;
                  },
                  selectedColor: colorScheme.secondaryContainer,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Public'),
                  selected: isPublic,
                  onSelected: (val) {
                    if (val) _isPublicNewPlaylist.value = true;
                  },
                  selectedColor: colorScheme.secondaryContainer,
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: newPlaylistCtrl,
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
                  child: _dialogController.isCreatingPlaylist.value
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
                          onPressed: _createNewPlaylist,
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
            onSubmitted: (_) => _createNewPlaylist(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsList(ColorScheme colorScheme, bool isTablet) {
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
        opacity: _listAnimation,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: allPlaylists.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final playlist = allPlaylists[index];
            return _buildPlaylistItem(playlist, colorScheme, isTablet, index);
          },
        ),
      );
    });
  }

  Widget _buildPlaylistItem(
    PlaylistModel playlist,
    ColorScheme colorScheme,
    bool isTablet,
    int index,
  ) {
    return Obx(() {
      final isSelected =
          _dialogController.selectedPlaylistId.value == playlist.id;

      final isWatchLater = playlist.id == 'watchlater';
      final isInPlaylist = isWatchLater
          ? playlistController.isInWatchLater(widget.videoId)
          : playlist.videoIds.contains(widget.videoId);

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
            onTap: () => _selectPlaylist(playlist),
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

  Widget _buildLoadingState(ColorScheme colorScheme, bool isTablet) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'Loading playlists...',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildActions(ColorScheme colorScheme, bool isTablet) {
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
                final selectedId = _dialogController.selectedPlaylistId.value;
                final isSelected = selectedId.isNotEmpty;
                final isWatchLater = selectedId == 'watchlater';
                final isInWatchLater =
                    isWatchLater &&
                    playlistController.isInWatchLater(widget.videoId);
                final isInPlaylist =
                    !isWatchLater &&
                    isSelected &&
                    (_selectedPlaylist?.videoIds.contains(widget.videoId) ??
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
                      isSelected && !_dialogController.isAddingToPlaylist.value
                      ? _addVideoToPlaylist
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
                  child: _dialogController.isAddingToPlaylist.value
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

  void _selectPlaylist(PlaylistModel playlist) {
    _dialogController.setSelectedPlaylist(playlist.id);
    _selectedPlaylist = playlist;
  }

  Future<void> _createNewPlaylist() async {
    final name = newPlaylistCtrl.text.trim();
    if (name.isEmpty || _dialogController.isCreatingPlaylist.value) return;

    final nameVal = ContentValidator.validate(name, fieldName: 'Playlist Name');
    if (!nameVal.isValid) {
      Get.snackbar(
        'Inappropriate Content',
        nameVal.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    _dialogController.setCreatingPlaylist(true);

    try {
      final messenger = ScaffoldMessenger.of(context);
      final theme = Theme.of(context);
      final navigator = Navigator.of(context);

      final newPlaylist = await playlistController.createPlayList(
        name,
        isPublic: _isPublicNewPlaylist.value,
        videoIds: [widget.videoId],
      );

      newPlaylistCtrl.clear();

      if (mounted) {
        navigator.pop();
        if (newPlaylist != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Playlist "$name" created and video added!'),
              backgroundColor: theme.colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create playlist: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        _dialogController.setCreatingPlaylist(false);
      }
    }
  }

  Future<void> _addVideoToPlaylist() async {
    final selectedId = _dialogController.selectedPlaylistId.value;
    if (selectedId.isEmpty || _dialogController.isAddingToPlaylist.value) {
      return;
    }

    _dialogController.setAddingToPlaylist(true);
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);

    try {
      if (selectedId == 'watchlater') {
        final wasIn = playlistController.isInWatchLater(widget.videoId);
        await playlistController.toggleWatchLater(widget.videoId);
        if (mounted) {
          navigator.pop();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                wasIn ? 'Removed from Watch Later' : 'Added to Watch Later',
              ),
              backgroundColor: theme.colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        final isPublic = _selectedPlaylist?.isPublic ?? false;
        final isAlreadyIn =
            _selectedPlaylist?.videoIds.contains(widget.videoId) ?? false;

        if (isAlreadyIn) {
          await playlistController.removeVideoFromPlaylist(
            selectedId,
            widget.videoId,
            isPublic,
          );
          if (mounted) {
            navigator.pop();
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Removed from playlist successfully'),
                backgroundColor: theme.colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        } else {
          await playlistController.addVideoToPlaylist(
            selectedId,
            widget.videoId,
            isPublic,
          );
          if (mounted) {
            navigator.pop();
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Video added to playlist successfully'),
                backgroundColor: theme.colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        _dialogController.setAddingToPlaylist(false);
      }
    }
  }
}
