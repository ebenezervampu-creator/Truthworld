import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/edit_playlist_dialog.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/manage_playlist_videos_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Unified bottom sheet presenting actions for a playlist.
void showPlaylistOptionsSheet({
  required BuildContext context,
  required PlaylistModel playlist,
  PlaylistController? playlistController,
}) {
  final controller = playlistController ?? Get.find<PlaylistController>();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.playlistName,
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PlaylistOptionItem(
                    icon: Icons.share_rounded,
                    title: 'Share Playlist',
                    onTap: () {
                      Navigator.pop(context);
                      controller.sharePlaylist(playlist.id);
                    },
                  ),
                  PlaylistOptionItem(
                    icon: Icons.edit_outlined,
                    title: 'Edit Playlist',
                    onTap: () {
                      Navigator.pop(context);
                      showEditPlaylistDialogModal(
                        context: context,
                        playlist: playlist,
                        playlistController: controller,
                      );
                    },
                  ),
                  PlaylistOptionItem(
                    icon: Icons.video_library_outlined,
                    title: 'Manage Videos',
                    onTap: () {
                      Navigator.pop(context);
                      showManagePlaylistVideosSheet(
                        context: context,
                        playlist: playlist,
                        playlistController: controller,
                      );
                    },
                  ),
                  PlaylistOptionItem(
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete Playlist',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeletePlaylist(context, playlist, controller);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _confirmDeletePlaylist(
  BuildContext context,
  PlaylistModel playlist,
  PlaylistController controller,
) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Playlist?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.playlistName}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deletePlaylist(playlist.id, playlist.isPublic);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}

class PlaylistOptionItem extends StatelessWidget {
  const PlaylistOptionItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? AppColors.error : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.roboto(
                color: isDestructive ? AppColors.error : Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
