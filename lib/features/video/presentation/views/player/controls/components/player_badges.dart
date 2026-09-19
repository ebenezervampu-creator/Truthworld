import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class NetworkBadge extends StatelessWidget {
  const NetworkBadge({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  Color _qColor(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent:
        return AppColors.success;
      case NetworkQuality.good:
        return Colors.lightGreenAccent;
      case NetworkQuality.fair:
        return AppColors.brandHover;
      case NetworkQuality.poor:
        return AppColors.warning;
      default:
        return PT.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final q = ctrl.abr.networkQuality.value;
      final bw = ctrl.abr.measuredBandwidthKbps.value;
      final col = _qColor(q);
      final label = bw > 1000
          ? '${(bw / 1000).toStringAsFixed(1)} Mbps'
          : '${bw.toStringAsFixed(0)} kbps';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.network_check_rounded,
              color: AppColors.textPrimary,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: col,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class AbrBadge extends StatelessWidget {
  const AbrBadge({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shortTier = ctrl.abr.currentTier.height > 0
          ? '${ctrl.abr.currentTier.height}p'
          : ctrl.abr.currentTier.label;
      final label = ctrl.abr.isAutoMode.value
          ? 'AUTO·$shortTier'
          : shortTier;
      return InkWell(
        onTap: () => ctrl.openSettings(context),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
            ),
          ),
          child: Text(label, style: TS.badge),
        ),
      );
    });
  }
}
