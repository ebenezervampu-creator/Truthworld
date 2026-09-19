import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_dialogs.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Desktop-specific sidebar showing quick actions, library search, and user playlists.
class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    required this.userId,
    super.key,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore;

  final String userId;
  final FirebaseFirestore? _firestore;

  Stream<QuerySnapshot> _getSidebarPlaylistsStream() {
    final db = _firestore ?? FirebaseFirestore.instance;
    return db
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.playlists)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 32),
          _buildSidebarSearch(),
          const SizedBox(height: 40),
          _buildSidebarQuickActions(context),
          const SizedBox(height: 40),
          Expanded(child: _buildSidebarPlaylists()),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final authService = AuthService.to;
    final displayName = authService.activeDisplayName;
    final handleOrEmail =
        authService.hasChannel.value && authService.userChannel != null
            ? authService.activeHandle
            : (authService.user?.email ?? '');

    return Row(
      children: [
        InkWell(
          onTap: StudioLauncher.openStudio,
          child: UserAvatar(
            radius: 24,
            photoUrl: authService.activePhotoUrl,
            displayName: displayName,
            backgroundColor: buttonBg,
            textColor: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              if (handleOrEmail.isNotEmpty)
                Text(
                  handleOrEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        inputFormatters: [TruthworldTextInputFormatters.englishOnly],
        style: const TextStyle(color: primaryText, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search in library...',
          hintStyle: TextStyle(color: secondaryText),
          border: InputBorder.none,
          icon: Icon(
            Icons.search_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSidebarQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _buildSidebarAction(
          icon: Icons.add_box_rounded,
          title: 'New Playlist',
          onTap: () => LibraryDialogs.showCreatePlaylistDialog(context),
        ),
        _buildSidebarAction(
          icon: Icons.history_rounded,
          title: 'Watch History',
          onTap: () => Get.toNamed('/watchhistory'),
        ),
        _buildSidebarAction(
          icon: Icons.video_collection_rounded,
          title: 'My Videos',
          onTap: () => Get.toNamed('/myvideos'),
        ),
        _buildSidebarAction(
          icon: Icons.thumb_up_rounded,
          title: 'Liked Videos',
          onTap: () => Get.toNamed('/likedvideos'),
        ),
        _buildSidebarAction(
          icon: Icons.settings_rounded,
          title: 'Settings',
          onTap: () => Get.toNamed('/settings'),
        ),
      ],
    );
  }

  Widget _buildSidebarAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, color: primaryText, size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarPlaylists() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PLAYLISTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getSidebarPlaylistsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No playlists yet',
                  style: TextStyle(color: secondaryText, fontSize: 13),
                );
              }

              final playlists = snapshot.data!.docs
                  .map(PlaylistModel.fromDocumentSnapshot)
                  .where((p) => p.thumbnailUrl.trim().isNotEmpty)
                  .toList();

              if (playlists.isEmpty) {
                return const Text(
                  'No playlists yet',
                  style: TextStyle(color: secondaryText, fontSize: 13),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return _buildSidebarPlaylistTile(playlist);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarPlaylistTile(PlaylistModel playlist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(6),
          image: playlist.thumbnailUrl.isNotEmpty
              ? DecorationImage(
                  image: CachedNetworkImageProvider(playlist.thumbnailUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {},
                )
              : null,
        ),
        child: playlist.thumbnailUrl.isEmpty
            ? const Icon(
                Icons.playlist_play,
                color: AppColors.textPrimary,
                size: 16,
              )
            : null,
      ),
      title: Text(
        playlist.playlistName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          color: primaryText,
        ),
      ),
      onTap: () {
        if (Get.isRegistered<HomeController>()) {
          final homeController = Get.find<HomeController>();
          homeController.navigateToPlaylistDetail(playlist);
        } else {
          Get.toNamed('/', arguments: {'openPlaylist': playlist});
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
