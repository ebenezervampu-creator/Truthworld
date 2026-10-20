import 'package:flutter/material.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet for creating a new playlist directly from the content upload workflow
void showCreatePlaylistBottomSheet(
  BuildContext context,
  bool isDark, {
  required UploadController uploadController,
  required PlaylistController playlistController,
}) {
    final playListNameController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) {
        const isPublic = true;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: const Border(
              top: BorderSide(
                color: AppColors.bgDivider,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: isTablet ? 32 : 24,
              right: isTablet ? 32 : 24,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1DB954).withValues(alpha: 0.2),
                            const Color(0xFF106E3A).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.playlist_add_rounded,
                        color: Color(0xFF1DB954),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Playlist',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontSize: isTablet ? 26 : 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Name your new collection',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: playListNameController,
                    maxLength: 100,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                    style: AppTextStyles.inputText,
                    decoration: InputDecoration(
                      labelText: 'Playlist Name',
                      labelStyle: AppTextStyles.inputHint,
                      hintText: 'Enter a descriptive name...',
                      hintStyle: AppTextStyles.inputHint,
                      prefixIcon: const Icon(
                        Icons.title_rounded,
                        color: AppColors.textTertiary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: AppColors.bgDivider,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: AppColors.bgDivider,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFF1DB954),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1DB954), Color(0xFF106E3A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 20 : 18,
                        horizontal: 24,
                      ),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    label: Text(
                      'CREATE PLAYLIST',
                      style: AppTextStyles.buttonText.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isTablet ? 17 : 16,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () async {
                      final playlistName = playListNameController.text.trim();
                      if (playlistName.isEmpty) {
                        AppSnackbar.warning(
                          'Please enter a playlist name',
                          title: 'Missing Information',
                        );
                        return;
                      }

                      final nameVal = ContentValidator.validate(
                        playlistName,
                        fieldName: 'Playlist Name',
                        maxLength: 100,
                      );
                      if (!nameVal.isValid) {
                        AppSnackbar.warning(
                          nameVal.message,
                          title: 'Content Notice',
                        );
                        return;
                      }

                      Navigator.pop(context);

                      // Create the playlist and get the result
                      final createdPlaylist = await playlistController
                          .createPlayList(
                            playlistName,
                            isPublic: isPublic,
                            videoIds: uploadController.currentVideoId != null
                                ? [uploadController.currentVideoId!]
                                : [],
                          );

                      playListNameController.clear();

                      if (createdPlaylist != null) {
                        // Refresh playlists to get the latest data
                        playlistController.refreshPlaylistsTick();
                        await playlistController.refreshPlaylists();

                        // Select the newly created playlist using the returned object
                        uploadController.selectPlaylist(createdPlaylist.id);
                        debugPrint(
                          '✅ Selected newly created playlist: ${createdPlaylist.playlistName} (${createdPlaylist.id})',
                        );
                        AppSnackbar.success(
                          'Playlist created successfully!',
                          title: 'Created',
                        );
                      } else {
                        AppSnackbar.error(
                          'Unable to create playlist. Please try again.',
                          title: 'Action Incomplete',
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

}
