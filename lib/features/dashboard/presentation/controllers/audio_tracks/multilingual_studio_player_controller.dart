import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/studio_media_download_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/studio_video_resolution_resolver.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Coordinator controller for the Studio Multi-Language Video Player.
/// Extends [MultiAudioPlayerController] to provide seamless synchronized multi-language playback,
/// live language switching, progress scrubbing, and native video downloads with chosen audio tracks.
class MultilingualStudioPlayerController extends MultiAudioPlayerController {
  static const String _logTag = 'MultilingualStudioPlayerController';

  final RxBool isDownloading = false.obs;
  String _activeVideoId = '';

  /// Synchronizes available audio tracks from the active Video and the coordinator's current tracks list.
  Future<void> syncWithVideoAndTracks({
    required Video video,
    required AudioTracksController tracksController,
    bool forceRefresh = false,
  }) async {
    final trackOptions = buildTrackOptions(
      video: video,
      tracksController: tracksController,
    );

    availableTracks.value = trackOptions;

    // Pick selected track if not selected or current selection is invalid
    final currentCode = selectedTrack.value?.code ?? tracksController.selectedLanguage.value;
    final match = trackOptions.firstWhereOrNull((t) => t.code == currentCode);
    if (match != null && match.code != selectedTrack.value?.code) {
      selectedTrack.value = match;
    } else if (selectedTrack.value == null && trackOptions.isNotEmpty) {
      selectedTrack.value = trackOptions.first;
    }

    // Initialize or reinitialize player when video changes or on forced refresh
    if (_activeVideoId != video.id || videoController == null || forceRefresh) {
      _activeVideoId = video.id;

      // STRICT ZERO RAW VIDEO: Resolve processed adaptive resolutions (1080p, 720p, 480p, etc.)
      final resolutions = await StudioVideoResolutionResolver.resolveResolutions(video);
      availableResolutions.value = resolutions;
      final defaultRes = StudioVideoResolutionResolver.pickDefaultResolution(resolutions);
      currentResolution.value = defaultRes;

      final playUrl = defaultRes?.url ?? (resolutions.isNotEmpty ? resolutions.first.url : '');

      if (playUrl.isNotEmpty) {
        unawaited(
          initialize(
            playUrl,
            tracks: trackOptions,
            preferredTrackCode: currentCode,
            video: video,
            targetResolution: defaultRes,
          ),
        );
      } else if (video.videoUrl.isNotEmpty && !MultiAudioPlayerController.isRawVideoUrl(video.videoUrl)) {
        // Safe non-raw fallback (e.g. test environments)
        unawaited(
          initialize(
            video.videoUrl,
            tracks: trackOptions,
            preferredTrackCode: currentCode,
            video: video,
          ),
        );
      } else {
        hasError.value = true;
        rxErrorMessage.value = 'Processed video resolutions are currently being generated. Transcoded streams will be available shortly.';
        isInitializing.value = false;
      }
    }
  }

  static String _cleanLanguageLabel(String name) {
    if (name.contains('(')) {
      final clean = name.split('(').first.trim();
      if (clean.isNotEmpty) return clean;
    }
    return name.trim();
  }

