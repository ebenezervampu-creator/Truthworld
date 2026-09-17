import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Active video header banner and action toolbar for desktop & tablet.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Video Thumbnail + Full-Width Title & Metadata + Save Button
          Row(
            children: [
              // Video Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  width: 72,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Obx(() {
                            final count = controller.availableLanguages.length;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count Dub Languages',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Original: English',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textSecondaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• Duration: ${video.duration}',
                            style: TextStyle(fontSize: 11, color: textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Save Changes Button (Primary Action Top Right)
              Obx(() {
                return ElevatedButton.icon(
                  onPressed: controller.isSaving.value ? null : controller.saveCurrentAudioTracks,
                  icon: controller.isSaving.value
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                  label: Text(
                    controller.isSaving.value ? 'Saving...' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Row: Action Toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Preview Player Toggle Button
                Obx(() => OutlinedButton.icon(
                  onPressed: () => showPreviewPlayer.value = !showPreviewPlayer.value,
                  icon: Icon(
                    showPreviewPlayer.value ? Icons.visibility_off_rounded : Icons.play_circle_outline_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    showPreviewPlayer.value ? 'Hide Preview' : 'Preview Sync',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(
                      color: showPreviewPlayer.value
                          ? AppColors.brand
                          : (isDarkMode ? const Color(0xFF333333) : AppColors.bgDivider),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
                const SizedBox(width: 8),

                // Upload Track Button
                ElevatedButton.icon(
                  onPressed: onUploadTrack,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                  label: const Text('Upload Track', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
                    foregroundColor: textColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),

                // Download Audio Button
                OutlinedButton.icon(
                  onPressed: () {
                    final tracks = controller.currentTracks;
                    if (tracks.isNotEmpty) {
                      controller.downloadAudioTrack(tracks.first);
                    } else {
                      controller.showError('No audio track available to download.');
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Download Audio',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(color: isDarkMode ? const Color(0xFF333333) : AppColors.bgDivider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),

                // Viewer Requests Button
                Obx(() {
                  final hasReqs = controller.languageRequests.where((r) => r.type == 'audio').isNotEmpty;
                  final showRequests = controller.showRequestsPanel.value;
                  final reqCount = controller.languageRequests.where((r) => r.type == 'audio').length;

                  return Badge(
                    isLabelVisible: hasReqs && !showRequests,
                    label: Text('$reqCount'),
                    backgroundColor: AppColors.brand,
                    textColor: Colors.black,
                    child: OutlinedButton.icon(
                      onPressed: controller.toggleRequestsPanel,
                      icon: const Icon(
                        Icons.mark_chat_unread_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        showRequests ? 'Close Requests' : 'Requests ($reqCount)',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(
                          color: showRequests
                              ? AppColors.brand
                              : (isDarkMode ? const Color(0xFF333333) : AppColors.bgDivider),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile responsive action toolbar for quick upload, preview, and save.
class AudioTracksMobileToolbar extends StatelessWidget {
  const AudioTracksMobileToolbar({
    required this.video,
    required this.controller,
    required this.showPreviewPlayer,
    required this.surfaceColor,
    required this.borderColor,
    required this.onUploadTrack,
    super.key,
  });

  final Video video;
  final AudioTracksController controller;
  final RxBool showPreviewPlayer;
  final Color surfaceColor;
  final Color borderColor;
  final VoidCallback onUploadTrack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: onUploadTrack,
            icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
            label: const Text('Upload Track'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          Obx(() => OutlinedButton.icon(
            onPressed: () => showPreviewPlayer.value = !showPreviewPlayer.value,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: Colors.white),
            label: Text(showPreviewPlayer.value ? 'Hide Preview' : 'Preview'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )),
          Obx(() {
            final showRequests = controller.showRequestsPanel.value;
            final reqCount = controller.languageRequests.where((r) => r.type == 'audio').length;
            return OutlinedButton.icon(
              onPressed: controller.toggleRequestsPanel,
              icon: const Icon(Icons.mark_chat_unread_rounded, size: 16, color: Colors.white),
              label: Text(showRequests ? 'Close Requests' : 'Requests ($reqCount)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          }),
          ElevatedButton.icon(
            onPressed: controller.isSaving.value ? null : controller.saveCurrentAudioTracks,
            icon: controller.isSaving.value
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
            label: Text(controller.isSaving.value ? 'Saving' : 'Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
