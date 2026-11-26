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

      // ── Active Music Theme Stage with Visual Evidence Pill ──────────
      return Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
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
          ),

          // ── High-Signal Visual Evidence Warning Pill ──────────────────────
          Positioned(
            top: 24,
            left: 16,
            right: 16,
            child: Center(
              child: Obx(() {
                if (!ctrl.visualEvidencePillVisible.value) {
                  return const SizedBox.shrink();
                }
                return VisualEvidenceWarningPill(
                  text: ctrl.visualEvidencePillText.value,
                  onTap: ctrl.onVisualEvidencePillTap,
                  onDismiss: ctrl.dismissVisualEvidencePill,
                );
              }),
            ),
          ),
        ],
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

/// High-Signal Visual Evidence Warning Pill
/// Displayed transiently in Audio-Only mode when relevant visual proof (documents, charts) appears on screen.
class VisualEvidenceWarningPill extends StatelessWidget {
  const VisualEvidenceWarningPill({
    required this.text,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.75),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
