import 'dart:io' show Platform;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

/// A video player widget that wraps raw [VideoPlayer] but automatically uses
/// [Chewie] on Android and iOS devices, and for Android users on web.
class MobileFriendlyVideoPlayer extends StatefulWidget {

  const MobileFriendlyVideoPlayer({
    required this.controller, super.key,
    this.showControls = false,
    this.autoPlay = false,
    this.looping = false,
  });
  final VideoPlayerController controller;
  final bool showControls;
  final bool autoPlay;
  final bool looping;

  @override
  State<MobileFriendlyVideoPlayer> createState() => _MobileFriendlyVideoPlayerState();
}

/// Detects if the current user is on mobile web (Android, iPhone, iPad, iPod)
bool _isMobileWebUser() {
  if (!kIsWeb) {
    return Platform.isAndroid || Platform.isIOS;
  }
  
  // On web, check user agent for mobile operating systems
  try {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('android') || 
           userAgent.contains('iphone') || 
           userAgent.contains('ipad') || 
           userAgent.contains('ipod') ||
           (userAgent.contains('macintosh') && html.window.navigator.maxTouchPoints != null && html.window.navigator.maxTouchPoints! > 0);
  } catch (_) {
    return false;
  }
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
    final isMobileOnWeb = kIsWeb && _isMobileWebUser();
    
    // Use Chewie for mobile devices and mobile users on web
    if (isMobile || isMobileOnWeb) {
      _chewieController.value = ChewieController(
        videoPlayerController: widget.controller,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        showControls: widget.showControls,
        allowedScreenSleep: false,
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
    final isMobileOnWeb = kIsWeb && _isMobileWebUser();
    
    return Obx(() {
      final chewie = _chewieController.value;
      if ((isMobile || isMobileOnWeb) && chewie != null) {
        return Chewie(controller: chewie);
      }
      return VideoPlayer(widget.controller);
    });
  }
}
