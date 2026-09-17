import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for editing a playlist name with validation and profanity filtering.
void showEditPlaylistDialogModal({
  required BuildContext context,
  required PlaylistModel playlist,
  required PlaylistController playlistController,
}) {
  final editController = TextEditingController(text: playlist.playlistName);

  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Edit Playlist',
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: editController,
          inputFormatters: TruthworldTextInputFormatters.standard,
          style: GoogleFonts.roboto(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Playlist Name',
            labelStyle: GoogleFonts.roboto(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            hintText: 'Enter new name',
            hintStyle: GoogleFonts.roboto(
              color: Colors.white.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: AppColors.bgSurfaceHover,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = editController.text.trim();
              final validation = ContentValidator.validate(
                newName,
                fieldName: 'Playlist Name',
                maxLength: 100,
              );
              if (!validation.isValid) {
                AppSnackbar.warning(validation.message);
                return;
              }
              playlistController.editPlaylist(
                playlist.id,
                newName,
                playlist.isPublic,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}
