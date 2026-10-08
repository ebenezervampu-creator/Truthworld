import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Audio and commentary tracks list section displaying all configured tracks for active language.
class AudioTracksListSection extends StatelessWidget {
  const AudioTracksListSection({
    required this.video,
    required this.controller,
    required this.textColor,
    required this.textSecondaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.onAddDubTrack,
    required this.onAddCommentary,
    required this.onPickAndUploadSingleDub,
    super.key,
  });

  final Video video;
  final AudioTracksController controller;
  final Color textColor;
  final Color textSecondaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDarkMode;
  final VoidCallback onAddDubTrack;
  final VoidCallback onAddCommentary;
  final Future<void> Function(String langCode) onPickAndUploadSingleDub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingTracks.value) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1E1E1E),
          highlightColor: AppColors.bgSurfaceHover,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => Container(
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      }

      final audioList = controller.currentTracks;
      final commentaryList = controller.commentaryTracks;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Audio Dubbing Section
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audio Dubbing & Voiceover Tracks (${audioList.length})',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onAddDubTrack,
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Add Dub Track', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (audioList.isEmpty)
            EmptyTrackCard(
              message: 'No audio dub tracks configured for this language.',
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
            )
          else
            ...audioList.asMap().entries.map((entry) {
              final index = entry.key;
              final track = entry.value;
              return AudioTrackCard(
                index: index,
                track: track,
                controller: controller,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                isDarkMode: isDarkMode,
                onUploadAudioFile: () => onPickAndUploadSingleDub(track.languageCode),
              );
            }),

          const SizedBox(height: 24),

          // Commentary & Multi-Video Section
          Row(
            children: [
              const Icon(Icons.subtitles_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Commentary & Alternate Video Tracks (${commentaryList.length})',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onAddCommentary,
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Add Commentary', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (commentaryList.isEmpty)
            EmptyTrackCard(
              message: 'No commentary or alternate angle tracks attached.',
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
            )
          else
            ...commentaryList.map((track) {
              return CommentaryTrackCard(
                track: track,
                controller: controller,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              );
            }),
        ],
      );
    });
  }
}

/// Card displaying audio dub track stream metadata and URL controls.
class AudioTrackCard extends StatelessWidget {
  const AudioTrackCard({
    required this.index,
    required this.track,
    required this.controller,
    required this.textColor,
    required this.textSecondaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.onUploadAudioFile,
    super.key,
  });

  final int index;
  final AudioTrackItem track;
  final AudioTracksController controller;
  final Color textColor;
  final Color textSecondaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDarkMode;
  final VoidCallback onUploadAudioFile;

  @override
  Widget build(BuildContext context) {
    final isBase = track.isBaseTrack;
    final trackUrlController = TextEditingController(text: track.audioUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBase ? AppColors.success.withValues(alpha: 0.5) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Track Top Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isBase
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBase ? Icons.volume_up_rounded : Icons.translate_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            track.languageName,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBase
                                  ? AppColors.success.withValues(alpha: 0.2)
                                  : AppColors.info.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isBase ? 'Primary Base Audio' : 'Dubbed Track',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isBase ? AppColors.success : AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBase
                            ? 'Original video master audio stream'
                            : 'Multi-Language Audio Voiceover Track Stream',
                        style: TextStyle(fontSize: 12, color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),

                // Replace / Upload Audio File Button
                if (!isBase)
                  IconButton(
                    tooltip: 'Upload / Replace Audio File',
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18, color: Colors.white),
                    onPressed: onUploadAudioFile,
                  ),

                // Download Audio Track Button
                IconButton(
                  tooltip: 'Download Audio Track',
                  icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                  onPressed: () => controller.downloadAudioTrack(track),
                ),

                // Copy Reference Link Button
                IconButton(
                  tooltip: 'Copy Reference Link',
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: track.audioUrl));
                    AppSnackbar.success('Track URL copied to clipboard.');
                  },
                ),

                // Delete Track Button
                if (!isBase)
                  IconButton(
                    tooltip: 'Delete Track',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
                    onPressed: () => controller.removeDubForLanguage(track.languageCode),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Stream URL Input Box
            Text(
              'Storage Stream URL Reference:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondaryColor),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: trackUrlController,
              inputFormatters: [TruthworldTextInputFormatters.englishOnly],
              style: TextStyle(fontSize: 13, color: textColor, fontFamily: 'monospace'),
              onChanged: (val) => controller.updateTrackUrl(index, val),
              decoration: InputDecoration(
                hintText: 'Provide direct HTTPS audio target file URI e.g. https://...',
                hintStyle: TextStyle(fontSize: 12, color: textSecondaryColor),
                prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Colors.white),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card displaying commentary audio and alternate video angle track.
class CommentaryTrackCard extends StatelessWidget {
  const CommentaryTrackCard({
    required this.track,
    required this.controller,
    required this.textColor,
    required this.textSecondaryColor,
    required this.surfaceColor,
    required this.borderColor,
    super.key,
  });

  final CommentaryTrackItem track;
  final AudioTracksController controller;
  final Color textColor;
  final Color textSecondaryColor;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.video_collection_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: ${track.role} • Lang: ${track.langCode.toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Download Track',
            icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
            onPressed: () => controller.downloadCommentaryTrack(track),
          ),
          IconButton(
            tooltip: 'Copy Reference Link',
            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white),
            onPressed: () => controller.exportTrackLinkToClipboard(track.videoUrl),
          ),
          IconButton(
            tooltip: 'Delete Track',
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
            onPressed: () => controller.deleteCommentaryTrack(track.id),
          ),
        ],
      ),
    );
  }
}

/// Fallback card when no audio or commentary tracks exist.
class EmptyTrackCard extends StatelessWidget {
  const EmptyTrackCard({
    required this.message,
    required this.textColor,
    required this.textSecondaryColor,
    required this.surfaceColor,
    required this.borderColor,
    super.key,
  });

  final String message;
  final Color textColor;
  final Color textSecondaryColor;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: textSecondaryColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
