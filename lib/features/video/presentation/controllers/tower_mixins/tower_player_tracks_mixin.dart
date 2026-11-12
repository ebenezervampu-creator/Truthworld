import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/widgets/language_request_dialog.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerTracksMixin on GetxController {
  @override
  bool get isClosed;
  PlaybackSource get activePlayback;
  VideoPlayerController get videoPlayerController;
  VideoPlayerController? get audioTrackController;
  set audioTrackController(VideoPlayerController? ctrl);
  RxBool get isMuted;
  RxDouble get volume;
  RxBool get isLooping;
  String? get tag;
  VideoController? get videoController;
  void trackAnalytics(PlayerEvent event);
  void showToast(String msg);
  void closeSettings();
  RxString get activePanel;
  RxBool get showTranscriptPopup;

  final RxBool subtitlesEnabled = false.obs;
  final RxString activeSubLang = 'Off'.obs;
  final RxList<SubtitleTrack> subtitleTracks = <SubtitleTrack>[].obs;
  final RxList<SubtitleSegment> subtitleSegments = <SubtitleSegment>[].obs;
  final RxBool isLoadingSubtitles = false.obs;
  final RxString currentSubtitle = ''.obs;
  final Rx<SubtitleSegment?> activeSubtitleSegment = Rx<SubtitleSegment?>(null);
  final RxInt subtitleOffsetMs = 0.obs;
  Timer? subtitleSyncTimer;

  void adjustSubtitleOffset(int deltaMs) {
    subtitleOffsetMs.value += deltaMs;
    final sign = subtitleOffsetMs.value > 0 ? '+' : '';
    showToast('Subtitle sync: $sign${subtitleOffsetMs.value}ms');
  }

  void resetSubtitleOffset() {
    subtitleOffsetMs.value = 0;
    showToast('Subtitle sync reset to 0ms');
  }

  final RxString activeAudioLang = 'Original'.obs;
  final RxList<AudioTrack> audioTracks = <AudioTrack>[].obs;
  final RxString activeVideoLang = 'Original'.obs;
  final RxList<VideoTrack> videoTracks = <VideoTrack>[].obs;

  bool get hasAlternateAudioTrack {
    final lang = activeAudioLang.value.trim().toLowerCase();
    if (lang.isEmpty ||
        lang == 'off' ||
        lang == 'original' ||
        lang.startsWith('original')) {
      return false;
    }
    final ctrl = audioTrackController;
    return ctrl != null && !ctrl.value.hasError;
  }

  void fallbackToOriginalAudio({String? reason}) {
    if (audioTrackController != null) {
      try {
        audioTrackController!.dispose();
      } catch (_) {}
      audioTrackController = null;
    }
    activeAudioLang.value =
        audioTracks.isNotEmpty ? audioTracks.first.label : 'Original';
    videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
    showToast('Original Audio');
  }

  void syncActiveSubtitle({Duration? overridePos}) {
    if (isClosed) return;

    // Bidirectional fallback: If local subtitleSegments is empty, check VideoController
    if (subtitleSegments.isEmpty) {
      final vc = videoController;
      if (vc != null && vc.transcriptSegments.isNotEmpty) {
        subtitleSegments.assignAll(vc.transcriptSegments);
      }
    }

    if (subtitleSegments.isEmpty) {
      if (currentSubtitle.value.isNotEmpty) currentSubtitle.value = '';
      if (activeSubtitleSegment.value != null) activeSubtitleSegment.value = null;
      return;
    }
    // Read clock position: when an alternate audio track is active, lock subtitles
    // directly to the audible audio track position to ensure 100% speech-to-subtitle sync.
    final useAudioClock = overridePos == null &&
        audioTrackController != null &&
        audioTrackController!.value.isInitialized &&
        activeAudioLang.value != 'Original' &&
        activeAudioLang.value != 'Off' &&
        activeAudioLang.value.isNotEmpty;

    Duration rawPos;
    if (overridePos != null) {
      rawPos = overridePos;
    } else {
      Duration? audioPos;
      if (useAudioClock) {
        try {
          audioPos = audioTrackController?.value.position;
        } catch (_) {}
      }
      rawPos = audioPos ?? videoPlayerController.value.position;
    }
    // For real-time video playback (overridePos == null), apply a 75ms audio clock lead
    // to compensate for hardware audio buffer latency and align subtitle display with vocal onset.
    final clockLeadMs = (overridePos == null) ? 75 : 0;
    final totalOffsetMs = subtitleOffsetMs.value + clockLeadMs;
    final pos = totalOffsetMs == 0
        ? rawPos
        : rawPos + Duration(milliseconds: totalOffsetMs);
    final seg = SubtitleParser.findActiveSubtitle(subtitleSegments, pos);
    final text = seg?.text ?? '';
    if (currentSubtitle.value != text) {
      currentSubtitle.value = text;
    }
    if (activeSubtitleSegment.value != seg) {
      activeSubtitleSegment.value = seg;
    }
    final vc = videoController;
    if (vc != null && (vc.isTranscriptVisible.value || showTranscriptPopup.value)) {
      vc.transcriptController.updateActiveSegment(seg, currentPos: pos);
    }
  }

  void startSubtitleSyncTimer() {
    if (subtitleSyncTimer != null && subtitleSyncTimer!.isActive) return;
    subtitleSyncTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => syncActiveSubtitle(),
    );
  }

  void stopSubtitleSyncTimer() {
    subtitleSyncTimer?.cancel();
    subtitleSyncTimer = null;
  }

  SubtitleSegment? findSubtitle(Duration pos) {
    return SubtitleParser.findActiveSubtitle(subtitleSegments, pos);
  }

  void setSubtitles({required bool enabled, SubtitleTrack? track}) {
    subtitlesEnabled.value = enabled;
    if (!enabled) {
      activeSubLang.value = 'Off';
      if (currentSubtitle.value.isNotEmpty) currentSubtitle.value = '';
      activeSubtitleSegment.value = null;
      stopSubtitleSyncTimer();
    } else if (track != null) {
      activeSubLang.value = track.label;
      fetchAndParseSubtitles(track.url);
      startSubtitleSyncTimer();
    } else {
      activeSubLang.value = 'Auto';
      if (subtitleSegments.isEmpty) {
        final vc = videoController;
        if (vc != null && vc.transcriptSegments.isNotEmpty) {
          subtitleSegments.assignAll(vc.transcriptSegments);
        }
      }
      if (subtitleSegments.isNotEmpty) {
        startSubtitleSyncTimer();
        syncActiveSubtitle();
      }
    }
    TowerPlayerController.globalSubtitlesEnabled = enabled;
    TowerPlayerController.globalActiveSubLang = activeSubLang.value;
    trackAnalytics(
      PlayerEvent('subtitle_change', data: {'lang': activeSubLang.value}),
    );
  }

  Future<void> fetchAndParseSubtitles(String url) async {
    if (url.isEmpty) return;
    isLoadingSubtitles.value = true;
    try {
      String? content;

      try {
        final resolvedUrl = StorageUtils.getFastDownloadUrl(url);
        final headers = await StorageUtils.getMediaHeaders();
        final response = await AppHttpClient.get(
          Uri.parse(resolvedUrl),
          headers: headers,
        );
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (e) {
        logger.warning(
          'Fast download HTTP probe for subtitles skipped or failed: $e',
          tag: 'TowerPlayerTracksMixin.fetchFastDownloadUrl',
        );
      }

      if (content == null || content.isEmpty) {
        try {
          Uint8List? data;
          final ref = StorageUtils.getStorageRef(url);
          if (ref != null) {
            data = await StorageUtils.getDataWithTimeout(ref);
          }
          if (data != null && data.isNotEmpty) {
            content = utf8.decode(data, allowMalformed: true);
          }
        } catch (_) {}
      }

      if (content != null && content.isNotEmpty) {
        await parseSubtitleContent(content);
      }
    } catch (e, stackTrace) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('unauthorized') ||
          errStr.contains('permission-denied') ||
          errStr.contains('object-not-found')) {
        logger.warning(
          'Subtitle track loading skipped (unavailable or unauthorized): $e',
          tag: 'TowerPlayerTracksMixin.fetchAndParseSubtitles',
        );
      } else {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'TowerPlayerTracksMixin.fetchAndParseSubtitles',
        );
      }
      subtitleSegments.clear();
    } finally {
      isLoadingSubtitles.value = false;
    }
  }

  Future<void> parseSubtitleContent(String content) async {
    final segs = await IsolateComputeUtils.parseSubtitlesAsync(content);
    if (isClosed) return;
    if (segs.isNotEmpty) {
      subtitleSegments.assignAll(segs);
      if (subtitlesEnabled.value) {
        startSubtitleSyncTimer();
      }
      syncActiveSubtitle();
    } else {
      subtitleSegments.clear();
      currentSubtitle.value = '';
    }
  }

  int _audioInitEpoch = 0;

  Future<void> setAudioLanguage(AudioTrack track) async {
    final currentEpoch = ++_audioInitEpoch;
    activeAudioLang.value = track.label;
    activePanel.value = '';
    closeSettings();
    try {
      if (audioTrackController != null) {
        try {
          audioTrackController!.dispose();
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'TowerPlayerTracksMixin.disposeOldAudioController',
          );
        }
        audioTrackController = null;
      }

      final isAlternateTrack = track.url != null &&
          track.url!.isNotEmpty &&
          track.type != 'Original' &&
          !track.label.toLowerCase().startsWith('original');

      if (isAlternateTrack) {
        var trackUrl = track.url!.trim();
        if (!trackUrl.contains('token=')) {
          final ref = StorageUtils.getStorageRef(trackUrl);
          if (ref != null) {
            try {
              trackUrl = await ref.getDownloadURL();
            } catch (e, stackTrace) {
              ErrorHandler.log(
                e,
                stackTrace: stackTrace,
                tag: 'TowerPlayerTracksMixin.resolveAudioTrackUrl',
              );
            }
          }
        }

        if (currentEpoch != _audioInitEpoch || isClosed) return;

        final isFirebaseStorageDownloadUrl =
            trackUrl.contains('firebasestorage.googleapis.com') &&
                trackUrl.contains('token=');

        final newAudioCtrl = VideoPlayerController.networkUrl(
          Uri.parse(trackUrl),
          httpHeaders: isFirebaseStorageDownloadUrl
              ? const <String, String>{}
              : StorageUtils.getSyncMediaHeaders(),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: true,
          ),
        );
        audioTrackController = newAudioCtrl;

        // 1. Immediately mute main video player so original audio does not bleed
        videoPlayerController.setVolume(0.0);

        void onAudioTrackError() {
          if (newAudioCtrl.value.hasError &&
              audioTrackController == newAudioCtrl &&
              currentEpoch == _audioInitEpoch) {
            ErrorHandler.log(
              newAudioCtrl.value.errorDescription,
              tag: 'TowerPlayerTracksMixin.audioTrackController.error',
            );
            fallbackToOriginalAudio(
              reason: 'Alternate audio playback failed',
            );
          }
        }

        newAudioCtrl.addListener(onAudioTrackError);

        newAudioCtrl.initialize().then((_) async {
          if (currentEpoch != _audioInitEpoch ||
              audioTrackController != newAudioCtrl ||
              isClosed) {
            try {
              newAudioCtrl.dispose();
            } catch (_) {}
            return;
          }

          if (newAudioCtrl.value.hasError) {
            fallbackToOriginalAudio(reason: 'Audio track reported error');
            return;
          }

          // Strictly enforce zero volume on main video player
          videoPlayerController.setVolume(0.0);

          newAudioCtrl.setVolume(
            isMuted.value ? 0.0 : volume.value,
          );
          newAudioCtrl.setPlaybackSpeed(
            videoPlayerController.value.playbackSpeed,
          );

          if (isLooping.value) {
            newAudioCtrl.setLooping(true);
          }

          final currentPos = videoPlayerController.value.position;
          final audioDur = newAudioCtrl.value.duration;
          if (currentPos > Duration.zero &&
              (audioDur == Duration.zero || currentPos <= audioDur)) {
            TowerPlayerVpcEventHandler.notifyManualSeekInitiated();
            await newAudioCtrl.seekTo(currentPos);
          }

          if (videoPlayerController.value.isPlaying &&
              audioTrackController == newAudioCtrl) {
            await newAudioCtrl.play();
          }
        }).catchError((e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'TowerPlayerTracksMixin.initAudioTrackController',
          );
          if (audioTrackController == newAudioCtrl &&
              currentEpoch == _audioInitEpoch) {
            fallbackToOriginalAudio(reason: 'Failed to initialize audio track');
          }
        });
      } else {
        // Reverting to Original Audio
        videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TowerPlayerTracksMixin.setAudioLanguage',
      );
    }
    trackAnalytics(PlayerEvent('audio_lang', data: {'lang': track.langCode}));
  }

  void setVideoLanguage(VideoTrack track) {
    activeVideoLang.value = track.label;
    activePanel.value = '';
    closeSettings();
    try {
      final vc = videoController;
      if (vc != null) {
        vc.setVideoTrack(track);
      }
      if (track.type == 'Video' && track.url != null && track.url!.isNotEmpty) {
        if (audioTrackController != null) {
          try {
            audioTrackController!.dispose();
          } catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'TowerPlayerTracksMixin.disposeAudioControllerOnVideoTrackSwitch',
            );
          }
          audioTrackController = null;
        }
        videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TowerPlayerTracksMixin.setVideoLanguage',
      );
    }
    showToast('Video: ${track.label}');
    trackAnalytics(PlayerEvent('video_lang', data: {'lang': track.langCode}));
  }

  void showRequestDialog(BuildContext context, String type) {
    final vc = videoController;
    if (vc == null) return;
    if (!vc.isAuthenticated) {
      showToast('Please login to request languages');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => LanguageRequestDialog(
        type: type,
        onRequested: (lang) async {
          final ok = await vc.requestLanguage(lang, type);
          showToast(
            ok ? 'Request submitted for $lang' : 'Failed to submit request',
          );
        },
      ),
    );
  }
}
