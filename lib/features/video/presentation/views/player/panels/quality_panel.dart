import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/theme/app_theme.dart';

class QualityPanel extends StatelessWidget {
  const QualityPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  bool _isPremiumUser() {
    try {
      if (ctrl.hasPremiumPlaybackAccess) return true;
      if (!Get.isRegistered<AuthService>()) return false;
      return AuthService.to.hasFullPremium;
    } catch (_) {
      return false;
    }
  }

  void _showPremiumDialog(BuildContext context) {
    try {
      final vCtrl = ctrl.videoController;
      final channel = vCtrl?.channelController.selectedChannel.value;
      if (channel != null && channel.noAdsForMembers) {
        // Channel offers Channel Premium (No Ads + 4K streaming)!
        ChannelMembershipJoinSheet.show(
          context,
          channelId: channel.channelId,
          channel: channel,
        );
        return;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'QualityPanel.showPremiumDialog',
      );
    }
    showPremiumDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      var avail = <VideoResolutionV2>[];
      var none = false;
      try {
        if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
          final vc = Get.find<VideoController>(tag: ctrl.tag);
          avail = vc.availableResolutions;
          if (avail.isNotEmpty) {
            final baseMediaUrl = vc.video.videoUrl.isNotEmpty
                ? vc.video.videoUrl
                : vc.video.originalUrl;
            final complete = VideoResolutionV2.ensureCompleteLadder(
              avail,
              fallbackUrl: baseMediaUrl,
            );
            if (complete.length != avail.length) {
              vc.availableResolutions.assignAll(complete);
            }
            avail = vc.availableResolutions;
          }
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

      if (ctrl.isAudioOnly.value) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelHeader(
              title: 'Audio Format',
              onBack: () => ctrl.activePanel.value = '',
              onClose: null,
            ),
            const PlayerDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectTile(
                label: 'Audio only',
                sublabel:
                    'Playing dedicated audio stream without video decoding',
                selected: true,
                badge: 'AUDIO',
                onTap: () => ctrl.activePanel.value = '',
              ),
            ),
          ],
        );
      }

      final isOffline = ctrl.videoController?.rxIsOffline.value == true;
      if (isOffline) {
        final currentRes = ctrl.videoController?.currentResolution.value;
        final resLabel = (currentRes != null && currentRes.label.isNotEmpty)
            ? currentRes.label
            : (avail.isNotEmpty ? avail.first.label : 'Offline');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelHeader(
              title: 'Offline Quality',
              onBack: () => ctrl.activePanel.value = '',
              onClose: null,
            ),
            const PlayerDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectTile(
                label: resLabel,
                sublabel: 'Locked to downloaded offline format',
                selected: true,
                badge: 'SAVED',
                onTap: () => ctrl.activePanel.value = '',
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
                        ? (ctrl.abr.currentTier.height > 0
                            ? ctrl.abr.currentTier.label
                            : 'Auto')
                        : null,
                    onTap: ctrl.selectAutoQuality,
                  ),
                  ...tiers.reversed
                      .where((t) =>
                          avail.isEmpty ||
                          avail.any((r) =>
                              r.label.toLowerCase() == t.label.toLowerCase() ||
                              (r.height == t.height &&
                                  (r.is60Fps == t.is60Fps ||
                                      avail.where((x) => x.height == t.height).length == 1)) ||
                              r.height == t.height))
                      .map((tier) {
                        final idx = tiers.indexOf(tier);
                        final isPremiumRes = tier.height > 1040;
                        final is60 = tier.is60Fps;
                        String? resBadge;
                        if (tier.height >= 2160) {
                          resBadge = is60 ? '4K 60' : '4K UHD';
                        } else if (tier.height >= 1440) {
                          resBadge = is60 ? '2K 60' : '2K QHD';
                        } else if (tier.height >= 1080) {
                          resBadge = is60 ? 'FHD 60' : 'FHD';
                        } else if (is60) {
                          resBadge = '60 FPS';
                        }

                        return SelectTile(
                          label: tier.label,
                          sublabel: '${tier.bitrate} kbps',
                          badge: resBadge,
                          selected:
                              !ctrl.abr.isAutoMode.value &&
                              (ctrl.abr.currentTier.label == tier.label ||
                                  (ctrl.abr.currentTier.height == tier.height &&
                                      ctrl.abr.currentTier.fps == tier.fps)),
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
