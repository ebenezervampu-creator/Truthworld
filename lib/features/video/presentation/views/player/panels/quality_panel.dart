import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_resolution_manager.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
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

  /// Badge for the Auto tile: the quality actually playing. With adaptive HLS the
  /// native player picks it, so it's read from the decoded frame size.
  String _autoBadge() {
    final vc = ctrl.videoController;
    if (vc != null && vc.isOnHlsAuto) {
      final size = vc.videoPlayerController?.value.size;
      final shortSide = size == null ? 0 : (size.width < size.height ? size.width : size.height).round();
      return shortSide > 0 ? '${shortSide}p' : 'Auto';
    }
    return ctrl.abr.currentTier.height > 0 ? ctrl.abr.currentTier.label : 'Auto';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      var avail = <VideoResolutionV2>[];
      var none = false;
      try {
        final vc = ctrl.videoController;
        if (vc != null) {
          if (vc.availableResolutions.isEmpty) {
            vc.fetchAvailableResolutions();
          }
          avail = vc.availableResolutions.toList();
        }
        none = avail.isEmpty;
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
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 48,
                    color: AppColors.textPrimary,
                  ),
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
      // Strictly exclude synthetic or unverified tiers above the authentic ceiling.
      final ladder = ctrl.abr.resolutionLadder;

      // Filter out synthetic and fallback items so users aren't shown redundant menu items that all play 720p
      final hasFallbackTiers = avail.any((r) => r.isSynthetic || r.isFallback);
      var realResolutions = avail.where((r) => !r.isSynthetic && !r.isFallback).toList();
      if (realResolutions.isEmpty && avail.isNotEmpty) {
        // If all are backfilled, take only the single highest available tier to avoid duplicate rows
        realResolutions = [avail.first];
      }

      // Check player's initialized native decoded height
      final decodedHeight = ctrl.videoPlayerController.value.isInitialized
          ? ctrl.videoPlayerController.value.size.height.toInt()
          : 0;

      // Real highest resolution among authentic available variants
      final maxAvailableHeight = realResolutions
          .map((r) => r.height)
          .fold(0, (a, b) => a > b ? a : b);

      final effectiveCeiling = maxAvailableHeight > 0
          ? maxAvailableHeight
          : (decodedHeight > 0 ? decodedHeight : 0);

      if (effectiveCeiling > 0) {
        realResolutions = realResolutions
            .where((r) => r.height <= effectiveCeiling)
            .toList();
      }

      // Sort descending by height then fps to match download page order
      final availSorted = [...realResolutions]
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
                    selected:
                        ctrl.abr.isAutoMode.value && !ctrl.isAudioOnly.value,
                    badge:
                        (ctrl.abr.isAutoMode.value && !ctrl.isAudioOnly.value)
                        ? _autoBadge()
                        : null,
                    onTap: ctrl.selectAutoQuality,
                  ),

                  // Only actually available resolutions — same as download page
                  ...availSorted.map((res) {
                    final isPremiumRes = res.height > 1040;

                    // Friendly badge matching download page style (Full HD, HD, SD…)
                    final badgeText =
                        DownloadResolutionManager.getResolutionBadge(
                          res.label,
                          res.height,
                          fps: res.fps,
                        );

                    // Find matching index in ABR ladder for selectQuality()
                    int ladderIdx = ladder.indexWhere(
                      (t) =>
                          t.height == res.height &&
                          (t.fps == res.fps ||
                              ladder
                                      .where((x) => x.height == res.height)
                                      .length ==
                                  1),
                    );
                    // Fallback: match by label
                    if (ladderIdx < 0) {
                      ladderIdx = ladder.indexWhere(
                        (t) => t.label.toLowerCase() == res.label.toLowerCase(),
                      );
                    }
                    // Fallback: match by height only
                    if (ladderIdx < 0) {
                      ladderIdx = ladder.indexWhere(
                        (t) => t.height == res.height,
                      );
                    }

                    final isSelected =
                        !ctrl.isAudioOnly.value &&
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
                        } else {
                          final vc = ctrl.videoController;
                          if (vc != null) {
                            vc.setResolution(res);
                            ctrl.activePanel.value = '';
                          }
                        }
                      },
                    );
                  }),

                  if (hasFallbackTiers && realResolutions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Lower data-saver qualities are currently unavailable for this video.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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
