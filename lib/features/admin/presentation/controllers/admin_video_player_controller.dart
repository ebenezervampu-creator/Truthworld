import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Controller for managing video playback inside Admin Dashboard view
class AdminVideoPlayerController extends BaseController {
  AdminVideoPlayerController(this.url, {this.videoData});
  final String url;
  final Map<String, dynamic>? videoData;

  VideoPlayerController? videoCtrl;
  ChewieController? chewieCtrl;
  final RxBool isPlayerInitialized = false.obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(_initPlayer());
  }

  void retry() {
    unawaited(_initPlayer());
  }

  Future<void> _initPlayer() async {
    try {
      isPlayerInitialized.value = false;
      error.value = null;

      // Clean up any old controllers first
      _safeDisposeControllers();

      final candidateUrls = _extractCandidateUrls();
      if (candidateUrls.isEmpty) {
        error.value = 'No valid video URL found for playback.';
        return;
      }

      final resolvedCandidates = <String>[];
      for (final raw in candidateUrls) {
        final res = await _resolveUrl(raw);
        if (res != null && res.isNotEmpty && !resolvedCandidates.contains(res)) {
          resolvedCandidates.add(res);
        }
      }

      if (resolvedCandidates.isEmpty) {
        error.value = 'Unable to resolve video playback URL.';
        return;
      }

      // On Web, standard browser <video> doesn't support HLS (.m3u8) without special extensions.
      // Prioritize non-.m3u8 (direct MP4) URLs on Web.
      if (kIsWeb) {
        resolvedCandidates.sort((a, b) {
          final aIsM3u8 = a.contains('.m3u8');
          final bIsM3u8 = b.contains('.m3u8');
          if (aIsM3u8 && !bIsM3u8) return 1;
          if (!aIsM3u8 && bIsM3u8) return -1;
          return 0;
        });
      }

      VideoPlayerController? initializedCtrl;

      for (final targetUrl in resolvedCandidates) {
        try {
          debugPrint('[AdminVideoPlayerController] Attempting init for: $targetUrl');
          final ctrl = VideoPlayerController.networkUrl(
            Uri.parse(targetUrl),
            httpHeaders: const {
              'Connection': 'keep-alive',
              'Accept': '*/*',
            },
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await ctrl.initialize();
          initializedCtrl = ctrl;
          debugPrint('[AdminVideoPlayerController] Successfully initialized: $targetUrl');
          break;
        } catch (e) {
          debugPrint('[AdminVideoPlayerController] Failed init candidate ($targetUrl): $e');
        }
      }

      if (initializedCtrl == null) {
        error.value = 'Error loading video player: Format error or unsupported stream source.';
        return;
      }

      videoCtrl = initializedCtrl;
      chewieCtrl = ChewieController(
        videoPlayerController: initializedCtrl,
        aspectRatio: initializedCtrl.value.isInitialized && initializedCtrl.value.aspectRatio > 0
            ? initializedCtrl.value.aspectRatio
            : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.brand,
          handleColor: AppColors.brand,
          bufferedColor: AppColors.progressBuffered,
          backgroundColor: AppColors.progressTrack,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Video error: $errorMessage',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      );

      isPlayerInitialized.value = true;
    } catch (e) {
      debugPrint('[AdminVideoPlayerController] General init error: $e');
      error.value = 'Error loading video player: $e';
    }
  }

  List<String> _extractCandidateUrls() {
    final candidates = <String>[];
    if (url.trim().isNotEmpty) {
      candidates.add(url.trim());
    }
    if (videoData != null) {
      for (final key in ['originalUrl', 'videoUrl', 'mediaUrl', 'url', 'hlsUrl', 'dashUrl']) {
        final val = videoData![key];
        if (val is String && val.trim().isNotEmpty && !candidates.contains(val.trim())) {
          candidates.add(val.trim());
        }
      }
      if (videoData!['adaptiveResolutions'] is List) {
        for (final res in (videoData!['adaptiveResolutions'] as List)) {
          if (res is Map && res['url'] is String && (res['url'] as String).trim().isNotEmpty) {
            final u = (res['url'] as String).trim();
            if (!candidates.contains(u)) candidates.add(u);
          }
        }
      }
    }
    return candidates;
  }

  Future<String?> _resolveUrl(String candidate) async {
    final clean = candidate.trim();
    if (clean.isEmpty) return null;

    if (clean.startsWith('gs://')) {
      try {
        final fastUrl = StorageUtils.getFastDownloadUrl(clean);
        if (fastUrl.startsWith('http')) return fastUrl;
      } catch (_) {}
      try {
        return await FirebaseStorage.instance.refFromURL(clean).getDownloadURL();
      } catch (_) {
        return null;
      }
    }

    if (clean.contains('firebasestorage.googleapis.com') && !clean.contains('alt=media')) {
      return StorageUtils.getFastDownloadUrl(clean);
    }

    if (!clean.startsWith('http://') && !clean.startsWith('https://') && !clean.startsWith('blob:') && !clean.startsWith('data:')) {
      try {
        return StorageUtils.getFastDownloadUrl(clean);
      } catch (_) {
        return null;
      }
    }

    return clean;
  }

  void _safeDisposeControllers() {
    if (chewieCtrl != null) {
      try {
        chewieCtrl!.pause();
      } catch (_) {}
      try {
        chewieCtrl!.dispose();
      } catch (_) {}
      chewieCtrl = null;
    }
    if (videoCtrl != null) {
      try {
        videoCtrl!.pause();
      } catch (_) {}
      try {
        videoCtrl!.dispose();
      } catch (_) {}
      videoCtrl = null;
    }
  }

  @override
  void onClose() {
    _safeDisposeControllers();
    super.onClose();
  }
}

