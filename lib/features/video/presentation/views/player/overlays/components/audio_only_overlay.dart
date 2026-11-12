import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/audio_themes_barrel.dart';
import 'package:truthworld/features/video/presentation/widgets/audio_themes_bottom_sheet.dart';

/// AudioOnlyOverlay: Multi-theme audio playback stage for TruthWorld.
/// Presents 5 specialized listening experiences powered by a shared low-power audio analysis engine.
class AudioOnlyOverlay extends StatelessWidget {
  const AudioOnlyOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final analysisService = ctrl.audioAnalysisService;
    // Explicit reduced-motion behavior via platform disableAnimations signal
    final isReducedMotion = MediaQuery.of(context).disableAnimations;

    return Obx(() {
      ctrl.isAudioOnly.value; // Reactive dependency
      final prefTheme = TowerPlayerPreferences.globalAudioTheme.value;
      // Fallback to Obsidian Minimalist for reduced motion or constrained environments
      final activeTheme = isReducedMotion ? AudioPlayerTheme.obsidianMinimalist : prefTheme;
      final video = ctrl.videoController?.video;
      final currentSub = ctrl.currentSubtitle.value;

      if (ctrl.isPiP.value) {
        return const ColoredBox(
          color: Color(0xFF08080C),
          child: Center(
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 28,
              color: Colors.white70,
            ),
          ),
        );
      }

      // ── Active Music Theme Stage ─────────────────────────────────────
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey<AudioPlayerTheme>(activeTheme),
          child: _buildThemeStage(
            activeTheme: activeTheme,
            analysisService: analysisService,
            video: video,
            currentSubtitle: currentSub,
          ),
        ),
      );
    });
  }

  Widget _buildThemeStage({
    required AudioPlayerTheme activeTheme,
    required AudioAnalysisService analysisService,
    required String currentSubtitle,
    dynamic video,
  }) {
    switch (activeTheme) {
      case AudioPlayerTheme.fluidAura:
        return FluidAuraTheme(
          ctrl: ctrl,
          analysisService: analysisService,
          video: video,
        );
      case AudioPlayerTheme.kineticSyllable:
        return KineticSyllableTheme(
          ctrl: ctrl,
          analysisService: analysisService,
          video: video,
          currentSubtitle: currentSubtitle,
        );
      case AudioPlayerTheme.audiophileSpectral:
        return AudiophileSpectralTheme(
          ctrl: ctrl,
          analysisService: analysisService,
          video: video,
        );
      case AudioPlayerTheme.obsidianMinimalist:
        return ObsidianMinimalistTheme(
          ctrl: ctrl,
          analysisService: analysisService,
          video: video,
        );
      case AudioPlayerTheme.truthPulseHologram:
        return TruthPulseHologramTheme(
          ctrl: ctrl,
          analysisService: analysisService,
          video: video,
        );
    }
  }
}

/// Theme Switcher Pill elevated to player controls so it respects controls visibility
/// and avoids overlapping action docks in fullscreen.
class AudioThemeSwitcherPill extends StatelessWidget {
  const AudioThemeSwitcherPill({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeTheme = TowerPlayerPreferences.globalAudioTheme.value;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AudioThemesBottomSheet.show(context, ctrl: ctrl);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeTheme.icon,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  activeTheme.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
