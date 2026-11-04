import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/player_lock_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_ad_policy_evaluator.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

/// Mixin encapsulating reactive video state, UI observables, source references,
/// and sleep timer/lock screen controllers for TowerPlayerController.
mixin TowerPlayerStateMixin on GetxController {
  String? get tag;
  RxBool get isAudioOnly;
  RxBool get isShowingAd;
  VideoController? get videoController;

  // ── Reactive Video State ──────────────────────────────────
  late Rx<VideoPlayerValue> rxValue;
  VideoPlayerValue get vv => rxValue.value;

  final RxBool isInitialized = false.obs;
  final RxDouble aspectRatio = 1.777.obs;
  final RxBool isPlaying = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorDescription = ''.obs;
  final RxBool showFullscreenActionsDock = true.obs;

  // ── UI Observables ────────────────────────────────────────
  final RxBool controlsVisible = true.obs;
  final RxBool settingsOpen = false.obs;
  final RxBool isBuffering = false.obs;
  final RxBool isDragging = false.obs;
  final Rx<Duration> dragPos = Duration.zero.obs;
  final RxBool isFullScreen = false.obs;
  final RxBool userExitedFullscreen = false.obs;
  final RxBool progressBarHovered = false.obs;
  final RxBool showCommentsPopup = false.obs;
  final RxBool showTranscriptPopup = false.obs;
  final ScrollController overlayTranscriptScrollController = ScrollController();
  final RxBool isOverlayTranscriptAutoScroll = true.obs;
  Timer? overlayTranscriptAutoScrollTimer;
  int lastOverlayScrollIndex = -1;

  void onOverlayTranscriptUserScrolled() {
    isOverlayTranscriptAutoScroll.value = false;
    overlayTranscriptAutoScrollTimer?.cancel();
    overlayTranscriptAutoScrollTimer = Timer(const Duration(seconds: 4), () {
      isOverlayTranscriptAutoScroll.value = true;
    });
  }

  void resumeOverlayTranscriptAutoScroll() {
    overlayTranscriptAutoScrollTimer?.cancel();
    overlayTranscriptAutoScrollTimer = null;
    isOverlayTranscriptAutoScroll.value = true;
  }
  final RxBool showFactCheckPopup = false.obs;
  final RxBool showMoreVideos = false.obs;
  final RxBool isLooping = false.obs;

  // ── Focus & Timers ────────────────────────────────────────
  final FocusNode focusNode = FocusNode();
  final TimerBag timers = TimerBag();
  Timer? errorDebounceTimer;
  DateTime lastTrackSync = DateTime(2000);
  bool hasEnded = false;
  bool hasShownNearEndMoreVideos = false;

  // ── Alternate Audio & Source References ───────────────────
  VideoPlayerController? audioTrackController;
  PlaybackSource? videoPlaybackSource;

  // ── Sleep Timer & Lock Screen ─────────────────────────────
  SleepTimerService get sleepTimerService => SleepTimerService.to;
  late final PlayerLockController lockController = Get.put(
    PlayerLockController(),
    tag: tag,
  );

  RxInt get sleepTimerRemainingSeconds => sleepTimerService.remainingSeconds;
  RxBool get isSleepTimerActive => sleepTimerService.isActive.obs;
  RxBool get isSleepTimerAtEndOfVideo => sleepTimerService.isAtEndOfVideo.obs;

  // ── Ad State Bridge ───────────────────────────────────────
  bool get isPremiumUser => TowerPlayerAdPolicyEvaluator.isPremiumUser();
  bool get shouldSuppressAds {
    try {
      final vCtrl = videoController;
      final isMember = vCtrl?.channelController.subController.isChannelMember.value ?? false;
      final channel = vCtrl?.channelController.selectedChannel.value;
      final channelNoAds = channel?.noAdsForMembers ?? false;
      return TowerPlayerAdPolicyEvaluator.shouldSuppressAds(
        isAudioOnly: isAudioOnly.value,
        isChannelMember: isMember,
        channelNoAdsForMembers: channelNoAds,
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerStateMixin.shouldSuppressAds',
      );
      return false;
    }
  }

  // ── Bridge Hooks ──────────────────────────────────────────
  bool get isShowingAdValue => isShowingAd.value;
  bool get isFullScreenValue => isFullScreen.value;

  int get seekStepSeconds {
    if (Get.isRegistered<UserSettingsController>()) {
      return UserSettingsController.to.playback.value.seekDurationSeconds;
    }
    return 10;
  }
}
