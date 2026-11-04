import 'dart:async';
import 'dart:math';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerAdMixin on GetxController {
  // ── Abstract dependencies ──
  VideoPlayerController get videoPlayerController;
  Rx<VideoPlayerValue> get rxValue;
  RxBool get isPlaying;
  RxBool get hasError;
  RxDouble get volume;
  RxBool get isMuted;
  RxString get activeSubLang;
  RxString get activeAudioLang;
  String? get tag;
  VideoController? get videoController;
  ChewieController? get chewieController;
  PlaybackSource? get videoPlaybackSource;
  VideoPlayerController? get audioTrackController;
  bool get hasAlternateAudioTrack;

  void startWatchTimer();
  void stopWatchTimer();
  void startHideTimer();
  void resetRetryCount();
  void showToast(String msg);

  // ── Ad Player State ──
  final RxBool isShowingAd = false.obs;
  final Rxn<PlaybackAd> currentAd = Rxn<PlaybackAd>();
  final RxInt adTimeRemaining = 0.obs;
  final RxInt skipCountdown = 0.obs;
  final RxBool adCanSkip = false.obs;
  VideoPlayerController? adPlayerController;
  VideoPlayerController? adAudioTrackController;
  final RxString currentAdSubtitle = ''.obs;
  final RxList<SubtitleSegment> adSubtitleSegments = <SubtitleSegment>[].obs;
  final RxBool isAdSubtitlesEnabled = true.obs;
  final RxString activeAdSubtitleLang = 'en'.obs;
  final RxString activeAdAudioLang = 'original'.obs;

  bool preRollPlayed = false;
  bool midRollPlayed = false;
  bool sponsorMidRollPlayed = false;
  bool isFinishingAd = false;
  bool isCurrentAdPreRoll = false;

  Future<void> startAd({required bool isPreRoll}) async {
    isCurrentAdPreRoll = isPreRoll;
    isFinishingAd = false;
    isShowingAd.value = true;
    stopWatchTimer();
    if (videoPlayerController.value.isPlaying) {
      try {
        videoPlayerController.pause();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerAdMixin.startAd.pauseVideo',
        );
      }
    }
    if (audioTrackController?.value.isPlaying == true) {
      try {
        audioTrackController?.pause();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerAdMixin.startAd.pauseAudio',
        );
      }
    }

    // Check for custom advertiser skippable campaigns first
    final activeVideoAds = <AdItem>[];
    if (Get.isRegistered<AdService>()) {
      activeVideoAds.addAll(AdService.to.getSkippableVideoAds());
    }

    if (activeVideoAds.isEmpty) {
      finishAd();
      return;
    }

    final random = Random();
    final selectedAd = activeVideoAds[random.nextInt(activeVideoAds.length)];

    String? resolvedUrl;
    if (selectedAd.resolutions != null && selectedAd.resolutions!.isNotEmpty) {
      final resList = List<Map<String, dynamic>>.from(selectedAd.resolutions!);

      // Select resolution based on global quality preference if set and not Auto
      final pref = TowerPlayerController.globalQualityPreference;
      Map<String, dynamic>? selectedResolution;

      if (pref != null && pref != 'Auto') {
        final cleanPref = pref.toLowerCase();
        for (final res in resList) {
          final label = (res['label'] as String? ?? '').toLowerCase();
          if (label == cleanPref ||
              label.contains(cleanPref) ||
              cleanPref.contains(label)) {
            selectedResolution = res;
            break;
          }
        }
      }

      // If Auto or no direct match, pick optimal/highest resolution <= 1040p
      if (selectedResolution == null) {
        resList.sort(
          (a, b) =>
              (b['height'] as int? ?? 0).compareTo(a['height'] as int? ?? 0),
        );
        selectedResolution = resList.firstWhere(
          (res) => (res['height'] as int? ?? 0) <= 1040,
          orElse: () => resList.first,
        );
      }

      if (selectedResolution['url'] != null) {
        resolvedUrl = selectedResolution['url'] as String;
        debugPrint(
          '[TowerPlayerController] ✅ Playing resolved ad URL directly from campaign document (${selectedResolution['label']}): $resolvedUrl',
        );
      }
    }

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      debugPrint(
        '[TowerPlayerController] ⚠️ Ad has no resolved resolutions in ad_campaigns. Skipping ad and resuming video.',
      );
      finishAd();
      return;
    }

    final ad = PlaybackAd(
      videoUrl: resolvedUrl,
      title: selectedAd.title,
      description: selectedAd.description,
      clickUrl: selectedAd.ctaTarget,
      skippable: selectedAd.isSkippableAd,
      duration: const Duration(seconds: 15),
      subtitles: selectedAd.subtitles,
      audioTracks: selectedAd.audioTracks,
    );

    currentAd.value = ad;
    adCanSkip.value = false;
    skipCountdown.value = ad.skippable ? 5 : 0;
    adTimeRemaining.value = ad.duration.inSeconds;

    final apc = VideoPlayerController.networkUrl(
      Uri.parse(ad.videoUrl),
      httpHeaders: StorageUtils.getSyncMediaHeaders(),
    );
    adPlayerController = apc;

    try {
      await apc.initialize();
      apc.addListener(onAdVpcUpdate);
      await apc.play();
      setupAdSubtitlesAndDubbing(ad);
      update();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAdMixin.initAd',
      );
      finishAd();
    }
  }

  Future<void> startSponsorAd(
    AdItem sponsorAd, {
    required bool isPreRoll,
  }) async {
    isCurrentAdPreRoll = isPreRoll;
    isFinishingAd = false;
    isShowingAd.value = true;
    stopWatchTimer();
    if (videoPlayerController.value.isPlaying) {
      try {
        videoPlayerController.pause();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerAdMixin.startSponsorAd.pauseVideo',
        );
      }
    }
    if (audioTrackController?.value.isPlaying == true) {
      try {
        audioTrackController?.pause();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerAdMixin.startSponsorAd.pauseAudio',
        );
      }
    }

    final resolvedUrl = isPreRoll
        ? sponsorAd.videoUrl
        : sponsorAd.midrollVideoUrl;

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      debugPrint(
        '[TowerPlayerController] Sponsor ad URL missing. Skipping ad and resuming playback.',
      );
      finishAd();
      return;
    }

    final ad = PlaybackAd(
      videoUrl: resolvedUrl,
      title: isPreRoll ? sponsorAd.sponsorBumperText : sponsorAd.title,
      description: isPreRoll
          ? 'Official Video Sponsor Bumper (5s Intro)'
          : sponsorAd.description,
      clickUrl: sponsorAd.ctaTarget,
      skippable: !isPreRoll,
      duration: isPreRoll ? const Duration(seconds: 5) : const Duration(seconds: 15),
      isSponsorBumper: isPreRoll,
      subtitles: sponsorAd.subtitles,
      audioTracks: sponsorAd.audioTracks,
    );

    currentAd.value = ad;
    adCanSkip.value = false;
    skipCountdown.value = ad.skippable ? 5 : 0;
    adTimeRemaining.value = ad.duration.inSeconds;

    final apc = VideoPlayerController.networkUrl(
      Uri.parse(ad.videoUrl),
      httpHeaders: StorageUtils.getSyncMediaHeaders(),
    );
    adPlayerController = apc;

    try {
      await apc.initialize();
      apc.addListener(onAdVpcUpdate);
      await apc.play();
      setupAdSubtitlesAndDubbing(ad);
      update();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAdMixin.initSponsorAd',
      );
      finishAd();
    }
  }

  void setupAdSubtitlesAndDubbing(PlaybackAd ad) {
    currentAdSubtitle.value = '';
    adSubtitleSegments.clear();

    final subs = ad.subtitles;
    if (subs != null && subs.isNotEmpty) {
      String? matchedLang;
      if (subs.containsKey(activeSubLang.value)) {
        matchedLang = activeSubLang.value;
      } else if (subs.containsKey('en')) {
        matchedLang = 'en';
      } else if (subs.isNotEmpty) {
        matchedLang = subs.keys.first;
      }

      if (matchedLang != null && subs[matchedLang] != null) {
        activeAdSubtitleLang.value = matchedLang;
        final rawContent = subs[matchedLang]!;
        final segs = SubtitleParser.parse(rawContent);
        adSubtitleSegments.assignAll(segs);
      }
    }

    disposeAdAudioTrack();
    final dubs = ad.audioTracks;
    if (dubs != null && dubs.isNotEmpty) {
      final targetLang = activeAudioLang.value.toLowerCase();
      String? matchedDubUrl;
      for (final entry in dubs.entries) {
        if (entry.key.toLowerCase() == targetLang || targetLang.contains(entry.key.toLowerCase())) {
          matchedDubUrl = entry.value;
          activeAdAudioLang.value = entry.key;
          break;
        }
      }

      if (matchedDubUrl != null && matchedDubUrl.isNotEmpty) {
        initializeAdAudioDub(matchedDubUrl);
      } else {
        activeAdAudioLang.value = 'original';
      }
    } else {
      activeAdAudioLang.value = 'original';
    }
  }

  void initializeAdAudioDub(String url) {
    try {
      final apc = adPlayerController;
      if (apc != null) {
        apc.setVolume(0);
      }
      adAudioTrackController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: StorageUtils.getSyncMediaHeaders(),
      );
      adAudioTrackController!.initialize().then((_) {
        if (adAudioTrackController == null || isFinishingAd) return;
        adAudioTrackController!.setVolume(isMuted.value ? 0.0 : volume.value);
        if (apc != null && apc.value.isPlaying) {
          adAudioTrackController!.play();
        }
      }).catchError((e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerAdMixin.adAudioDubInit',
        );
        apc?.setVolume(isMuted.value ? 0.0 : volume.value);
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAdMixin.initAdAudioTrack',
      );
    }
  }

  void disposeAdAudioTrack() {
    if (adAudioTrackController != null) {
      try {
        adAudioTrackController!.dispose();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerAdMixin.disposeAdAudioTrack',
        );
      }
      adAudioTrackController = null;
    }
  }

  void setAdSubtitleLanguage(String langCode) {
    activeAdSubtitleLang.value = langCode;
    final subs = currentAd.value?.subtitles;
    if (subs != null && subs.containsKey(langCode)) {
      final content = subs[langCode]!;
      final segs = SubtitleParser.parse(content);
      adSubtitleSegments.assignAll(segs);
      if (adPlayerController != null) {
        final pos = adPlayerController!.value.position;
        final seg = SubtitleParser.findActiveSubtitle(adSubtitleSegments, pos);
        currentAdSubtitle.value = seg?.text ?? '';
      }
    }
  }

  void toggleAdSubtitles() {
    isAdSubtitlesEnabled.value = !isAdSubtitlesEnabled.value;
    if (!isAdSubtitlesEnabled.value) {
      currentAdSubtitle.value = '';
    }
  }

  void setAdAudioLanguage(String langCode) {
    activeAdAudioLang.value = langCode;
    disposeAdAudioTrack();
    final apc = adPlayerController;
    if (langCode == 'original' || currentAd.value?.audioTracks == null) {
      apc?.setVolume(isMuted.value ? 0.0 : volume.value);
      return;
    }

    final dubUrl = currentAd.value?.audioTracks?[langCode];
    if (dubUrl != null && dubUrl.isNotEmpty) {
      initializeAdAudioDub(dubUrl);
    } else {
      apc?.setVolume(isMuted.value ? 0.0 : volume.value);
    }
  }

  void onAdVpcUpdate() {
    if (isFinishingAd || adPlayerController == null) return;
    final val = adPlayerController!.value;

    if (val.hasError) {
      debugPrint('[TowerPlayer] Ad playback failed. Skipping ad.');
      finishAd();
      return;
    }

    final pos = val.position;
    final mediaDur = val.duration;
    final targetDur = currentAd.value?.duration;

    final effectiveDur = (targetDur != null && targetDur > Duration.zero)
        ? (mediaDur > Duration.zero && mediaDur < targetDur ? mediaDur : targetDur)
        : mediaDur;

    adTimeRemaining.value = max(0, effectiveDur.inSeconds - pos.inSeconds);

    if (currentAd.value?.skippable ?? false) {
      final elapsed = pos.inSeconds;
      if (elapsed >= 5) {
        adCanSkip.value = true;
        skipCountdown.value = 0;
      } else {
        adCanSkip.value = false;
        skipCountdown.value = 5 - elapsed;
      }
    } else {
      adCanSkip.value = false;
      skipCountdown.value = 0;
    }

    if (isAdSubtitlesEnabled.value && adSubtitleSegments.isNotEmpty) {
      final seg = SubtitleParser.findActiveSubtitle(adSubtitleSegments, pos);
      currentAdSubtitle.value = seg?.text ?? '';
    } else {
      currentAdSubtitle.value = '';
    }

    if (adAudioTrackController != null && adAudioTrackController!.value.isInitialized) {
      final audioPos = adAudioTrackController!.value.position;
      final diff = (audioPos.inMilliseconds - pos.inMilliseconds).abs();
      if (diff > 350) {
        adAudioTrackController!.seekTo(pos);
      }
      if (val.isPlaying && !adAudioTrackController!.value.isPlaying) {
        adAudioTrackController!.play();
      } else if (!val.isPlaying && adAudioTrackController!.value.isPlaying) {
        adAudioTrackController!.pause();
      }
    }

    if (pos >= effectiveDur && effectiveDur > Duration.zero) {
      finishAd();
    }
  }

  void skipAd() {
    if (adCanSkip.value && !isFinishingAd) {
      finishAd();
    }
  }

  Future<void> finishAd() async {
    if (isFinishingAd) return;
    isFinishingAd = true;

    disposeAdAudioTrack();
    currentAdSubtitle.value = '';
    adSubtitleSegments.clear();

    final apc = adPlayerController;
    adPlayerController = null;
    currentAd.value = null;
    isShowingAd.value = false;

    try {
      apc?.removeListener(onAdVpcUpdate);
      apc?.pause();
      apc?.dispose();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAdMixin.disposeAdVpc',
      );
    }

    hasError.value = false;
    resetRetryCount();

    if (tag != null && Get.isRegistered<VideoController>(tag: tag)) {
      Get.find<VideoController>(tag: tag).showThumbnail.value = false;
    } else if (Get.isRegistered<VideoController>()) {
      Get.find<VideoController>().showThumbnail.value = false;
    }

    update();

    try {
      if (isCurrentAdPreRoll &&
          !VideoPlaybackHandoff.hasActivePosition(tag ?? videoController?.video.id ?? '') &&
          (Get.arguments is! Map || Get.arguments['isFromMiniplayer'] != true)) {
        if (videoPlayerController.value.position > Duration.zero) {
          await videoPlayerController.seekTo(Duration.zero);
        }
      }
      isCurrentAdPreRoll = false;
      if (hasAlternateAudioTrack) {
        await videoPlayerController.setVolume(0.0);
      }
      await videoPlayerController.play();
      isPlaying.value = true;
      rxValue.value = videoPlayerController.value;
      if (audioTrackController != null &&
          audioTrackController!.value.isInitialized) {
        final pos = videoPlayerController.value.position;
        if (pos <= audioTrackController!.value.duration) {
          await audioTrackController!.seekTo(pos);
        }
        await audioTrackController!.play();
      }
      try {
        chewieController?.play();
      } catch (_) {}
      try {
        videoController?.chewieController?.play();
      } catch (_) {}
      videoPlaybackSource?.play();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAdMixin.finishAdResumePlayback',
      );
      try {
        if (e.toString().contains('NotAllowedError') ||
            e.toString().contains('play()')) {
          await videoPlayerController.setVolume(0);
          await videoPlayerController.play();
          isPlaying.value = true;
          rxValue.value = videoPlayerController.value;
        } else {
          await videoPlayerController.play();
          isPlaying.value = true;
          rxValue.value = videoPlayerController.value;
        }
      } catch (e2, s2) {
        ErrorHandler.log(
          e2,
          stackTrace: s2,
          tag: 'TowerPlayerAdMixin.finishAdAutoplayFallback',
        );
      }
    }

    startWatchTimer();
    startHideTimer();
    isFinishingAd = false;
    update();
  }

  void togglePlayPauseAd() {
    if (adPlayerController == null) return;
    if (adPlayerController!.value.isPlaying) {
      adPlayerController!.pause();
    } else {
      adPlayerController!.play();
    }
  }

  void toggleMuteAd() {
    if (adPlayerController == null) return;
    if (adPlayerController!.value.volume > 0) {
      adPlayerController!.setVolume(0);
    } else {
      adPlayerController!.setVolume(volume.value);
    }
  }
}
