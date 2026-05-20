import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_dialog_controller.dart';
import 'package:truthworld/data/models/playlist_model.dart';

final playlistController = Get.put(PlaylistController());
final playlistDialogController = Get.put(PlaylistDialogController());

void showPlaylistDialog({
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
            seedColor: Color(0xFF8B5CF6),
            brightness: Theme.of(context).brightness,
          ),
        ),
        child: _PlaylistDialog(
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

class _PlaylistDialog extends StatefulWidget {
  final String videoId;
  final Animation<double> animation;

  const _PlaylistDialog({
    required this.videoId,
    required this.animation,
  });

  @override
  State<_PlaylistDialog> createState() =>
      _PlaylistDialogState();
}

class _PlaylistDialogState extends State<_PlaylistDialog>
    with TickerProviderStateMixin {
  final TextEditingController newPlaylistCtrl = TextEditingController();
  late PlaylistDialogController _dialogController;

  late AnimationController _scaleController;
  late AnimationController _listController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _dialogController = Get.put(PlaylistDialogController());
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _listAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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
            margin: EdgeInsets.all(20),
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
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              color: colorScheme.primary,
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
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
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
                padding: EdgeInsets.symmetric(horizontal: 16),
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
      padding: EdgeInsets.all(16),
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
                color: colorScheme.secondary,
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
                          padding: EdgeInsets.all(12),
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
                          icon: Icon(
                            Icons.add_rounded,
                            color: colorScheme.secondary,
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection("playlists")
          //.orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(colorScheme, isTablet);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(colorScheme, isTablet);
        }

        final playlists = snapshot.data!.docs
            .map((doc) => PlaylistModel.fromDocumentSnapshot(doc))
            .toList();

        return FadeTransition(
          opacity: _listAnimation,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: playlists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _buildPlaylistItem(playlist, colorScheme, isTablet, index);
            },
          ),
        );
      },
    );
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

      return AnimatedContainer(
        duration: Duration(milliseconds: 200 + (index * 50)),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectPlaylist(playlist.id),
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
                  // Playlist icon
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
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(
                          playlist.thumbnailUrl,
                        ),
                        fit: BoxFit.cover,
                      ),
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
                              color: Colors.white,
                              size: 20,
                            ),
                          )
                        : Icon(
                            Icons.playlist_play_rounded,
                            color: colorScheme.onSurfaceVariant,
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
                          '${playlist.videoIds.length} videos',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selection indicator
                  AnimatedScale(
                    scale: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: colorScheme.onTertiary,
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.playlist_add_outlined,
              size: isTablet ? 48 : 40,
              color: colorScheme.tertiary,
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
              () => ElevatedButton(
                onPressed:
                    _dialogController.selectedPlaylistId.value.isNotEmpty &&
                        !_dialogController.isAddingToPlaylist.value
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
                        'Add Video',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectPlaylist(String playlistId) {
    _dialogController.setSelectedPlaylist(playlistId);
  }

  Future<void> _createNewPlaylist() async {
    final name = newPlaylistCtrl.text.trim();
    if (name.isEmpty || _dialogController.isCreatingPlaylist.value) return;

    _dialogController.setCreatingPlaylist(true);

    try {
      await playlistController.createPlayList(name, isPublic: false);

      newPlaylistCtrl.clear();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playlist "$name" created successfully'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
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
    if (_dialogController.selectedPlaylistId.value.isEmpty ||
        _dialogController.isAddingToPlaylist.value) {
      return;
    }

    _dialogController.setAddingToPlaylist(true);

    try {
      await playlistController.addVideoToPlaylist(
        _dialogController.selectedPlaylistId.value,
        widget.videoId,
        false,
      );

      if (mounted) {
        Navigator.of(context).pop();

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Video added to playlist successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add video: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        _dialogController.setAddingToPlaylist(false);
      }
    }
  }
}





