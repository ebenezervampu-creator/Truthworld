import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A video player widget that wraps raw [VideoPlayer] but automatically uses
/// [Chewie] on Android and iOS devices, and for Android users on web.
class MobileFriendlyVideoPlayer extends StatefulWidget {
  const MobileFriendlyVideoPlayer({
    required this.controller,
    super.key,
    this.showControls = false,
    this.autoPlay = false,
    this.looping = false,
  });
  final VideoPlayerController controller;
  final bool showControls;
  final bool autoPlay;
  final bool looping;

  @override
  State<MobileFriendlyVideoPlayer> createState() =>
      _MobileFriendlyVideoPlayerState();
}

class _MobileFriendlyVideoPlayerState extends State<MobileFriendlyVideoPlayer> {
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.showControls) {
      _initChewie();
    }
  }

  void _initChewie() {
    _chewieController = ChewieController(
      videoPlayerController: widget.controller,
      autoPlay: widget.autoPlay,
      looping: widget.looping,
      allowedScreenSleep: false,
    );
  }

  @override
  void didUpdateWidget(MobileFriendlyVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showControls && oldWidget.controller != widget.controller) {
      _chewieController?.dispose();
      _initChewie();
    }
  }

  @override
  void dispose() {
    if (widget.showControls) {
      _chewieController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showControls && _chewieController != null) {
      return Chewie(controller: _chewieController!);
    }
    return VideoPlayer(widget.controller);
  }
}
