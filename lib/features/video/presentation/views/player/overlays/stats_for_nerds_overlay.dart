import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/stats_for_nerds_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class StatsForNerdsOverlay extends StatelessWidget {
  const StatsForNerdsOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StatsForNerdsController>(
      tag: ctrl.tag,
      init: StatsForNerdsController(playerCtrl: ctrl),
      builder: (statsCtrl) => _StatsForNerdsOverlayView(
        ctrl: ctrl,
        statsCtrl: statsCtrl,
      ),
    );
  }
}

class _StatsForNerdsOverlayView extends StatelessWidget {
  const _StatsForNerdsOverlayView({
    required this.ctrl,
    required this.statsCtrl,
  });

  final TowerPlayerController ctrl;
  final StatsForNerdsController statsCtrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!ctrl.showStatsForNerds.value) return const SizedBox.shrink();

      final size = ctrl.videoPlayerController.value.size;
      final videoRes = size.width > 0
          ? '${size.width.toInt()}x${size.height.toInt()}@30'
          : '1920x1080@30';

      // Viewport dimensions of current video frame widget
      final viewW = MediaQuery.of(context).size.width;
      final viewH = MediaQuery.of(context).size.height;
      final viewportRes = '${viewW.toInt()}x${viewH.toInt()}';

      final bitrate = statsCtrl.getEstimatedBitrate(size.width);
      final bufferState = statsCtrl.getBufferState();

      return Container(
        width: 320,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textDisabled),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stats for Nerds',
                  style: TS.badge.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () => ctrl.showStatsForNerds.value = false,
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                    size: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('Video ID / sCPN:', '${ctrl.tag} / ${statsCtrl.scpn}'),
            _row(
              'Viewport / Frames:',
              '$viewportRes / ${statsCtrl.droppedFrames.value} dropped of ${statsCtrl.decodedFrames.value}',
            ),
            _row(
              'Current / Optimal:',
              '$videoRes / ${ctrl.currentQualityLabel}',
            ),
            _row('Codecs:', 'vp09.01.09.08.01.01.01.01.00 (248) / opus (251)'),
            _row('Color / Bitrate:', 'BT.709 / $bitrate'),
            _row(
              'Connection Speed:',
              statsCtrl.fmtBw(ctrl.abr.measuredBandwidthKbps.value),
            ),
            _row(
              'Buffer Health:',
              '${ctrl.bufferHealthSeconds.toStringAsFixed(1)} s',
            ),
            _row('Network Activity:', bufferState),
            _row('CDN Node Region:', statsCtrl.cdnNode),
            _row('Playback Speed:', '${ctrl.playbackSpeed.value}x'),
          ],
        ),
      );
    });
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TS.mono.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TS.mono.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

