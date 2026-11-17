import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/ai_dubbing_tab_view.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/direct_track_tab_view.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_language_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_mode_switcher.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for configuring AI Audio Dubbing and Direct Audio Tracks.
/// Reuses the shared TruthWorld minimalist components and supports multi-language
/// batch generation as well as direct audio uploads.
class AudioTrackDubbingOptionsDialog extends StatelessWidget {
  AudioTrackDubbingOptionsDialog({
    required this.controller,
    required this.isDarkMode,
    this.initialLangCode = '',
    this.allowLanguageSwitch = true,
    this.initialTierId,
    this.initialMediaType = 'audio',
    super.key,
  }) : state = DubbingOptionsState(
          controller: controller,
          initialLangCode: initialLangCode,
          allowLanguageSwitch: allowLanguageSwitch,
          initialTierId: initialTierId,
          initialMediaType: initialMediaType,
        );

  final AudioTracksController controller;
  final String initialLangCode;
  final bool isDarkMode;
  final bool allowLanguageSwitch;
  final String? initialTierId;
  final String initialMediaType;

  final DubbingOptionsState state;

  // Convenience accessors
  RxString get selectedLangCode => state.selectedLangCode;
  RxList<String> get selectedLangCodes => state.selectedLangCodes;
  RxInt get selectedTab => state.selectedTab;
  RxString get selectedDubbingTier => state.selectedDubbingTier;
  RxString get selectedMediaMode => state.selectedMediaMode;
  RxString get voiceType => state.voiceType;
  RxBool get enableDiarization => state.enableDiarization;
  RxString get selectedVoiceGender => state.selectedVoiceGender;
  RxBool get isGenerating => state.isGenerating;
  Rx<PlatformFile?> get selectedDirectFile => state.selectedDirectFile;
  RxBool get isUploadingDirect => state.isUploadingDirect;
  Rx<SpendableBalance?> get spendableBalance => state.spendableBalance;
  Rx<Channel?> get currentChannel => state.currentChannel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;
    final video = controller.selectedVideo.value;
    final durationSeconds = (video != null && video.durationSeconds > 0)
        ? video.durationSeconds
        : (video?.durationValue.inSeconds ?? 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio Track & Dubbing',
                            style: typography.display.copyWith(
                              fontFamily: TWTypography.brandFamily,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create a new audio track or dub your video into another language.',
                            style: typography.bodySmall.copyWith(
                              fontSize: 12.5,
                              color: colors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Get.back<void>(),
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 1. Segmented Mode Switcher
                DubbingModeSwitcher(state: state),

                const SizedBox(height: 14),

                // Original Video Language Indicator Card with Change Action
                _buildOriginalLanguageBar(context, colors, typography),

                const SizedBox(height: 14),

                // 2. Target Language(s) Selector Card
                DubbingLanguageBar(state: state),

                const SizedBox(height: 12),

                // 3. Mode-specific Settings & CTA
                Obx(() {
                  if (state.selectedTab.value == 0) {
                    return AiDubbingTabView(
                      state: state,
                      durationSeconds: durationSeconds,
                      onGenerate: () => state.handleGenerateAiDubbing(context),
                    );
                  }
                  return DirectTrackTabView(
                    state: state,
                    durationLabel: video?.duration ?? '00:00',
                    onUpload: () => state.handleUploadDirectTrack(context),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOriginalLanguageBar(
    BuildContext context,
    TWColors colors,
    TWTypography typography,
  ) {
    return Obx(() {
      final currentVideo = controller.selectedVideo.value;
      final baseLang = normalizeLanguageCode(currentVideo?.language ?? 'en');
      final baseLangName = controller.getLanguageName(baseLang);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            buildLanguageFlag(baseLang, width: 22, height: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Video Language',
                    style: typography.bodySmall.copyWith(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    baseLangName,
                    style: typography.body.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                AudioTracksDialogs.showOriginalLanguageSelectorModal(
                  context: context,
                  controller: controller,
                  isDarkMode: isDarkMode,
                );
              },
              icon: Icon(Icons.edit_rounded, size: 12, color: colors.textPrimary),
              label: Text(
                'Change',
                style: typography.label.copyWith(
                  color: colors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
