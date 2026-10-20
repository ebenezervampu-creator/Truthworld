import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/hover_preview_coordinator.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller_registry.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/home/presentation/controllers/home_feed_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:video_player/video_player.dart';

/// Pure GetX controller managing VideoCard state, hover playback, and navigation.
class VideoCardController extends GetxController implements HoverPreviewClient {
  VideoCardController({
    required this.video,
    this.disableHoverPreview = false,
    this.heroPrefix = 'video_card',
    this.customOnTap,
  });

  final Video video;
  @override
  final bool disableHoverPreview;
  final String heroPrefix;
  final VoidCallback? customOnTap;

  final RxBool _isHovered = false.obs;
  @override
  bool get isHovered => _isHovered.value;

  Timer? _hoverTimer;
  final Rxn<VideoPlayerController> _videoPlayerController =
      Rxn<VideoPlayerController>();
  VideoPlayerController? get activePlayer => _videoPlayerController.value;

  final RxBool isControllerInitialized = false.obs;
  final RxBool isLoadingVideo = false.obs;
  late final Worker _muteWorker;

  static final Map<String, Map<String, String>> _channelCache = {};
  final RxString realChannelAvatarUrl = ''.obs;
  final RxString realChannelName = ''.obs;

  bool _isDisposed = false;
  @override
  bool get isDisposed => _isDisposed;

  @override
  bool get hasActivePlayer => _videoPlayerController.value != null;

  @override
  void onInit() {
    super.onInit();
    final initialAvatar = video.channelAvatarUrl.isNotEmpty
        ? video.channelAvatarUrl
        : video.channelImage;
    if (initialAvatar.isNotEmpty) {
      realChannelAvatarUrl.value = initialAvatar;
    }
    realChannelName.value = video.channelName;
    loadRealChannelData();
    syncRealtimeViewsIfNeeded();

    _muteWorker = ever(HoverPreviewCoordinator.globalMute, (isMuted) {
      if (_videoPlayerController.value != null &&
          isControllerInitialized.value) {
        if (isMuted) {
          _videoPlayerController.value!.setVolume(0.0);
        } else {
          HoverPreviewCoordinator.pauseAllMainPlayers();
          _videoPlayerController.value!.setVolume(1.0);
        }
      }
    });
  }

