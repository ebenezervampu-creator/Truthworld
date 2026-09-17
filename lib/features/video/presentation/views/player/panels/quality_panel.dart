import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/theme/app_theme.dart';

class QualityPanel extends StatelessWidget {
  const QualityPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  String _bwLabel(double k) => k > 1000
      ? '${(k / 1000).toStringAsFixed(1)} Mbps'
      : '${k.toStringAsFixed(0)} kbps';

  Color _qColor(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return AppColors.success;
      case NetworkQuality.fair:
        return AppColors.brandHover;
      default:
        return PT.primary;
    }
  }

  bool _isPremiumUser() {
    try {
      if (!Get.isRegistered<AuthService>()) return false;
      return AuthService.to.hasFullPremium;
    } catch (_) {
      return false;
    }
  }

  void _showPremiumDialog(BuildContext context) {
    showPremiumDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      var avail = <VideoResolutionV2>[];
      var none = false;
      try {
        if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
          avail = Get.find<VideoController>(tag: ctrl.tag).availableResolutions;
          none = avail.isEmpty;
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'QualityPanel.findVideoController',
        );
      }

      if (none) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelHeader(
              title: 'Video Quality',
              onBack: () => ctrl.activePanel.value = '',
              onClose: null,
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.videocam_off_rounded, size: 48, color: AppColors.textPrimary),
                  SizedBox(height: 16),
                  Text('Video Not Available', style: TS.title),
                  SizedBox(height: 8),
                  Text(
                    'No playable resolutions found',
                    textAlign: TextAlign.center,
                    style: TS.bodySm,
                  ),
                ],
              ),
            ),
          ],
        );
      }

      final tiers = ctrl.abr.resolutionLadder;
      final isPremium = _isPremiumUser();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'Video Quality',
            onBack: () => ctrl.activePanel.value = '',
            onClose: null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.speed_rounded,
                  color: AppColors.textTertiary,
                  size: 14,
                ),
                const SizedBox(width: 8),
                const Text('Network: ', style: TS.bodySm),
                Text(
                  _bwLabel(ctrl.abr.measuredBandwidthKbps.value),
                  style: TS.bodySm.copyWith(
                    color: _qColor(ctrl.abr.networkQuality.value),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Text('Buffer: ', style: TS.bodySm),
                Text(
                  '${ctrl.abr.bufferHealthSeconds.value.toStringAsFixed(1)}s',
                  style: TS.bodySm.copyWith(
                    color: ctrl.abr.bufferHealthSeconds.value < 3
                        ? PT.primary
                        : AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const PlayerDivider(),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectTile(
                    label: 'Auto',
                    sublabel: 'Adapts to network speed',
                    selected: ctrl.abr.isAutoMode.value,
                    badge: ctrl.abr.isAutoMode.value
                        ? (ctrl.abr.currentTier.height > 0 ? '${ctrl.abr.currentTier.height}p' : 'Auto')
                        : null,
                    onTap: ctrl.selectAutoQuality,
                  ),
                  ...tiers.reversed
                      .where((t) => avail.any((r) => r.height == t.height))
                      .map((tier) {
                        final idx = tiers.indexWhere((t) => t.height == tier.height);
                        final isPremiumRes = tier.height > 1080;

                        return SelectTile(
                          label: tier.label,
                          sublabel: '${tier.bitrate} kbps',
                          selected:
                              !ctrl.abr.isAutoMode.value &&
                              ctrl.abr.currentTier.height == tier.height,
                          trailing: isPremiumRes && !isPremium
                              ? const Icon(
                                  Icons.lock_rounded,
                                  color: AppColors.warning,
                                  size: 16,
                                )
                              : null,
                          onTap: () {
                            if (isPremiumRes && !isPremium) {
                              _showPremiumDialog(context);
                            } else {
                              if (idx >= 0) ctrl.selectQuality(idx);
                            }
                          },
                        );
                      }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

void showPremiumDialog(BuildContext context) {
  Get.toNamed('/premium');
}
