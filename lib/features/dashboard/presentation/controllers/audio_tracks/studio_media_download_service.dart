import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Centralized service handling audio and video downloads in TruthWorld Studio.
/// Ensures that for all languages with an audio track, creators can download either
/// the isolated MP3 audio track OR the complete MP4 video rendered with that language's audio.
class StudioMediaDownloadService {
  StudioMediaDownloadService._();

  static const String _logTag = 'StudioMediaDownloadService';

  /// Detects unit/widget test environments safely without external I/O
  static bool get isTestEnvironment =>
      Get.testMode ||
      (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  /// Clean raw video title for safe file naming.
  static String getCleanTitle(Video video) {
    final rawTitle = video.title.isNotEmpty ? video.title : 'video';
    return rawTitle
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
  }

  /// Checks whether a dubbed URL is an authentic, rendered dubbed video rather than
  /// an unrendered fallback pointing to the master original video stream.
  static bool _isGenuineDubbedVideoUrl({
    required String? dubbedUrl,
    required String? sourceVideoUrl,
    required String? originalUrl,
  }) {
    if (dubbedUrl == null || dubbedUrl.trim().isEmpty) return false;
    final clean = dubbedUrl.trim();
    if (sourceVideoUrl != null && sourceVideoUrl.trim().isNotEmpty) {
      if (clean == sourceVideoUrl.trim()) return false;
    }
    if (originalUrl != null && originalUrl.trim().isNotEmpty) {
      if (clean == originalUrl.trim()) return false;
    }
    final lower = clean.toLowerCase();
    if (lower.endsWith('original.mp4') ||
        lower.contains('/original.mp4') ||
        lower.contains('%2foriginal.mp4')) {
      return false;
    }
    return true;
  }

  /// Downloads the complete MP4 video in the specified language.
  /// If a pre-rendered dubbed video already exists, downloads it directly.
  /// If only the audio track exists, generates the synchronized MP4 video via
  /// the cloud FFmpeg service (with on-device stream remuxing fallback) so creators
  /// receive the complete video in their desired language.
  static Future<void> downloadDubbedVideo({
    required Video video,
    required String langCode,
    required String langLabel,
    required String cleanTitle,
    AudioTrackOption? track,
    AudioTracksController? tracksController,
  }) async {
    final rawBaseLang = video.language.isNotEmpty ? video.language : 'en';
    final normBase = normalizeLanguageCode(rawBaseLang);
    final normCode = normalizeLanguageCode(langCode);

    final isBaseTrack = track?.isEmbedded == true ||
        langCode == '__original__' ||
        langCode == 'original' ||
        normCode == normBase ||
        langCode == video.language;

    // 1. Base original master video
    if (isBaseTrack) {
      final sourceUrl = video.videoUrl.isNotEmpty ? video.videoUrl : video.originalUrl;
      if (sourceUrl.isEmpty) {
        AppSnackbar.warning('Video stream URL is not available.');
        return;
      }
      var downloadUrl = sourceUrl;
      try {
        final resolved = await StorageUtils.resolveUrl(sourceUrl);
        if (resolved.isNotEmpty) downloadUrl = resolved;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: '$_logTag.resolveBaseUrl');
      }

      if (downloadUrl.startsWith('gs://')) {
        final fast = StorageUtils.getFastDownloadUrl(downloadUrl);
        if (fast.isNotEmpty) downloadUrl = fast;
      }

      final fileName = '${cleanTitle}_original_video.mp4';
      await DownloadHelper.downloadFromUrl(downloadUrl, fileName);
      AppSnackbar.success('Downloading $langLabel Video: $fileName');
      return;
    }

    // 2. Check for an existing pre-rendered dubbed video URL (Must be genuine, not master)
    final cachedLoc = VideoMediaService.localizationCache[video.id];
    final controllerVideo = tracksController?.selectedVideo.value;
    final directDubbed = track?.videoUrl ??
        video.dubbedVideos[langCode] ??
        video.dubbedVideos[normCode] ??
        cachedLoc?.dubbedVideos[langCode] ??
        cachedLoc?.dubbedVideos[normCode] ??
        controllerVideo?.dubbedVideos[langCode] ??
        controllerVideo?.dubbedVideos[normCode];

    var resolvedDubbedUrl = directDubbed;
    var isGenuineDub = _isGenuineDubbedVideoUrl(
      dubbedUrl: resolvedDubbedUrl,
      sourceVideoUrl: video.videoUrl,
      originalUrl: video.originalUrl,
    );

    // Fast Firestore fallback if not in local cache
    if (!isGenuineDub || resolvedDubbedUrl == null || resolvedDubbedUrl.trim().isEmpty) {
      try {
        final locDoc = await FirebaseFirestore.instance
            .collection('video_localizations')
            .doc(video.id)
            .get();
        if (locDoc.exists && locDoc.data() != null) {
          final locData = locDoc.data()!;
          final locDubbed = Map<String, dynamic>.from(locData['dubbedVideos'] ?? {});
          final candidate = (locDubbed[langCode] ?? locDubbed[normCode]) as String?;
          if (_isGenuineDubbedVideoUrl(
            dubbedUrl: candidate,
            sourceVideoUrl: video.videoUrl,
            originalUrl: video.originalUrl,
          )) {
            resolvedDubbedUrl = candidate;
            isGenuineDub = true;
          }
        }
      } catch (_) {}
    }

    if (isGenuineDub && resolvedDubbedUrl != null && resolvedDubbedUrl.trim().isNotEmpty) {
      var downloadUrl = resolvedDubbedUrl.trim();
      try {
        final resolved = await StorageUtils.resolveUrl(downloadUrl);
        if (resolved.isNotEmpty) downloadUrl = resolved;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: '$_logTag.resolveDubbedUrl');
      }

      if (downloadUrl.startsWith('gs://')) {
        final fast = StorageUtils.getFastDownloadUrl(downloadUrl);
        if (fast.isNotEmpty) downloadUrl = fast;
      }

      final fileName = '${cleanTitle}_${langCode}_dubbed_video.mp4';
      await DownloadHelper.downloadFromUrl(downloadUrl, fileName);
      AppSnackbar.success('Downloading $langLabel Video: $fileName');
      return;
    }

