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
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      title: const Text(
        'Move to Trash?',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontFamily: TWTypography.brandFamily,
        ),
      ),
      content: Text(
        'Are you sure you want to move "${playlist.name}" to Trash? Deleted items are retained for 30 days before permanent deletion.',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontFamily: TWTypography.uiFamily,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: TWTypography.uiFamily,
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Move to Trash',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
        ),
      ],
    );
  }
}
