import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerAbrMixin on GetxController {
  // Host controller dependencies
  VideoPlayerController get videoPlayerController;
  VideoController? get videoController;
  String? get tag;
  RxBool get isShowingAd;
  RxString get activePanel;
  void closeSettings();
  void trackAnalytics(PlayerEvent event);

  // ── ABR / quality ─────────────────────────────────────────
  final AdaptiveBitrateController abr = AdaptiveBitrateController();
  List<ResolutionTier> resolutionTiers = [];

  void initABR() {
    if (!Get.isRegistered<AdaptiveBitrateController>(tag: tag)) {
      Get.put(abr, tag: tag);
    }
    var ladder = List<ResolutionTier>.from(ResolutionTier.defaultLadder);

    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        final vc = Get.find<VideoController>(tag: tag);
        if (vc.availableResolutions.isNotEmpty) {
          ladder = vc.availableResolutions.reversed
              .map(ResolutionTier.fromVideoResolution)
              .toList();
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAbrMixin.initABR.ladderLookup',
      );
    }

    abr.initialize(ladder: ladder, vpc: videoPlayerController);
    abr.isAdPlaying = () => isShowingAd.value;

    abr.onTierChanged = (tierIndex, isManual) {
      void applyTierChange() {
        try {
          if (!Get.isRegistered<VideoController>(tag: tag)) return;
          final vc = Get.find<VideoController>(tag: tag);
          if (vc.isSwitchingResolution.value) return;
          if (tierIndex >= 0 && tierIndex < abr.resolutionLadder.length) {
            final tier = abr.resolutionLadder[tierIndex];
            final match = vc.availableResolutions.firstWhereOrNull(
              (r) => r.height == tier.height,
            );
            if (match != null &&
                (vc.currentResolution.value?.url != match.url ||
                    vc.currentResolution.value?.label != match.label)) {
              vc.setResolution(match, isManual: isManual);
            }
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
    var pref = TowerPlayerController.globalQualityPreference;
    if (pref == null || pref == 'Auto') {
      if (Get.isRegistered<UserSettingsController>()) {
        final pb = UserSettingsController.to.playback.value;
        final isWifi = !Get.isRegistered<ConnectivityService>() ||
            ConnectivityService.to.isWifi;
        final targetQualityStr =
            isWifi ? pb.wifiQuality : pb.cellularQuality;

        if (targetQualityStr.contains('1080') ||
            targetQualityStr.contains('High')) {
          pref = '1080p';
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
      }
    }

    if (pref != null) {
      if (pref == 'Auto') {
        abr.enableAutoMode();
      } else {
        final matchIdx = abr.resolutionLadder.indexWhere(
          (t) => t.label.contains(pref!),
        );
        if (matchIdx != -1) {
          abr.setManualTier(matchIdx);
        }
      }
    }
  }

  String get currentQualityLabel => abr.isAutoMode.value
      ? 'Auto · ${abr.currentTier.label}'
      : abr.currentTier.label;

  void selectQuality(int tierIndex) {
    if (tierIndex < 0 || tierIndex >= abr.resolutionLadder.length) return;
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
    abr.enableAutoMode();
    TowerPlayerController.globalQualityPreference = 'Auto';
    activePanel.value = '';
    closeSettings();
  }
}
