import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/ai_dubbing_tab_view.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/direct_track_tab_view.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_language_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal dialog providing clean, premium ElevenLabs-style options for AI Voice Dubbing and Direct Audio Track.
/// Follows 100% GetX reactive architecture, Zero setState, Zero White-on-White, and Zero Charm-Pricing.
class AudioTrackDubbingOptionsDialog extends StatelessWidget {
  AudioTrackDubbingOptionsDialog({
    required this.controller,
    required this.initialLangCode,
    required this.isDarkMode,
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

  // Convenience accessors for backwards compatibility
  RxString get selectedLangCode => state.selectedLangCode;
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
    final video = controller.selectedVideo.value;
    final durationSeconds = (video != null && video.durationSeconds > 0)
        ? video.durationSeconds
        : (video?.durationValue.inSeconds ?? 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                _buildHeader(context),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Language Selector
                      DubbingLanguageBar(state: state),

                      const SizedBox(height: 12),

                      // 2. Segmented Mode Switcher
                      _buildSegmentedTabSwitcher(),

                      const SizedBox(height: 14),

                      // 3. Tab Content
                      Obx(() {
                        if (state.selectedTab.value == 0) {
                          return AiDubbingTabView(
                            state: state,
                            durationSeconds: durationSeconds,
                            onGenerate: () => state.handleGenerateAiDubbing(context),
                          );
                        } else {
                          return DirectTrackTabView(
                            state: state,
                            durationLabel: video?.duration ?? '00:00',
                            onUpload: () => state.handleUploadDirectTrack(context),
                          );
                        }
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bgSurface)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Audio Track & Dubbing Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            onPressed: () => Get.back<void>(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabSwitcher() {
    return Obx(() {
      final tab = state.selectedTab.value;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabPill(
                index: 0,
                activeTab: tab,
                icon: Icons.auto_awesome_rounded,
                label: 'AI Voice Dubbing',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildTabPill(
                index: 1,
                activeTab: tab,
                icon: Icons.graphic_eq_rounded,
                label: 'Direct Audio Track',
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTabPill({
    required int index,
    required int activeTab,
    required IconData icon,
    required String label,
  }) {
    final isActive = activeTab == index;
    return InkWell(
      onTap: () => state.selectedTab.value = index,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: Colors.white.withValues(alpha: 0.15))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