  Future<void> loadRealChannelData() async {
    final effectiveChannelId = video.channelId.trim().isNotEmpty
        ? video.channelId.trim()
        : video.ownerId.trim();
    if (effectiveChannelId.isEmpty) return;

    if (realChannelAvatarUrl.value.isNotEmpty &&
        realChannelName.value.isNotEmpty) {
      return;
    }

    final cached = _channelCache[effectiveChannelId];
    if (cached != null) {
      if (cached['avatar']?.isNotEmpty ?? false) {
        realChannelAvatarUrl.value = cached['avatar']!;
      }
      if (cached['name']?.isNotEmpty ?? false) {
        realChannelName.value = cached['name']!;
      }
      if (realChannelAvatarUrl.value.isNotEmpty &&
          realChannelName.value.isNotEmpty) {
        return;
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(effectiveChannelId)
          .getCacheFirst();

      Map<String, dynamic>? data;
      if (doc.exists && doc.data() != null) {
        data = doc.data();
      } else {
        // Fallback: Query by ownerId if effectiveChannelId is a user UID
        final querySnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('ownerId', isEqualTo: effectiveChannelId)
            .limit(1)
            .getCacheFirst();
        if (querySnap.docs.isNotEmpty) {
          data = querySnap.docs.first.data();
        } else {
          // Fallback: Query users collection if the creator's avatar is in their user profile
          final userDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(effectiveChannelId)
              .getCacheFirst();
          if (userDoc.exists && userDoc.data() != null) {
            data = userDoc.data();
          }
        }
      }

      if (data != null) {
        final avatar = (data['avatarUrl'] as String?)?.trim().isNotEmpty == true
            ? (data['avatarUrl'] as String).trim()
            : (data['avatarImage'] as String?)?.trim().isNotEmpty == true
                ? (data['avatarImage'] as String).trim()
                : (data['channelAvatarUrl'] as String?)?.trim().isNotEmpty == true
                    ? (data['channelAvatarUrl'] as String).trim()
                    : (data['channelImage'] as String?)?.trim().isNotEmpty == true
                        ? (data['channelImage'] as String).trim()
                        : (data['photoUrl'] as String?)?.trim().isNotEmpty == true
                            ? (data['photoUrl'] as String).trim()
                            : (data['photoURL'] as String?)?.trim().isNotEmpty == true
                                ? (data['photoURL'] as String).trim()
                                : '';

        final name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : (data['channelName'] as String?)?.trim().isNotEmpty == true
                ? (data['channelName'] as String).trim()
                : (data['displayName'] as String?)?.trim().isNotEmpty == true
                    ? (data['displayName'] as String).trim()
                    : '';

        if (avatar.isNotEmpty) {
          realChannelAvatarUrl.value = avatar;
        }
        if (name.isNotEmpty) {
          realChannelName.value = name;
        }
        if (avatar.isNotEmpty || name.isNotEmpty) {
          _channelCache[effectiveChannelId] = {
            'avatar': avatar,
            'name': name,
          };
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoCardController.loadRealChannelData',
      );
    }
  }

  Future<void> syncRealtimeViewsIfNeeded() async {
    final videoId = video.id.trim();
    if (videoId.isEmpty) return;

    if (Get.isRegistered<MainController>()) {
      final live = MainController.to.videoViews[videoId];
      if (live != null && live > 0) return;
    }

    if (video.views == 0) {
      try {
        final counterService = Get.isRegistered<DistributedCounterService>()
            ? DistributedCounterService.to
            : Get.put(DistributedCounterService());
        final realtimeViews = await counterService.getRealtimeVideoViews(videoId);
        if (realtimeViews > 0) {
          if (Get.isRegistered<MainController>()) {
            MainController.to.videoViews[videoId] = realtimeViews;
          }
          unawaited(counterService.healParentVideoViews(videoId, realtimeViews));
          if (Get.isRegistered<HomeFeedController>()) {
            final updatedVideo = video.copyWith(viewCount: realtimeViews);
            Get.find<HomeFeedController>().updateVideo(updatedVideo);
          }
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'VideoCardController.syncRealtimeViewsIfNeeded',
        );
      }
    }
  }

  Future<void> initializePreviewPlayer() async {
    if (_videoPlayerController.value != null || isLoadingVideo.value) return;

    isLoadingVideo.value = true;
    var previewUrl = '';

    if (video.animatedPreviewUrl.isNotEmpty &&
        !video.animatedPreviewUrl.startsWith('gs://') &&
        (!kIsWeb || !video.animatedPreviewUrl.contains('.m3u8'))) {
      previewUrl = video.animatedPreviewUrl;
    }

    if (previewUrl.isEmpty && video.adaptiveResolutions.isNotEmpty) {
      final videoResolutions = video.adaptiveResolutions
          .where(
            (r) =>
                r.url.trim().isNotEmpty &&
                r.height > 0 &&
                !r.label.toLowerCase().contains('audio') &&
                !r.url.toLowerCase().contains('/audio') &&
                !r.url.toLowerCase().endsWith('original.mp4') &&
                !r.url.toLowerCase().contains('/original/') &&
                (!kIsWeb || !r.url.contains('.m3u8')),
          )
          .toList();
      if (videoResolutions.isNotEmpty) {
        final lowest = videoResolutions.reduce(
          (a, b) => a.bitrate < b.bitrate ? a : b,
        );
        previewUrl = lowest.url;
      }
    }

    if (previewUrl.isEmpty &&
        video.hlsUrl.isNotEmpty &&
        !video.hlsUrl.endsWith('original.mp4') &&
        !video.hlsUrl.contains('/original/')) {
      previewUrl = video.hlsUrl;
    }

    if (previewUrl.isEmpty) {
      isLoadingVideo.value = false;
      return;
    }

    previewUrl = await StorageUtils.resolveUrl(previewUrl);

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(previewUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController.value = controller;

      await controller.initialize();

      if (!_isDisposed &&
          _isHovered.value &&
          _videoPlayerController.value == controller) {
        HoverPreviewCoordinator.setActiveCard(this);
        final isMuted = HoverPreviewCoordinator.globalMute.value;
        if (!isMuted) {
          await controller.setVolume(1.0);
        } else {
          await controller.setVolume(0.0);
        }
        await controller.setLooping(true);
        await controller.play();
        isControllerInitialized.value = true;
        isLoadingVideo.value = false;
      } else {
        controller.dispose();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoCardController.initializePreviewPlayer',
      );
      if (!_isDisposed) {
        isLoadingVideo.value = false;
      }
    }
  }

  void disposePreviewPlayer() {
    if (_videoPlayerController.value != null) {
      final controller = _videoPlayerController.value;
      _videoPlayerController.value = null;
      isControllerInitialized.value = false;
      isLoadingVideo.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (controller?.value.isInitialized ?? false) {
            controller?.pause();
          }
          controller?.dispose();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'VideoCardController.disposePreviewPlayer',
          );
        }
      });
    }
  }

  @override
  void startHoverPlayback() {
    if (_isDisposed || disableHoverPreview) return;
    if (_isHovered.value && _videoPlayerController.value != null) return;
    _isHovered.value = true;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed && _isHovered.value) {
        initializePreviewPlayer();
      }
    });
  }

  void handleHoverEnter() {
    if (disableHoverPreview) return;
    HoverPreviewCoordinator.setActiveCard(this);
    startHoverPlayback();
  }

  @override
  void handleHoverExit() {
    if (disableHoverPreview) return;
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _isHovered.value = false;
    HoverPreviewCoordinator.clearActiveCard(this);
    disposePreviewPlayer();
  }

  void handleVisibilityChanged(double visibleFraction) {
    if (_isDisposed || disableHoverPreview) return;
    if (kIsWeb) return;
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return;

    HoverPreviewCoordinator.reportMobileVisibility(this, visibleFraction);
  }

  void handleTap(BuildContext context) {
    DeepLinkService.instance.cacheVideo(video);
    final controller = _videoPlayerController.value;
    Duration? resumePos;

    if (controller != null && isControllerInitialized.value) {
      final pos = controller.value.position;
      if (pos > Duration.zero) {
        resumePos = pos;
        VideoPlaybackHandoff.registerResumePosition(video.id, pos);
      }
      if (!kIsWeb) {
        VideoPlaybackHandoff.registerActiveController(
          video.id,
          controller,
          position: pos,
        );
      } else {
        try {
          controller.dispose();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'VideoCardController.handleTap.disposeWeb',
          );
        }
      }
      _videoPlayerController.value = null;
      isControllerInitialized.value = false;
      isLoadingVideo.value = false;
    } else {
      VideoPlaybackHandoff.prewarmVideo(video);
    }

    if (customOnTap != null) {
      customOnTap!();
    } else {
      MiniplayerNavigationHelper.navigateToVideoScreen(
        video: video,
        resumePosition: resumePos,
        routeArguments: {
          'video': video,
          'heroTag': '${heroPrefix}_${video.id}',
          'resumePosition': resumePos,
          'initialPosition': resumePos,
        },
      );
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    _muteWorker.dispose();
    _hoverTimer?.cancel();
    VideoCardControllerRegistry.unregisterTag('video_card_${video.id}_$heroPrefix');
    HoverPreviewCoordinator.unregisterCard(this);
    disposePreviewPlayer();
    super.onClose();
  }
}
