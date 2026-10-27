import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_resolution_manager.dart';
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectTile(
                    label: 'Audio only',
                    sublabel:
                        'Ultra Data Saver · Streaming without video decoding',
                    selected: true,
                    badge: 'ACTIVE',
                    onTap: () => ctrl.activePanel.value = '',
                  ),
                  const SizedBox(height: 4),
                  SelectTile(
                    label: 'Switch to Video Mode',
                    sublabel: 'Resume standard video streaming',
                    selected: false,
                    badge: 'VIDEO',
                    onTap: () {
                      ctrl.activePanel.value = '';
                      ctrl.setAudioOnly(false);
                    },
                  ),
                ],
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

      final isPremium = _isPremiumUser();

      // Build list from only the resolutions actually available for this video.
      // Map each available resolution to its corresponding ABR ladder index
      // so selectQuality(idx) works correctly.
      final ladder = ctrl.abr.resolutionLadder;

      // Collect available entries paired with their ABR ladder index.
      // We sort descending by height then fps to match download page order.
      final availSorted = [...avail]
        ..sort((a, b) {
          final cmp = b.height.compareTo(a.height);
          if (cmp != 0) return cmp;
          return b.fps.compareTo(a.fps);
        });

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
                  // Auto tile
                  SelectTile(
                    label: 'Auto',
                    sublabel: 'Adapts to network speed',
                    selected: ctrl.abr.isAutoMode.value && !ctrl.isAudioOnly.value,
                    badge: (ctrl.abr.isAutoMode.value && !ctrl.isAudioOnly.value)
                        ? (ctrl.abr.currentTier.height > 0
                            ? ctrl.abr.currentTier.label
                            : 'Auto')
                        : null,
                    onTap: ctrl.selectAutoQuality,
                  ),

                  // Only actually available resolutions — same as download page
                  ...availSorted.map((res) {
                    final isPremiumRes = res.height > 1040;

                    // Friendly badge matching download page style (Full HD, HD, SD…)
                    final badgeText = DownloadResolutionManager.getResolutionBadge(
                      res.label,
                      res.height,
                      fps: res.fps,
                    );

                    // Find matching index in ABR ladder for selectQuality()
                    int ladderIdx = ladder.indexWhere(
                      (t) =>
                          t.height == res.height &&
                          (t.fps == res.fps ||
                              ladder.where((x) => x.height == res.height).length == 1),
                    );
                    // Fallback: match by label
                    if (ladderIdx < 0) {
                      ladderIdx = ladder.indexWhere(
                        (t) => t.label.toLowerCase() == res.label.toLowerCase(),
                      );
                    }
                    // Fallback: match by height only
                    if (ladderIdx < 0) {
                      ladderIdx = ladder.indexWhere((t) => t.height == res.height);
                    }

                    final isSelected = !ctrl.isAudioOnly.value &&
                        !ctrl.abr.isAutoMode.value &&
                        (ctrl.abr.currentTier.label == res.label ||
                            (ctrl.abr.currentTier.height == res.height &&
                                ctrl.abr.currentTier.fps == res.fps));

                    return SelectTile(
                      label: res.label,
                      sublabel: 'Tap to switch to this quality',
                      badge: badgeText.isNotEmpty ? badgeText : null,
                      selected: isSelected,
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
                        } else if (ladderIdx >= 0) {
                          ctrl.selectQuality(ladderIdx);
                        }
                      },
                    );
                  }),

                  const SizedBox(height: 4),
                  SelectTile(
                    label: 'Audio only',
                    sublabel: 'Listen without video · saves data',
                    badge: 'AUDIO',
                    selected: ctrl.isAudioOnly.value,
                    onTap: () {
                      ctrl.activePanel.value = '';
                      ctrl.setAudioOnly(true);
                    },
                  ),
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
