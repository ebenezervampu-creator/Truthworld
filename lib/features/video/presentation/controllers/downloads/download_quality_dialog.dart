import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_resolution_manager.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet dialog allowing users to pick video resolution or audio-only offline format.
class DownloadQualityDialog {
  /// Displays the interactive quality & resolution selection bottom sheet.
  static void show(
    BuildContext? context,
    Video video, {
    required Future<List<VideoResolutionV2>> Function(Video video)
        getResolutions,
    required Function(VideoResolutionV2 resolution) onResolutionSelected,
    required VoidCallback onAudioSelected,
  }) {
    final targetContext = context ?? Get.overlayContext ?? Get.context;
    if (targetContext == null) return;

    showModalBottomSheet(
      context: targetContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: FutureBuilder<List<VideoResolutionV2>>(
            future: getResolutions(video),
            builder: (context, snapshot) {
              final resolutions = snapshot.data ?? [];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.download_for_offline,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Download Quality',
                                  style: GoogleFonts.roboto(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),

                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else ...[
                      // Resolutions List
                      ...resolutions.map((res) {
                        final badgeText =
                            DownloadResolutionManager.getResolutionBadge(
                          res.label,
                          res.height,
                        );
                        return ListTile(
                          leading: const Icon(
                            Icons.video_file_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          title: Row(
                            children: [
                              Text(
                                res.label,
                                style: GoogleFonts.roboto(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (badgeText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Save video for offline viewing',
                            style: GoogleFonts.roboto(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            onResolutionSelected(res);
                          },
                        );
                      }),

                      // Audio Only Tile
                      ListTile(
                        leading: const Icon(
                          Icons.headphones_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        title: Text(
                          'Audio only',
                          style: GoogleFonts.roboto(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Save audio for offline listening (saves storage & data)',
                          style: GoogleFonts.roboto(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Audio only',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          onAudioSelected();
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
