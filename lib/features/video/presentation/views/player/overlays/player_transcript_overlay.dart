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
            PanelHeader(
              title: 'Transcript',
              onBack: null,
              onClose: () {
                ctrl.showTranscriptPopup.value = false;
                ctrl.startHideTimer();
              },
            ),
            Expanded(
              child: Obx(() {
                if (ctrl.subtitleSegments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transcript available',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                final pos = ctrl.vv.position;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: ctrl.subtitleSegments.length,
                  itemBuilder: (context, index) {
                    final seg = ctrl.subtitleSegments[index];
                    final isActive = pos >= seg.start && pos <= seg.end;

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
                                  color: isActive ? PT.primary : PT.textDim,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                seg.text,
                                style: TS.body.copyWith(
                                  color: isActive ? AppColors.textPrimary : PT.textDim,
                                  fontWeight: isActive
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$mins:$secs';
    return '$mins:$secs';
  }
}
