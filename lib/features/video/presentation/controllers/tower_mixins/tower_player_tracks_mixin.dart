import 'dart:async';
import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
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

  final RxString activeAudioLang = 'English'.obs;
  final RxList<AudioTrack> audioTracks = <AudioTrack>[].obs;

  void syncActiveSubtitle() {
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
    // Read directly from the VideoPlayerController for the most up-to-date
    // position, shifted by any user-configured subtitle offset.
    final rawPos = videoPlayerController.value.position;
    final pos = subtitleOffsetMs.value == 0
        ? rawPos
        : rawPos + Duration(milliseconds: subtitleOffsetMs.value);
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
    } else if (track != null) {
      activeSubLang.value = track.label;
      fetchAndParseSubtitles(track.url);
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
        final response = await AppHttpClient.get(Uri.parse(resolvedUrl));
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'TowerPlayerTracksMixin.fetchFastDownloadUrl',
        );
      }

      if (content == null || content.isEmpty) {
        try {
          Uint8List? data;
          if (url.startsWith('gs://')) {
            data = await FirebaseStorage.instance.refFromURL(url).getData();
          } else if (url.startsWith('https://storage.googleapis.com/') ||
              url.startsWith('https://firebasestorage.googleapis.com/')) {
            data = await FirebaseStorage.instance.refFromURL(url).getData();
          } else if (url.startsWith('subtitles/') || url.startsWith('transcripts/') || url.startsWith('videos/')) {
            data = await FirebaseStorage.instance.ref(url).getData();
          }
          if (data != null && data.isNotEmpty) {
            content = utf8.decode(data, allowMalformed: true);
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'TowerPlayerTracksMixin.fetchFirebaseStorageSubtitles',
          );
        }
      }

      if (content != null && content.isNotEmpty) {
        await parseSubtitleContent(content);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TowerPlayerTracksMixin.fetchAndParseSubtitles',
      );
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
      syncActiveSubtitle();
    } else {
      subtitleSegments.clear();
      currentSubtitle.value = '';
    }
  }

  void setAudioLanguage(AudioTrack track) {
    activeAudioLang.value = track.label;
    activePanel.value = '';
    closeSettings();
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
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

        if (track.url != null && track.url!.isNotEmpty) {
          videoPlayerController.setVolume(0);

          audioTrackController = VideoPlayerController.networkUrl(
            Uri.parse(track.url!),
            httpHeaders: StorageUtils.getSyncMediaHeaders(),
          );
          audioTrackController!.initialize().then((_) async {
            if (audioTrackController == null) return;

            audioTrackController!.setVolume(
              isMuted.value ? 0.0 : volume.value,
            );
            audioTrackController!.setPlaybackSpeed(
              videoPlayerController.value.playbackSpeed,
            );

            final currentPos = videoPlayerController.value.position;
            final audioDur = audioTrackController!.value.duration;
            if (audioDur > Duration.zero && currentPos <= audioDur) {
              await audioTrackController!.seekTo(currentPos);
            }

            if (videoPlayerController.value.isPlaying && audioTrackController != null) {
              await audioTrackController!.play();
            }
          });
        } else {
          videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
        }
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

  void showRequestDialog(BuildContext context, String type) {
    if (!Get.isRegistered<VideoController>(tag: tag)) return;
    final vc = Get.find<VideoController>(tag: tag);
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
