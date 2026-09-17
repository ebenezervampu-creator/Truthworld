import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Confirmation dialog to delete a playlist.
class DeletePlaylistConfirmationDialog extends StatelessWidget {
  const DeletePlaylistConfirmationDialog({
    required this.playlist,
    super.key,
  });

  final PlaylistModel playlist;

  static Future<void> show(
    BuildContext context, {
    required PlaylistModel playlist,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DeletePlaylistConfirmationDialog(playlist: playlist),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistsManagementController>();

    return AlertDialog(
      backgroundColor: const Color(0xFF141417),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      title: const Text(
        'Delete Playlist?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Are you sure you want to permanently delete "${playlist.name}"? This action cannot be undone.',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await controller.deletePlaylist(playlist.id);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
