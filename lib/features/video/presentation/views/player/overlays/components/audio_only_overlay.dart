import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/audio_themes_barrel.dart';

/// AudioOnlyOverlay: Multi-theme audio playback stage for TruthWorld.
/// Replaces wireframes with production-grade music themes (Ambient Glow, Retro Vinyl, Cyber Spectrum, Lyrical Stage, Zen Aura).
class AudioOnlyOverlay extends StatelessWidget {
  const AudioOnlyOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ctrl.isAudioOnly.value; // Reactive dependency
      final isPlaying = ctrl.isPlaying.value;
      final activeTheme = TowerPlayerPreferences.globalAudioTheme.value;
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

      return Stack(
        fit: StackFit.expand,
        children: [
          // ── Active Music Theme Stage ─────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey<AudioPlayerTheme>(activeTheme),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildThemeStage(
                  activeTheme: activeTheme,
                  isPlaying: isPlaying,
                  video: video,
                  currentSubtitle: currentSub,
                ),
              ),
            ),
          ),

          // ── Top Theme Switcher Pill (Hidden in PiP) ──────────────────────
          if (!ctrl.isPiP.value)
            Positioned(
              top: 14,
              right: 14,
              child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ctrl.activePanel.value = 'audio_theme';
                  ctrl.settingsOpen.value = true;
                  ctrl.controlsVisible.value = true;
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
            ),
          ),
        ],
      );
    });
  }

  Widget _buildThemeStage({
    required AudioPlayerTheme activeTheme,
    required bool isPlaying,
    required String currentSubtitle,
    dynamic video,
  }) {
    switch (activeTheme) {
      case AudioPlayerTheme.ambientGlow:
        return AmbientGlowTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.retroVinyl:
        return RetroVinylTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.cyberSpectrum:
        return CyberSpectrumTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.lyricalStage:
        return LyricalStageTheme(
          isPlaying: isPlaying,
          currentSubtitle: currentSubtitle,
          video: video,
        );
      case AudioPlayerTheme.zenAura:
        return ZenAuraTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.vintageCassette:
        return VintageCassetteTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.analogVuMeter:
        return AnalogVuMeterTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.cosmicNebula:
        return CosmicNebulaTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.holographicCd:
        return HolographicCdTheme(
          isPlaying: isPlaying,
          video: video,
        );
      case AudioPlayerTheme.fluidHorizon:
        return FluidHorizonTheme(
          isPlaying: isPlaying,
          video: video,
        );
    }
  }
}
