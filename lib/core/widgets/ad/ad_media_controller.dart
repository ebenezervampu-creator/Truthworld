import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:video_player/video_player.dart';

/// GetX controller managing media playback lifecycle, hover auto-play timer,
/// mute states, and storage URL resolution for native ad cards.
class AdMediaController extends GetxController {
  final Rxn<VideoPlayerController> videoController = Rxn<VideoPlayerController>();
  Timer? _hoverTimer;
  final RxBool isMuted = true.obs;
  final RxBool isInitialized = false.obs;
  final RxBool isLoading = false.obs;

  String? _currentAdId;
  String? _currentVideoUrl;

  void onAdHoverChanged({
    required AdItem ad,
    required bool isHovered,
  }) {
    final effectiveUrl = ad.effectiveVideoUrl;
    if (_currentAdId != ad.id || _currentVideoUrl != effectiveUrl) {
      _currentAdId = ad.id;
      _currentVideoUrl = effectiveUrl;
      cancelAndDispose();
      if (isHovered) {
        startHoverTimer(ad);
      }
    } else {
      if (isHovered) {
        startHoverTimer(ad);
      } else {
        cancelAndDispose();
      }
    }
  }

  void startHoverTimer(AdItem ad) {
    final url = ad.effectiveVideoUrl;
    if (url == null || url.isEmpty) return;

    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 500), () {
      initializeVideo(ad);
    });
  }

  void cancelAndDispose() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    final ctrl = videoController.value;
    videoController.value = null;
    isInitialized.value = false;
    isLoading.value = false;
    if (ctrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (ctrl.value.isInitialized) {
            ctrl.pause();
          }
          ctrl.dispose();
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'AdMediaController.disposeVideo',
          );
        }
      });
    }
  }

  Future<void> initializeVideo(AdItem ad) async {
    final rawUrl = ad.effectiveVideoUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      isInitialized.value = false;
      isLoading.value = false;
      return;
    }

    if (videoController.value != null || isLoading.value) return;
    isLoading.value = true;

    var playUrl = rawUrl;
    if (playUrl.startsWith('gs://') ||
        playUrl.startsWith('https://storage.googleapis.com/') ||
        (playUrl.contains('firebasestorage.googleapis.com') &&
            !playUrl.contains('token='))) {
      try {
        playUrl = await FirebaseStorage.instance
            .refFromURL(playUrl)
            .getDownloadURL();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AdMediaController.resolveStorageUrl',
        );
        final fallback = StorageUtils.getFastDownloadUrl(playUrl);
        if (fallback.isNotEmpty && fallback != playUrl) {
          playUrl = fallback;
        }
      }
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      videoController.value = controller;

      await controller.initialize();

      if (videoController.value == controller) {
        await controller.setVolume(isMuted.value ? 0.0 : 1.0);
        await controller.setLooping(true);
        await controller.play();
        isInitialized.value = true;
        isLoading.value = false;
      } else {
        await controller.dispose();
        if (videoController.value == controller) {
          videoController.value = null;
        }
        isLoading.value = false;
        isInitialized.value = false;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AdMediaController.initializeVideo',
      );
      isLoading.value = false;
      isInitialized.value = false;
    }
  }

  void toggleMute() {
    final nextMuted = !isMuted.value;
    isMuted.value = nextMuted;
    if (!nextMuted) {
      HoverPreviewCoordinator.pauseAllMainPlayers();
      videoController.value?.setVolume(1.0);
    } else {
      videoController.value?.setVolume(0.0);
    }
  }

  @override
  void onClose() {
    cancelAndDispose();
    super.onClose();
  }
}
