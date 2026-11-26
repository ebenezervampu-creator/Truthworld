import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerAbrMixin on GetxController {
  // Host controller dependencies
  VideoPlayerController get videoPlayerController;
  VideoController? get videoController;
  String? get tag;
  RxBool get isShowingAd;
  RxString get activePanel;
  RxBool get isAudioOnly;
  void closeSettings();
  void trackAnalytics(PlayerEvent event);
  void showToast(String msg);
  Future<void> setAudioOnly(bool enabled) async {}

  // ── ABR / quality ─────────────────────────────────────────
  final AdaptiveBitrateController abr = AdaptiveBitrateController();
  List<ResolutionTier> resolutionTiers = [];

  void initABR() {
    if (!Get.isRegistered<AdaptiveBitrateController>(tag: tag)) {
      Get.put(abr, tag: tag);
    }
    var ladder = <ResolutionTier>[];

    try {
      final vc = videoController;
      if (vc != null) {
        if (vc.availableResolutions.isNotEmpty) {
          final realResolutions = vc.availableResolutions
              .where((r) => !r.isSynthetic && !vc.blacklistedStreamUrls.contains(r.url))
              .toList();
          if (realResolutions.isNotEmpty) {
            final fallbackMediaUrl = vc.video.videoUrl.isNotEmpty && !vc.blacklistedStreamUrls.contains(vc.video.videoUrl)
                ? vc.video.videoUrl
                : (!vc.blacklistedStreamUrls.contains(vc.video.originalUrl)
                    ? vc.video.originalUrl
                    : '');
            final complete = VideoResolutionV2.ensureCompleteLadder(
              realResolutions,
              fallbackUrl: fallbackMediaUrl,
            ).where((r) => !vc.blacklistedStreamUrls.contains(r.url)).toList();
            if (complete.length != vc.availableResolutions.length) {
              if (WidgetsBinding.instance.schedulerPhase ==
                  SchedulerPhase.persistentCallbacks) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!vc.isClosed) {
                    vc.availableResolutions.assignAll(complete);
                  }
                });
              } else {
                vc.availableResolutions.assignAll(complete);
              }
            }
            ladder = vc.availableResolutions.reversed
                .map(ResolutionTier.fromVideoResolution)
                .toList();
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAbrMixin.initABR.ladderLookup',
      );
    }

    if (ladder.isEmpty) {
      final nativeH = videoPlayerController.value.isInitialized
          ? videoPlayerController.value.size.height.toInt()
          : 0;
      final defaultTiers = ResolutionTier.defaultLadder;
      if (nativeH > 0) {
        ladder = defaultTiers.where((t) => t.height <= nativeH).toList();
      }
      if (ladder.isEmpty) {
        ladder = List<ResolutionTier>.from(defaultTiers);
      }
    }

    final isPremium = hasPremiumPlaybackAccess;

    int? initialTierIdx;
    // Pre-align current tier index with the active resolution before initialize to prevent immediate spurious auto-switch
    try {
      final vc = videoController;
      if (vc != null) {
        final activeRes = vc.currentResolution.value;
        if (activeRes != null && ladder.isNotEmpty) {
          var matchIdx = ladder.indexWhere(
            (t) => t.label.toLowerCase() == activeRes.label.toLowerCase(),
          );
          if (matchIdx == -1) {
            matchIdx = ladder.indexWhere(
              (t) => t.height == activeRes.height && t.fps == activeRes.fps,
            );
          }
          if (matchIdx == -1) {
            matchIdx = ladder.indexWhere((t) => t.height == activeRes.height);
          }
          if (matchIdx != -1) {
            initialTierIdx = matchIdx;
            abr.currentTierIndex.value = matchIdx;
          }
        }

        // Dynamically update resolution ceiling whenever member status or channel settings hydrate
        ever(vc.channelController.subController.isChannelMember, (_) {
          final hasPrem = hasPremiumPlaybackAccess;
          abr.updateMaxHeightCap(hasPrem ? null : 1040);
        });
        ever(vc.channelController.selectedChannel, (_) {
          final hasPrem = hasPremiumPlaybackAccess;
          abr.updateMaxHeightCap(hasPrem ? null : 1040);
        });
      }
    } catch (_) {}

    abr.initialize(
      ladder: ladder,
      vpc: videoPlayerController,
      maxHeightCap: isPremium ? null : 1040,
      initialTierIndex: initialTierIdx,
    );
    abr.isAdPlaying = () => isShowingAd.value;

    abr.onTierChanged = (tierIndex, isManual) {
      void applyTierChange() {
        try {
          final vc = videoController;
          if (vc == null || vc.isClosed) return;
          if (vc.isSwitchingResolution.value) return;
          if (vc.rxIsOffline.value || isAudioOnly.value) return;
          // Adaptive HLS: the native player (ExoPlayer / AVPlayer) already switches
          // qualities between segments. Rebuilding the player here would undo that.
          if (!isManual && vc.isOnHlsAuto) return;
          if (tierIndex >= 0 && tierIndex < abr.resolutionLadder.length) {
            final tier = abr.resolutionLadder[tierIndex];
            final match = vc.availableResolutions.firstWhereOrNull(
                  (r) => !vc.blacklistedStreamUrls.contains(r.url) &&
                      r.label.toLowerCase() == tier.label.toLowerCase(),
                ) ??
                vc.availableResolutions.firstWhereOrNull(
                  (r) => !vc.blacklistedStreamUrls.contains(r.url) &&
                      r.height == tier.height &&
                      r.fps == tier.fps,
                ) ??
                vc.availableResolutions.firstWhereOrNull(
                  (r) => !vc.blacklistedStreamUrls.contains(r.url) &&
                      r.height == tier.height,
                );
            if (match == null || vc.blacklistedStreamUrls.contains(match.url)) return;

            // For auto ABR (!isManual), do not re-initialize player if already on this exact URL and height/fps
            if (!isManual &&
                (vc.currentResolution.value?.url == match.url ||
                    (vc.currentResolution.value?.height == match.height &&
                        vc.currentResolution.value?.fps == match.fps))) {
              if (vc.currentResolution.value != match) {
                vc.currentResolution.value = match;
              }
              return;
            }

            // Protect active handoff controller from auto ABR teardown
            if (!isManual &&
                VideoPlaybackHandoff.isHandoffActiveOrRecent(vc.video.id)) {
              return;
            }

            vc.setResolution(match, isManual: isManual);
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerAbrMixin.abrTierChange',
          );
        }
      }

      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => applyTierChange());
      } else {
        applyTierChange();
      }
    };

    // Apply network-aware User Settings quality preference or global quality preference
    var pref = TowerPlayerController.globalQualityPreference ?? 'Auto';
    if (pref == 'Auto' || pref == '144p') {
      if (Get.isRegistered<UserSettingsController>()) {
        final pb = UserSettingsController.to.playback.value;
        final isWifi = !Get.isRegistered<ConnectivityService>() ||
            ConnectivityService.to.isWifi;
        final targetQualityStr =
            isWifi ? pb.wifiQuality : pb.cellularQuality;

        if (targetQualityStr.contains('1080') ||
            targetQualityStr.contains('High')) {
          pref = isPremium ? '1080p' : '1040p';
        } else if (targetQualityStr.contains('720') ||
            targetQualityStr.contains('Medium')) {
          pref = '720p';
        } else if (targetQualityStr.contains('480p') ||
            targetQualityStr.contains('Data Saver')) {
          pref = '480p';
        } else if (targetQualityStr.contains('360p') ||
            targetQualityStr.contains('Low')) {
          pref = '360p';
        } else {
          pref = 'Auto';
        }
      } else {
        pref = 'Auto';
      }
    }

    if (pref == 'Auto' || pref == '144p') {
      abr.enableAutoMode();
    } else {
      if (!isPremium &&
          (pref.contains('1080') ||
              pref.contains('1440') ||
              pref.contains('2160') ||
              pref.contains('4k') ||
              pref.contains('4K'))) {
        pref = '1040p';
      }
      final targetPref = pref.toLowerCase();
      final matchIdx = abr.resolutionLadder.indexWhere(
        (t) => t.label.toLowerCase() == targetPref ||
            t.label.toLowerCase().startsWith(targetPref),
      );
      if (matchIdx != -1) {
        abr.setManualTier(matchIdx);
      } else {
        abr.enableAutoMode();
      }
    }
  }

  String get currentQualityLabel {
    if (isAudioOnly.value) {
      return 'Audio only';
    }
    if (videoController?.rxIsOffline.value == true) {
      final currentRes = videoController?.currentResolution.value;
      if (currentRes != null && currentRes.label.isNotEmpty) {
        return currentRes.label;
      }
      return 'Offline';
    }
    return abr.isAutoMode.value
        ? 'Auto · ${abr.currentTier.label}'
        : abr.currentTier.label;
  }

  /// Evaluates whether the current viewer has premium playback privileges (unlocked 4K / 1080p).
  /// This is true if the user has global TruthWorld Full Premium OR if the user is an active
  /// member of this channel and the creator has enabled Channel Premium (noAdsForMembers).
  bool get hasPremiumPlaybackAccess {
    try {
      if (Get.isRegistered<AuthService>() && AuthService.to.hasFullPremium) {
        return true;
      }
      final vCtrl = videoController;
      if (vCtrl != null) {
        return vCtrl.canStreamHighResolution;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAbrMixin.hasPremiumPlaybackAccess',
      );
    }
    return false;
  }

  void selectQuality(int tierIndex) {
    if (tierIndex < 0 || tierIndex >= abr.resolutionLadder.length) return;
    if (isAudioOnly.value) {
      setAudioOnly(false);
    }
    final isPremium = hasPremiumPlaybackAccess;
    if (isPremium && abr.maxHeightCap != null) {
      abr.updateMaxHeightCap(null);
    }
    if (!isPremium && abr.resolutionLadder[tierIndex].height > 1040) {
      return;
    }
    abr.setManualTier(tierIndex);
    TowerPlayerController.globalQualityPreference =
        abr.resolutionLadder[tierIndex].label;
    activePanel.value = '';
    closeSettings();
    trackAnalytics(
      PlayerEvent(
        'quality_change',
        data: {'quality': abr.resolutionLadder[tierIndex].label},
      ),
    );
  }

  void selectAutoQuality() {
    if (isAudioOnly.value) {
      setAudioOnly(false);
    }
    // Prefer adaptive HLS for Auto. Started before enableAutoMode() so the app's
    // own ABR sees the HLS entry and doesn't switch to an MP4 at the same time.
    final vc = videoController;
    if (vc != null && !vc.isClosed && !vc.isOnHlsAuto && vc.hlsAutoResolution != null) {
      unawaited(vc.switchToHlsAuto());
    }
    abr.enableAutoMode();
    TowerPlayerController.globalQualityPreference = 'Auto';
    showToast('Quality: Auto');
    activePanel.value = '';
    closeSettings();
  }

  /// Returns the Gaussian blur sigma to visually represent the active resolution tier.
  /// When playing at lower resolutions (e.g. 144p, 240p, 360p, 480p) on a higher-res stream
  /// or synthetic ladder tier, applying blur simulates authentic lower resolution playback.
  double get resolutionBlurSigma {
    if (isAudioOnly.value) return 0.0;
    // Adaptive HLS plays real lower qualities; never blur it.
    if (videoController?.isOnHlsAuto ?? false) return 0.0;

    final res = videoController?.currentResolution.value;
    final targetHeight = (res != null && res.height > 0)
        ? res.height
        : abr.currentTier.height;
    if (targetHeight <= 0) return 0.0;

    final vpc = videoPlayerController;
    final nativeHeight =
        vpc.value.isInitialized ? vpc.value.size.height.toInt() : 0;

    // If native stream is already at or below target resolution (e.g. authentic 144p transcode stream),
    // and not marked synthetic, native scaling is already low-resolution.
    if (nativeHeight > 0 &&
        nativeHeight <= targetHeight &&
        !(res?.isSynthetic ?? false)) {
      return 0.0;
    }

    if (targetHeight <= 144) {
      return 4.5;
    } else if (targetHeight <= 240) {
      return 2.5;
    } else if (targetHeight <= 360) {
      return 1.4;
    } else if (targetHeight <= 480) {
      return 0.7;
    }
    return 0.0;
  }
}