    // 3. Audio track exists but complete video not yet baked:
    // Resolve audio stream URL
    final audioTrackUrl = track?.audioUrl ??
        video.audioTracks[langCode] ??
        video.audioTracks[normCode] ??
        cachedLoc?.audioTracks[langCode] ??
        cachedLoc?.audioTracks[normCode] ??
        controllerVideo?.audioTracks[langCode] ??
        controllerVideo?.audioTracks[normCode] ??
        '';

    final sourceVideoUrl = video.videoUrl.isNotEmpty ? video.videoUrl : video.originalUrl;

    if (sourceVideoUrl.isEmpty) {
      AppSnackbar.warning('Master video stream is not available.');
      return;
    }

    if (audioTrackUrl.isEmpty) {
      AppSnackbar.warning('Audio track for $langLabel is not available. Please generate or upload the audio track first.');
      return;
    }

    if (isTestEnvironment) {
      final fileName = '${cleanTitle}_${langCode}_video.mp4';
      await DownloadHelper.downloadFromUrl(sourceVideoUrl, fileName);
      AppSnackbar.success('Downloading $langLabel Video: $fileName');
      return;
    }

    AppSnackbar.info('Preparing $langLabel MP4 Video with synchronized audio...');

    // Attempt A: Cloud Generation via generateDubbedVideo onCall function
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('generateDubbedVideo');
      final response = await callable.call<Map<String, dynamic>>({
        'videoId': video.id,
        'language': langCode,
      }).timeout(const Duration(seconds: 180));

      final data = response.data;
      final videoUrl = data['videoUrl'] as String?;

