import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io' show Platform;
import 'package:get/get.dart';

/// A video player widget that wraps raw [VideoPlayer] but automatically uses
/// [Chewie] on Android and iOS devices, conforming to platform requirements.
class MobileFriendlyVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final bool showControls;
  final bool autoPlay;
  final bool looping;

  const MobileFriendlyVideoPlayer({
    super.key,
    required this.controller,
    this.showControls = false,
    this.autoPlay = false,
    this.looping = false,
  });

  @override
  State<MobileFriendlyVideoPlayer> createState() => _MobileFriendlyVideoPlayerState();
}

class _MobileFriendlyVideoPlayerState extends State<MobileFriendlyVideoPlayer> {
  final Rxn<ChewieController> _chewieController = Rxn<ChewieController>();

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(MobileFriendlyVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _cleanupListener(oldWidget.controller);
      _chewieController.value?.dispose();
      _chewieController.value = null;
      _initPlayer();
    }
  }

  void _initPlayer() {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile) {
      _chewieController.value = ChewieController(
        videoPlayerController: widget.controller,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        showControls: widget.showControls,
        allowedScreenSleep: false,
        aspectRatio: widget.controller.value.isInitialized 
            ? widget.controller.value.aspectRatio 
            : null,
      );
      if (!widget.controller.value.isInitialized) {
        widget.controller.addListener(_onControllerInitialized);
      }
    }
  }

  void _onControllerInitialized() {
    if (widget.controller.value.isInitialized) {
      widget.controller.removeListener(_onControllerInitialized);
      final old = _chewieController.value;
      _chewieController.value = ChewieController(
        videoPlayerController: widget.controller,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        showControls: widget.showControls,
        allowedScreenSleep: false,
        aspectRatio: widget.controller.value.aspectRatio,
      );
      old?.dispose();
    }
  }

  void _cleanupListener(VideoPlayerController controller) {
    try {
      controller.removeListener(_onControllerInitialized);
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanupListener(widget.controller);
    _chewieController.value?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return Obx(() {
      final chewie = _chewieController.value;
      if (isMobile && chewie != null) {
        return Chewie(controller: chewie);
      }
      return VideoPlayer(widget.controller);
    });
  }
}
