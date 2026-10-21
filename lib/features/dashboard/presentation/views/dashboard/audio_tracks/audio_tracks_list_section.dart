import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
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
      if (controller.isLoadingTracks.value && controller.currentTracks.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: StudioLoadingIndicator(
              message: 'Loading audio tracks...',
              isFullScreen: false,
            ),
          ),
        );
      }

      final audioList = controller.currentTracks;
      final commentaryList = controller.commentaryTracks;

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Audio Dubbing Section Header
          Row(
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audio Dubbing & Voiceovers (${audioList.length})',
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onAddDubTrack,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add Dub Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  side: const BorderSide(color: Color(0xFF27272A)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

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

          // Commentary & Multi-Video Section Header
          Row(
            children: [
              const Icon(
                Icons.subtitles_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Commentary & Alternate Tracks (${commentaryList.length})',
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onAddCommentary,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add Commentary',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  side: const BorderSide(color: Color(0xFF27272A)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

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

/// Clean card displaying audio dub track stream metadata and URL controls.
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title & Badge + Action Buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Icon(
                    isBase ? Icons.volume_up_rounded : Icons.translate_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Title, Badge, and Subtitle (Wrapped to never overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            track.languageName,
                            style: const TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27272A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBase ? 'Primary Base Audio' : 'Dubbed Track',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBase
                            ? 'Original video master audio stream'
                            : 'Multi-language voiceover stream',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Icons Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isBase)
                      IconButton(
                        tooltip: 'Upload / Replace Audio File',
                        icon: const Icon(
                          Icons.cloud_upload_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: onUploadAudioFile,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Download Audio Track',
                      icon: const Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () => controller.downloadAudioTrack(track),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Copy Reference Link',
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: track.audioUrl));
                        AppSnackbar.success('Track URL copied to clipboard.');
                      },
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    if (!isBase) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Delete Track',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            controller.removeDubForLanguage(track.languageCode),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stream URL Reference
            const Text(
              'Storage Stream URL Reference:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: trackUrlController,
                      maxLength: 500,
                      buildCounter: (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) =>
                          null,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(500),
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                      onChanged: (val) => controller.updateTrackUrl(index, val),
                      decoration: const InputDecoration(
                        hintText: 'https://storage.googleapis.com/...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean card displaying commentary audio and alternate video angle track.
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
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Icon(
              Icons.video_collection_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: ${track.role} • Lang: ${track.langCode.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Download Track',
            icon: const Icon(
              Icons.download_rounded,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () => controller.downloadCommentaryTrack(track),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Copy Reference Link',
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () =>
                controller.exportTrackLinkToClipboard(track.videoUrl),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Delete Track',
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () => controller.deleteCommentaryTrack(track.id),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
