import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/player_settings_panels.dart';
import 'package:truthworld/theme/app_theme.dart';

class TranscriptOverlay extends StatelessWidget {
  const TranscriptOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final vc = ctrl.videoController;

    // Proactively request transcript loading if not yet loaded
    if (ctrl.subtitleSegments.isEmpty &&
        (vc == null || vc.transcriptSegments.isEmpty) &&
        (vc == null || !vc.isLoadingTranscript.value) &&
        !ctrl.isLoadingSubtitles.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vc?.loadTranscriptForVideo();
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // Absorb taps
      child: Container(
        decoration: BoxDecoration(
          color: PT.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PT.border),
        ),
        child: Column(
          children: [
            Obx(
              () => PanelHeader(
                title: 'Transcript',
                onBack: null,
                onClose: () {
                  ctrl.showTranscriptPopup.value = false;
                  ctrl.startHideTimer();
                },
                onContinue: () {
                  ctrl.toggleTranscriptAutoPlay();
                  ctrl.startHideTimer();
                },
                continueLabel: ctrl.isTranscriptAutoPlay.value
                    ? 'Pause'
                    : 'Play',
              ),
            ),
            Expanded(
              child: Obx(() {
                ctrl.showTranscriptPopup.value;
                ctrl.isTranscriptAutoPlay.value;
                final isLoading = ctrl.isLoadingSubtitles.value ||
                    (vc != null && vc.isLoadingTranscript.value);

                final segments = ctrl.subtitleSegments.isNotEmpty
                    ? ctrl.subtitleSegments
                    : (vc?.transcriptSegments ?? <SubtitleSegment>[]);

                if (isLoading && segments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brand,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading transcript...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (segments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No timestamped transcript available',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: () {
                              vc?.loadTranscriptForVideo();
                            },
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Retry',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  AppColors.textPrimary.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: segments.length,
                  itemBuilder: (context, index) {
                    final seg = segments[index];
                    return _TranscriptOverlayTile(
                      seg: seg,
                      ctrl: ctrl,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptOverlayTile extends StatelessWidget {
  const _TranscriptOverlayTile({
    required this.seg,
    required this.ctrl,
  });

  final SubtitleSegment seg;
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = ctrl.activeSubtitleSegment.value == seg;

      return InkWell(
        onTap: () => ctrl.seekTo(seg.start),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          color: isActive
              ? AppColors.textPrimary.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  _formatDuration(seg.start),
                  style: TS.mono.copyWith(
                    color: isActive ? Colors.white : PT.textDim,
                    fontSize: 12,
                    fontWeight: isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  seg.text,
                  style: TS.body.copyWith(
                    color: isActive
                        ? AppColors.textPrimary
                        : PT.textDim,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  static String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$mins:$secs';
    return '$mins:$secs';
  }
}
