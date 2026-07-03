import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

class StatsForNerdsOverlay extends StatelessWidget {
  final TowerPlayerController ctrl;
  const StatsForNerdsOverlay({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!ctrl.showStatsForNerds.value) return const SizedBox.shrink();
      final sz = ctrl.videoPlayerController.value.size;
      final res = sz.width > 0
          ? '${sz.width.toInt()}×${sz.height.toInt()}@30'
          : 'Unknown';
      return Positioned(
        top: 16,
        left: 16,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
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
                      color: AppColors.brand,
                      fontSize: 12,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ctrl.showStatsForNerds.value = false,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _row('Video ID:', ctrl.tag ?? 'N/A'),
              _row('Resolution:', res),
              _row('Connection:', _bwStr(ctrl.abr.measuredBandwidthKbps.value)),
              _row(
                'Buffer Health:',
                '${ctrl.bufferHealthSeconds.toStringAsFixed(1)} s',
              ),
              _row('Playback Speed:', '${ctrl.playbackSpeed.value}×'),
              _row('Audio Language:', ctrl.activeAudioLang.value),
            ],
          ),
        ),
      );
    });
  }

  String _bwStr(double kbps) => kbps > 1000
      ? '${(kbps / 1000).toStringAsFixed(1)} Mbps'
      : '${kbps.toStringAsFixed(0)} kbps';

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TS.mono.copyWith(color: Colors.white70)),
          ),
          Expanded(child: Text(value, style: TS.mono)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOLUTION SWITCHING OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
