import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_language_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_mode_switcher.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Direct Audio Track upload tab view matching TruthWorld's minimalist dark-card
/// aesthetic and supporting single or multi-language track attachments.
class DirectTrackTabView extends StatelessWidget {
  const DirectTrackTabView({
    required this.state,
    required this.durationLabel,
    required this.onUpload,
    super.key,
  });

  final DubbingOptionsState state;
  final String durationLabel;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Studio Reference Audio Card
        DubbingOptionCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 430;
              final durationHint =
                  durationLabel.isNotEmpty ? ' ($durationLabel)' : '';

              final infoRow = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.settings_voice_rounded,
                      color: colors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where to Get Direct Audio Tracks (Studio Guide)',
                          style: typography.title.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Download reference audio$durationHint to record or edit in your external DAW.',
                          style: typography.bodySmall.copyWith(
                            fontSize: 12,
                            color: colors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final downloadBtn = OutlinedButton.icon(
                onPressed: state.controller.downloadOriginalVideoAudio,
                icon: Icon(
                  Icons.download_rounded,
                  size: 15,
                  color: colors.textPrimary,
                ),
                label: Text(
                  'Download Original Audio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.surfaceInput,
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoRow,
                    const SizedBox(height: 12),
                    downloadBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: infoRow),
                  const SizedBox(width: 12),
                  downloadBtn,
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // 2. Direct Audio File Picker Card(s)
        Obx(() {
          final selectedCodes = state.selectedLangCodes.toList();
          final filesByLang = state.directFilesByLang;
          final activeSingleFile = selectedCodes.isNotEmpty
              ? (filesByLang[selectedCodes.first] ??
                  state.selectedDirectFile.value)
              : state.selectedDirectFile.value;

          if (selectedCodes.length <= 1) {
            final targetCode = selectedCodes.isNotEmpty
                ? selectedCodes.first
                : state.selectedLangCode.value;
            final targetName = targetCode.isNotEmpty
                ? state.controller.getLanguageName(targetCode)
                : 'Target Language';

            return _SingleFileUploadCard(
              targetLangCode: targetCode,
              targetLangName: targetName,
              file: activeSingleFile,
              onPick: () => state.pickDirectAudioFile(targetCode),
              onClear: targetCode.isNotEmpty
                  ? () => state.removeDirectFileForLanguage(targetCode)
                  : null,
            );
          }

          return DubbingOptionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach Audio Files by Language',
                  style: typography.title.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upload .mp3, .wav, .m4a, or .aac files for each selected language.',
                  style: typography.bodySmall.copyWith(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < selectedCodes.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _MultiLangFileRow(
                    langCode: selectedCodes[i],
                    langName: state.controller.getLanguageName(selectedCodes[i]),
                    file: filesByLang[selectedCodes[i]],
                    onPick: () => state.pickDirectAudioFile(selectedCodes[i]),
                    onClear: () =>
                        state.removeDirectFileForLanguage(selectedCodes[i]),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 24),

        // 3. Full-width Monochrome Primary CTA
        Obx(() {
          final selectedCodes = state.selectedLangCodes;
          final filesByLang = state.directFilesByLang;
          final uploading = state.isUploadingDirect.value;

          var attachedCount = 0;
          if (selectedCodes.length <= 1) {
            final hasFile = state.selectedDirectFile.value != null ||
                (selectedCodes.isNotEmpty &&
                    filesByLang[selectedCodes.first] != null);
            attachedCount = hasFile ? 1 : 0;
          } else {
            attachedCount = selectedCodes
                .where((code) => filesByLang[code] != null)
                .length;
          }

          final canUpload = attachedCount > 0 && !uploading;
          final String label;
          if (uploading) {
            label = attachedCount > 1
                ? 'Attaching $attachedCount Tracks...'
                : 'Attaching Track...';
          } else if (attachedCount > 1) {
            label = 'Upload & Attach $attachedCount Tracks';
          } else {
            label = 'Upload & Attach Track';
          }

          return SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: canUpload ? onUpload : null,
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(
                      Icons.upload_file_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
              label: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.button.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SingleFileUploadCard extends StatelessWidget {
  const _SingleFileUploadCard({
    required this.targetLangCode,
    required this.targetLangName,
    required this.file,
    required this.onPick,
    this.onClear,
  });

  final String targetLangCode;
  final String targetLangName;
  final PlatformFile? file;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;
    final hasFile = file != null;

    return DubbingOptionCard(
      onTap: onPick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                hasFile
                    ? Icons.check_circle_rounded
                    : Icons.cloud_upload_outlined,
                color: hasFile ? AppColors.success : colors.textPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Finished Direct Audio Track',
                      style: typography.title.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasFile
                          ? '${file!.name} (${(file!.size / (1024 * 1024)).toStringAsFixed(2)} MB)'
                          : 'Tap to choose audio for $targetLangName (.mp3, .wav, .m4a, .aac)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        fontSize: 12,
                        color: hasFile
                            ? AppColors.success
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFile && onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove file',
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiLangFileRow extends StatelessWidget {
  const _MultiLangFileRow({
    required this.langCode,
    required this.langName,
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final String langCode;
  final String langName;
  final PlatformFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;
    final hasFile = file != null;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile
                ? AppColors.success.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            buildLanguageFlag(langCode, width: 20, height: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hasFile
                        ? '${file!.name} (${(file!.size / (1024 * 1024)).toStringAsFixed(2)} MB)'
                        : 'Tap to attach .mp3, .wav, .m4a, .aac',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.copyWith(
                      fontSize: 11.5,
                      color:
                          hasFile ? AppColors.success : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasFile)
              IconButton(
                onPressed: onClear,
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove file',
              )
            else
              Icon(
                Icons.upload_file_rounded,
                size: 18,
                color: colors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
