import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean, high-contrast video header and action toolbar matching Channel Creation style.
class AudioTracksWorkspaceHeader extends StatelessWidget {
  const AudioTracksWorkspaceHeader({
    required this.video,
    required this.controller,
    required this.showPreviewPlayer,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.onUploadTrack,
    this.onChangeVideo,
    super.key,
  });

  final Video video;
  final AudioTracksController controller;
  final RxBool showPreviewPlayer;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final VoidCallback onUploadTrack;
  final VoidCallback? onChangeVideo;

  Widget _buildSaveButton({bool compact = false}) {
    return Obx(() {
      final isSaving = controller.isSaving.value;
      return ElevatedButton.icon(
        onPressed: isSaving ? null : controller.saveCurrentAudioTracks,
        icon: isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Icon(Icons.save_rounded, size: 16, color: Colors.black),
        label: Text(
          isSaving ? 'Saving...' : 'Save Changes',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Thumbnail + Title + Metadata + Optional Change Video
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  width: 64,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 64,
                    height: 44,
                    color: AppColors.bgInput,
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Obx(() {
                          final count = controller.availableLanguages.length;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$count Dub Languages',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }),
                        Text(
                          'Duration: ${video.duration}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onChangeVideo != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onChangeVideo,
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Change',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    side: const BorderSide(color: AppColors.bgSurface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.bgSurface),
          const SizedBox(height: 14),

          // Actions Row: Clean toolbar matching channel creation actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Primary: Upload Track
                ElevatedButton.icon(
                  onPressed: onUploadTrack,
                  icon: const Icon(
                    Icons.cloud_upload_rounded,
                    size: 16,
                    color: Colors.black,
                  ),
                  label: const Text(
                    'Upload Track',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Preview Toggle Button
                Obx(() {
                  final isShowing = showPreviewPlayer.value;
                  return OutlinedButton.icon(
                    onPressed: () => showPreviewPlayer.value = !isShowing,
                    icon: Icon(
                      isShowing
                          ? Icons.visibility_off_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      isShowing ? 'Hide Preview' : 'Preview Sync',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isShowing
                          ? AppColors.bgSurface
                          : AppColors.bgPage,
                      side: const BorderSide(color: AppColors.bgSurface),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),

                // Requests Button
                Obx(() {
                  final showRequests = controller.showRequestsPanel.value;
                  final reqCount = controller.languageRequests
                      .where((r) => r.type == 'audio')
                      .length;

                  return OutlinedButton.icon(
                    onPressed: controller.toggleRequestsPanel,
                    icon: const Icon(
                      Icons.mark_chat_unread_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      showRequests ? 'Close Requests' : 'Requests ($reqCount)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: showRequests
                          ? AppColors.bgSurface
                          : AppColors.bgPage,
                      side: const BorderSide(color: AppColors.bgSurface),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),

                // Save Button
                _buildSaveButton(compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile responsive action toolbar matching the clean theme.
class AudioTracksMobileToolbar extends StatelessWidget {
  const AudioTracksMobileToolbar({
    required this.video,
    required this.controller,
    required this.showPreviewPlayer,
    required this.surfaceColor,
    required this.borderColor,
    required this.onUploadTrack,
    this.onChangeVideo,
    super.key,
  });

  final Video video;
  final AudioTracksController controller;
  final RxBool showPreviewPlayer;
  final Color surfaceColor;
  final Color borderColor;
  final VoidCallback onUploadTrack;
  final VoidCallback? onChangeVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: onUploadTrack,
            icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.black),
            label: const Text(
              'Upload Track',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => showPreviewPlayer.value = !showPreviewPlayer.value,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Preview',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: controller.saveCurrentAudioTracks,
            icon: const Icon(Icons.save_rounded, size: 16, color: Colors.black),
            label: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