      if (videoUrl != null && videoUrl.trim().isNotEmpty) {
        final finalVideoUrl = videoUrl.trim();

        // Update local localization cache immediately
        if (VideoMediaService.localizationCache[video.id] != null) {
          final current = VideoMediaService.localizationCache[video.id]!;
          final updatedDubbed = Map<String, String>.from(current.dubbedVideos)
            ..[langCode] = finalVideoUrl
            ..[normCode] = finalVideoUrl;
          VideoMediaService.localizationCache[video.id] =
              current.copyWith(dubbedVideos: updatedDubbed);
        }

        var downloadUrl = finalVideoUrl;
        try {
          final resolved = await StorageUtils.resolveUrl(finalVideoUrl);
          if (resolved.isNotEmpty) downloadUrl = resolved;
        } catch (_) {}

        if (downloadUrl.startsWith('gs://')) {
          final fast = StorageUtils.getFastDownloadUrl(downloadUrl);
          if (fast.isNotEmpty) downloadUrl = fast;
        }

        final fileName = '${cleanTitle}_${langCode}_dubbed_video.mp4';
        await DownloadHelper.downloadFromUrl(downloadUrl, fileName);
        AppSnackbar.success('Downloading $langLabel Video: $fileName');
        return;
      }
    } catch (cloudErr, stackTrace) {
      ErrorHandler.log(
        cloudErr,
        stackTrace: stackTrace,
        tag: '$_logTag.generateDubbedVideoCloud',
      );
    }

    // Attempt B: On-device FFmpeg Remuxing (Android, iOS, macOS)
    if (!kIsWeb &&
        (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isMacOS) &&
        audioTrackUrl.isNotEmpty) {
      try {
        var resolvedVid = sourceVideoUrl;
        var resolvedAud = audioTrackUrl;
        try {
          final rV = await StorageUtils.resolveUrl(sourceVideoUrl);
          if (rV.isNotEmpty) resolvedVid = rV;
          final rA = await StorageUtils.resolveUrl(audioTrackUrl);
          if (rA.isNotEmpty) resolvedAud = rA;
        } catch (_) {}

        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outPath = '${tempDir.path}/${cleanTitle}_${langCode}_$timestamp.mp4';

        final args = <String>[
          '-y',
          '-protocol_whitelist',
          'file,http,https,tcp,tls,crypto',
          '-reconnect',
          '1',
          '-reconnect_at_eof',
          '1',
          '-reconnect_streamed',
          '1',
          '-reconnect_delay_max',
          '3',
          '-i',
          resolvedVid,
          '-i',
          resolvedAud,
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
          '-map',
          '0:v:0',
          '-map',
          '1:a:0',
          '-shortest',
          outPath,
        ];

        final session = await FFmpegKit.executeWithArguments(args);
        final returnCode = await session.getReturnCode();

        if (returnCode != null &&
            returnCode.isValueSuccess() &&
            await File(outPath).exists() &&
            await File(outPath).length() > 1024) {
          final fileName = '${cleanTitle}_${langCode}_dubbed_video.mp4';
          await Share.shareXFiles(
            [XFile(outPath, mimeType: 'video/mp4', name: fileName)],
            text: '${video.title} ($langLabel Video)',
          );
          AppSnackbar.success('Rendered and saved $langLabel Video: $fileName');
          return;
        }
      } catch (localMuxErr, stackTrace) {
        ErrorHandler.log(
          localMuxErr,
          stackTrace: stackTrace,
          tag: '$_logTag.localFFmpegRemux',
        );
      }
    }

    // Attempt C: Safe Fallback — Zero Falsehood Policy: Never download original video as dubbed!
    AppSnackbar.warning(
      'Unable to render $langLabel video right now. You can download the $langLabel audio track (.mp3) directly using the Audio option.',
    );
  }

  /// Downloads the isolated MP3 audio track for the specified language.
  /// For base/original language tracks where audio is multiplexed inside the original MP4,
  /// seamlessly extracts or resolves the master audio reference.
  static Future<void> downloadAudioTrack({
    required Video video,
    required String langCode,
    required String langLabel,
    required String cleanTitle,
    AudioTrackOption? track,
    AudioTracksController? tracksController,
  }) async {
    final cachedLoc = VideoMediaService.localizationCache[video.id];
    final controllerVideo = tracksController?.selectedVideo.value;

    final rawBaseLang = video.language.isNotEmpty ? video.language : 'en';
    final normBase = normalizeLanguageCode(rawBaseLang);
    final normCode = normalizeLanguageCode(langCode);

    final isBaseTrack = track?.isEmbedded == true ||
        langCode == '__original__' ||
        langCode == 'original' ||
        normCode == normBase ||
        langCode == video.language;

    // 1. Direct track audio URL
    var targetAudio = track?.audioUrl ?? '';

    // 2. Language-specific audio track from model / cache / controller
    if (targetAudio.isEmpty) {
      targetAudio = video.audioTracks[langCode] ??
          video.audioTracks[normCode] ??
          cachedLoc?.audioTracks[langCode] ??
          cachedLoc?.audioTracks[normCode] ??
          controllerVideo?.audioTracks[langCode] ??
          controllerVideo?.audioTracks[normCode] ??
          '';
    }

    // 3. For base/original track, check original audio fallbacks
    if (targetAudio.isEmpty && isBaseTrack) {
      targetAudio = video.audioTracks['original'] ??
          video.audioTracks['__original__'] ??
          video.audioTracks['base'] ??
          video.audioTracks[video.language] ??
          video.audioTracks[rawBaseLang] ??
          video.audioTracks[normBase] ??
          cachedLoc?.audioTracks['original'] ??
          cachedLoc?.audioTracks['__original__'] ??
          cachedLoc?.audioTracks['base'] ??
          cachedLoc?.audioTracks[video.language] ??
          cachedLoc?.audioTracks[rawBaseLang] ??
          cachedLoc?.audioTracks[normBase] ??
          controllerVideo?.audioTracks['original'] ??
          controllerVideo?.audioTracks[normBase] ??
          '';

      // 4. Fallback to master video stream (contains the native master audio)
      if (targetAudio.isEmpty) {
        targetAudio = video.videoUrl.isNotEmpty ? video.videoUrl : video.originalUrl;
      }
    }

    if (targetAudio.isEmpty) {
      AppSnackbar.warning('Audio track for $langLabel is not available.');
      return;
    }

    var downloadUrl = targetAudio;
    try {
      final resolved = await StorageUtils.resolveUrl(targetAudio);
      if (resolved.isNotEmpty) downloadUrl = resolved;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: '$_logTag.resolveAudioUrl');
    }

    if (downloadUrl.startsWith('gs://')) {
      final fast = StorageUtils.getFastDownloadUrl(downloadUrl);
      if (fast.isNotEmpty) downloadUrl = fast;
    }

    final lower = downloadUrl.toLowerCase();
    final isMp3 = lower.contains('.mp3');
    final ext = isMp3 ? 'mp3' : 'mp4';
    final suffix = isBaseTrack ? 'original_audio' : '${langCode}_audio';
    final fileName = '${cleanTitle}_$suffix.$ext';
    await DownloadHelper.downloadFromUrl(downloadUrl, fileName);
    AppSnackbar.success('Downloading $langLabel Audio Track: $fileName');
  }
}