  /// Builds the complete list of [AudioTrackOption] items from video, localization cache, and current tracks.
  static List<AudioTrackOption> buildTrackOptions({
    required Video video,
    required AudioTracksController tracksController,
  }) {
    final options = <AudioTrackOption>[];
    final addedCodes = <String>{};

    // 1. Base / embedded track (Primary language)
    final baseLang = video.language.isNotEmpty ? video.language : 'en';
    final rawBaseLabel = tracksController.getLanguageName(baseLang);
    final baseLabel = _cleanLanguageLabel(rawBaseLabel.isNotEmpty ? rawBaseLabel : 'English');
    final cachedLoc = VideoMediaService.localizationCache[video.id];
    final mergedAudio = Map<String, String>.from(video.audioTracks)
      ..addAll(cachedLoc?.audioTracks ?? const {});
    final mergedDubbed = Map<String, String>.from(video.dubbedVideos)
      ..addAll(cachedLoc?.dubbedVideos ?? const {});

    final baseAudioUrl = mergedAudio[baseLang] ?? '';
    final baseVideoUrl = mergedDubbed[baseLang];

    options.add(
      AudioTrackOption(
        code: baseLang,
        label: baseLabel.isNotEmpty ? baseLabel : 'English',
        isEmbedded: true,
        audioUrl: baseAudioUrl.isNotEmpty ? baseAudioUrl : null,
        videoUrl: (baseVideoUrl != null && baseVideoUrl.isNotEmpty) ? baseVideoUrl : null,
      ),
    );
    addedCodes.add(baseLang.toLowerCase());

    // 2. Tracks from coordinator's currentTracks (active editor state)
    for (final trackItem in tracksController.currentTracks) {
      final code = trackItem.languageCode.trim().toLowerCase();
      if (code.isEmpty || addedCodes.contains(code)) continue;

      final dubVideo = mergedDubbed[trackItem.languageCode] ?? mergedDubbed[code];
      final audioU = trackItem.audioUrl.isNotEmpty ? trackItem.audioUrl : mergedAudio[code];

      // Only include playable tracks (base track, or tracks with valid audio/video URL)
      if (!trackItem.isBaseTrack &&
          (audioU == null || audioU.trim().isEmpty) &&
          (dubVideo == null || dubVideo.trim().isEmpty) &&
          trackItem.status.toLowerCase() == 'not added') {
        continue;
      }

      final rawLabel = trackItem.languageName.isNotEmpty
          ? trackItem.languageName
          : tracksController.getLanguageName(trackItem.languageCode);
      final label = _cleanLanguageLabel(rawLabel);

      options.add(
        AudioTrackOption(
          code: trackItem.languageCode,
          label: label.isNotEmpty ? label : trackItem.languageCode.toUpperCase(),
          audioUrl: (audioU != null && audioU.isNotEmpty) ? audioU : null,
          videoUrl: (dubVideo != null && dubVideo.isNotEmpty) ? dubVideo : null,
          isEmbedded: trackItem.isBaseTrack,
        ),
      );
      addedCodes.add(code);
    }

    // 3. Any additional languages from video.audioTracks or localization cache
    for (final entry in mergedAudio.entries) {
      final code = entry.key.trim().toLowerCase();
      if (code.isEmpty || addedCodes.contains(code)) continue;

      final rawLabel = tracksController.getLanguageName(entry.key);
      final label = _cleanLanguageLabel(rawLabel);
      final dubVideo = mergedDubbed[entry.key] ?? mergedDubbed[code];

      options.add(
        AudioTrackOption(
          code: entry.key,
          label: label.isNotEmpty ? label : entry.key.toUpperCase(),
          audioUrl: entry.value.trim().isNotEmpty ? entry.value.trim() : null,
          videoUrl: (dubVideo != null && dubVideo.isNotEmpty) ? dubVideo : null,
        ),
      );
      addedCodes.add(code);
    }

    // 4. Any dubbed videos available in video.dubbedVideos
    for (final entry in mergedDubbed.entries) {
      final code = entry.key.trim().toLowerCase();
      if (code.isEmpty || addedCodes.contains(code)) continue;

      final rawLabel = tracksController.getLanguageName(entry.key);
      final label = _cleanLanguageLabel(rawLabel);
      final audioU = mergedAudio[entry.key] ?? mergedAudio[code];

      options.add(
        AudioTrackOption(
          code: entry.key,
          label: label.isNotEmpty ? label : entry.key.toUpperCase(),
          audioUrl: (audioU != null && audioU.isNotEmpty) ? audioU : null,
          videoUrl: entry.value.trim().isNotEmpty ? entry.value.trim() : null,
        ),
      );
      addedCodes.add(code);
    }

    // 5. Any actively generating languages
    for (final genCode in tracksController.generatingDubLanguages) {
      final code = genCode.trim().toLowerCase();
      if (code.isEmpty || addedCodes.contains(code)) continue;

      final rawLabel = tracksController.getLanguageName(genCode);
      final label = _cleanLanguageLabel(rawLabel);

      options.add(
        AudioTrackOption(
          code: genCode,
          label: label.isNotEmpty ? label : genCode.toUpperCase(),
        ),
      );
      addedCodes.add(code);
    }

    // 6. Any actively uploading language
    final uploadingCode = tracksController.uploadingLanguageCode.value.trim().toLowerCase();
    if (uploadingCode.isNotEmpty && !addedCodes.contains(uploadingCode)) {
      final rawLabel = tracksController.getLanguageName(uploadingCode);
      final label = _cleanLanguageLabel(rawLabel);

      options.add(
        AudioTrackOption(
          code: uploadingCode,
          label: label.isNotEmpty ? label : uploadingCode.toUpperCase(),
        ),
      );
      addedCodes.add(uploadingCode);
    }

    return options;
  }

  /// Downloads video with the wanted language Audio Track.
  Future<void> downloadVideoWithWantedTrack({
    required BuildContext context,
    required Video video,
    required AudioTracksController tracksController,
    AudioTrackOption? track,
  }) async {
    final chosenTrack = track ?? selectedTrack.value;
    final langCode = chosenTrack?.code ?? video.language;
    final langLabel = chosenTrack?.label ?? tracksController.getLanguageName(langCode);

    final cleanTitle = StudioMediaDownloadService.getCleanTitle(video);

    try {
      isDownloading.value = true;
      await StudioMediaDownloadService.downloadDubbedVideo(
        video: video,
        langCode: langCode,
        langLabel: langLabel,
        cleanTitle: cleanTitle,
        track: chosenTrack,
        tracksController: tracksController,
      );
    } catch (e, s) {
      logger.error('Failed downloading video track', error: e, stackTrace: s, tag: _logTag);
      AppSnackbar.error('Unable to complete file download. Please try again.');
    } finally {
      isDownloading.value = false;
    }
  }

  @override
  void onClose() {
    _activeVideoId = '';
    super.onClose();
  }
}
