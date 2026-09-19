import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/data/datasources/local/database_helpers.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:universal_html/html.dart' as html;

/// Mixin handling offline playback loading and video/audio downloading.
mixin VideoOfflineDownloadMixin on GetxController {
  Video get video;
  RxBool get isAudioOnly;
  RxBool get rxIsLoading;
  RxBool get videoError;
  RxString get rxErrorMessage;
  RxList<VideoResolutionV2> get availableResolutions;
  Rx<VideoResolutionV2?> get currentResolution;
  RxBool get isDownloading;
  RxDouble get downloadProgress;
  String? get offlineBlobUrl;
  set offlineBlobUrl(String? value);
  RxList<Video> get recommendedVideos;

  Future<void> initializeVideoPlayer({String? overrideUrl});
  Future<void> fetchRecommendations();

  Future<void> initializeOfflinePlayback() async {
    rxIsLoading.value = true;
    try {
      final isAudio = isAudioOnly.value || (Get.arguments?['isAudioOnly'] == true);
      if (isAudio) {
        isAudioOnly.value = true;
      }

      // Sync isAudioOnly with TowerPlayerController
      if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
        Get.find<TowerPlayerController>(tag: video.id).isAudioOnly.value =
            isAudio;
      } else if (Get.isRegistered<TowerPlayerController>()) {
        Get.find<TowerPlayerController>().isAudioOnly.value = isAudio;
      }

      if (kIsWeb) {
        final bytes = await getVideoBytes(video.id);
        if (bytes == null || bytes.length < 512) {
          throw Exception('Offline media content not found or corrupted');
        }
        // Check for M3U8 text playlist header '#EXTM3U'
        if (bytes.length >= 7 &&
            bytes[0] == 0x23 && // '#'
            bytes[1] == 0x45 && // 'E'
            bytes[2] == 0x58 && // 'X'
            bytes[3] == 0x4D && // 'M'
            bytes[4] == 0x33 && // '3'
            bytes[5] == 0x55) { // 'U'
          throw Exception(
            'Downloaded file is an HLS playlist rather than direct media. Please re-download.',
          );
        }

        final mime = isAudio ? 'audio/mpeg' : 'video/mp4';
        final blob = html.Blob([bytes], mime);
        offlineBlobUrl = html.Url.createObjectUrl(blob);
      } else {
        final proxyUrl = await getOfflinePlaybackUrl(video.id);
        if (proxyUrl != null && proxyUrl.isNotEmpty) {
          offlineBlobUrl = proxyUrl;
        } else {
          final filePath = await getVideoFilePath(video.id);
          if (filePath != null &&
              File(filePath).existsSync() &&
              (await File(filePath).length()) > 512) {
            offlineBlobUrl = filePath;
          } else {
            throw Exception('Offline media content not found or corrupted');
          }
        }
      }

      // Create a dummy resolution for the UI
      availableResolutions.assignAll([
        VideoResolutionV2(
          label: isAudio ? 'Audio only' : 'Offline',
          url: offlineBlobUrl!,
          width: 0,
          height: 0,
          bitrate: 0,
        ),
      ]);
      currentResolution.value = availableResolutions.first;

      await initializeVideoPlayer(overrideUrl: offlineBlobUrl);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'VideoController.initOfflinePlayback',
      );
      videoError.value = true;
      final appException = AppException.from(e, stackTrace);
      rxErrorMessage.value = appException.displayMessage;
    } finally {
      rxIsLoading.value = false;
    }
  }

  void prefetchNextPage() {
    if (recommendedVideos.length < 50) {
      fetchRecommendations();
    }
  }

  Future<String> resolveDownloadableMediaUrl({required bool isAudioOnly}) async {
    // 1. If audio only, check audio tracks first (non-m3u8)
    if (isAudioOnly && video.audioTracks.isNotEmpty) {
      final track = video.audioTracks.values.firstWhere(
        (t) => t.isNotEmpty && !t.contains('.m3u8') && !t.contains('.mpd'),
        orElse: () => '',
      );
      if (track.isNotEmpty) return StorageUtils.getFastDownloadUrl(track);
    }

    // 2. Check availableResolutions for progressive MP4s
    if (availableResolutions.isNotEmpty) {
      final mp4Res = availableResolutions
          .where((r) =>
              r.url.isNotEmpty &&
              !r.url.contains('.m3u8') &&
              !r.url.contains('.mpd'))
          .toList();
      if (mp4Res.isNotEmpty) {
        if (isAudioOnly) {
          mp4Res.sort((a, b) => a.height.compareTo(b.height));
        } else {
          mp4Res.sort((a, b) => b.height.compareTo(a.height));
        }
        return StorageUtils.getFastDownloadUrl(mp4Res.first.url);
      }
    }

    // 3. Check video.adaptiveResolutions
    if (video.adaptiveResolutions.isNotEmpty) {
      final mp4Res = video.adaptiveResolutions
          .where((r) =>
              r.url.isNotEmpty &&
              !r.url.contains('.m3u8') &&
              !r.url.contains('.mpd'))
          .toList();
      if (mp4Res.isNotEmpty) {
        if (isAudioOnly) {
          mp4Res.sort((a, b) => a.height.compareTo(b.height));
        } else {
          mp4Res.sort((a, b) => b.height.compareTo(a.height));
        }
        return StorageUtils.getFastDownloadUrl(mp4Res.first.url);
      }
    }

    // 4. Check Firestore resolution_jobs variants
    try {
      final doc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(video.id)
          .getCacheFirst();
      if (doc.exists && doc.data() != null && doc.data()!['variants'] != null) {
        final variants = doc.data()!['variants'] as Map<String, dynamic>;
        for (final entry in variants.entries) {
          final vData = entry.value as Map<String, dynamic>;
          if (vData['status'] == 'completed') {
            final downloadUrl = vData['downloadUrl'] as String?;
            if (downloadUrl != null &&
                downloadUrl.isNotEmpty &&
                !downloadUrl.contains('.m3u8') &&
                !downloadUrl.contains('.mpd')) {
              return downloadUrl;
            }
            final outputPath = vData['outputPath'] as String?;
            if (outputPath != null &&
                outputPath.isNotEmpty &&
                !outputPath.contains('.m3u8') &&
                !outputPath.contains('.mpd')) {
              return StorageUtils.getFastDownloadUrl(outputPath);
            }
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoOfflineDownloadMixin.resolveDownloadUrl',
      );
    }

    // 5. Check video.originalUrl (if not m3u8/mpd)
    if (video.originalUrl.isNotEmpty &&
        !video.originalUrl.contains('.m3u8') &&
        !video.originalUrl.contains('.mpd')) {
      return StorageUtils.getFastDownloadUrl(video.originalUrl);
    }

    // 6. Check video.videoUrl (if not m3u8/mpd)
    if (video.videoUrl.isNotEmpty &&
        !video.videoUrl.contains('.m3u8') &&
        !video.videoUrl.contains('.mpd')) {
      return StorageUtils.getFastDownloadUrl(video.videoUrl);
    }

    return '';
  }

  bool validateDownloadSettings() {
    if (!Get.isRegistered<UserSettingsController>()) return true;
    final dl = UserSettingsController.to.downloads.value;

    if (dl.wifiOnly) {
      final isWifi = !Get.isRegistered<ConnectivityService>() ||
          ConnectivityService.to.isWifi;
      if (!isWifi) {
        AppSnackbar.warning(
          'Downloads are restricted to Wi-Fi connections in Settings.',
          title: 'Wi-Fi Required',
        );
        return false;
      }
    }

    return true;
  }

  Future<void> saveAudioOffline() async {
    if (isDownloading.value) {
      AppSnackbar.info(
        'Download is already in progress.',
        title: 'Download in Progress',
      );
      return;
    }

    final downloadsCtrl = Get.isRegistered<DownloadsController>()
        ? Get.find<DownloadsController>()
        : Get.put(DownloadsController());

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      final success = await downloadsCtrl.downloadAudioOffline(
        video: video,
        onProgress: (p) => downloadProgress.value = p,
      );
      if (success) {
        await downloadsCtrl.loadVideos();
      }
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }

  Future<void> saveVideoOffline(
    VideoResolutionV2 resolution, {
    bool isAudioOnly = false,
  }) async {
    if (isAudioOnly) {
      return saveAudioOffline();
    }

    if (isDownloading.value) {
      AppSnackbar.info(
        'Video download is already in progress.',
        title: 'Download in Progress',
      );
      return;
    }

    final downloadsCtrl = Get.isRegistered<DownloadsController>()
        ? Get.find<DownloadsController>()
        : Get.put(DownloadsController());

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      final success = await downloadsCtrl.downloadVideoOffline(
        video: video,
        resolution: resolution,
        onProgress: (p) => downloadProgress.value = p,
      );
      if (success) {
        await downloadsCtrl.loadVideos();
      }
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }
}
