import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class StateOverlay extends StatelessWidget {
  const StateOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ctrl.isAudioOnly.value; // Guarantee Rx access for Obx
      final state = ctrl.abr.playbackState.value;
      final buffering = ctrl.isBuffering.value;
      final hasError = ctrl.hasError.value;

      // Suppress spinner/errors for transparent auto-quality switches or format recovery
      var isAutoSwitch = false;
      var isRecovering = false;
      try {
        final vc = ctrl.videoController;
        if (vc != null) {
          isAutoSwitch = vc.isAutoSwitching.value;
          isRecovering = vc.isRecoveringFromFormatError;
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'PlaybackStateOverlay.checkAutoSwitching',
        );
      }
      if (isAutoSwitch || isRecovering) return const SizedBox.shrink();

      if (hasError) return _buildError();
      if (state == PlaybackState.stalled) return _buildStall();
      if (buffering || state == PlaybackState.buffering) {
        return _buildSpinner(PT.primary);
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildSpinner(Color color) => Center(
    child: SizedBox(
      width: 48,
      height: 48,
      child: Shimmer.fromColors(
        baseColor: color.withValues(alpha: 0.3),
        highlightColor: color,
        child: const Icon(
          Icons.play_circle_outline_rounded,
          color: AppColors.textPrimary,
          size: 48,
        ),
      ),
    ),
  );

  Widget _buildStall() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSpinner(AppColors.warning),
        const SizedBox(height: 16),
        Text(
          'Poor network · ${ctrl.abr.currentTier.label}',
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _buildError() {
    final err = ctrl.errorDescription.value.isNotEmpty
        ? ctrl.errorDescription.value
        : (ctrl.vv.errorDescription ?? 'An unknown error occurred');
    final lower = err.toLowerCase();
    if (lower.contains('removed from the document') ||
        lower.contains('play() request was interrupted') ||
        lower.contains('the play() request was interrupted') ||
        lower.contains('aborterror') ||
        lower.contains('notallowederror') ||
        lower.contains('media_err_aborted') ||
        lower.contains('client returned a buffer') ||
        lower.contains('bad_index') ||
        lower.contains('pause()') ||
        lower.contains('user gesture')) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: AppColors.bgPage,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.textPrimary, size: 52),
            const SizedBox(height: 16),
            Text('Playback Error', style: TS.title.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              err,
              style: TS.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PremiumButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: ctrl.retryManual,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOUBLE-TAP RIPPLE (Curved arc with 3-chevron animated wave)
// ─────────────────────────────────────────────────────────────────────────────
