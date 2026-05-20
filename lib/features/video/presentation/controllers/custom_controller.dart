import 'dart:async';
import 'package:truthworld/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/presentation/widgets/full_screen_helper.dart';
import 'package:video_player/video_player.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class CustomController extends GetxController {
  VideoPlayerController? videoPlayerController;
  var isPlaying = false.obs;
  var isMuted = false.obs;
  var isLooping = false.obs;
  var isFullScreen = false.obs;
  var isInitialized = false.obs;
  var isBuffering = false.obs;
  var errorMessage = ''.obs;
  var duration = Duration.zero.obs;
  var position = Duration.zero.obs;
  var volume = 1.0.obs;
  var videoQuality = 'Auto'.obs;
  var showControls = true.obs;
  Timer? _hideControlsTimer;
  Timer? _singleTapTimer;
  DateTime? _lastTapDownTime;
  static const speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  var playbackSpeed = 1.0.obs;

  var showRewindOverlay = false.obs;
  var showForwardOverlay = false.obs;
  var showCenterOverlay = false.obs;
  var centerOverlayIcon = Icons.play_arrow.obs;

  // Sample quality-to-URL mapping for HLS (replace with actual URLs)
  /// Stores dynamically fetched resolution URLs from Firestore
  Map<String, String> _qualityUrls = {};
  List<String> availableQualities = ['Auto']; // updated when Firestore loads

  Future<void> loadVideoResolutions(String videoId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();
      if (!doc.exists) {
        errorMessage.value = 'Video not found in Firestore';
        return;
      }

      final List<dynamic>? resolutions =
          doc.data()?['resolutions'] as List<dynamic>?;
      if (resolutions == null || resolutions.isEmpty) {
        errorMessage.value = 'No resolutions found';
        return;
      }

      final Map<String, String> urls = {};

      // defaultStorage = FirebaseStorage.instance (uses default bucket)
      final storage = FirebaseStorage.instance;

      for (final res in resolutions) {
        if (res is! Map) continue;
        final quality = (res['quality'] ?? 'unknown').toString();
        var path = (res['path'] ?? '').toString();
        if (path.isEmpty) continue;

        try {
          // Normalize path: remove leading '/' if present
          if (path.startsWith('/')) path = path.substring(1);

          // Try direct child ref first (common)
          String url;
          try {
            final ref = storage.ref().child(path);
            url = await ref.getDownloadURL();
          } catch (_) {
            // Try refFromURL if the path actually contains a full gs:// or https://
            if (path.startsWith('gs://') || path.startsWith('https://')) {
              final ref = storage.refFromURL(path);
              url = await ref.getDownloadURL();
            } else {
              rethrow;
            }
          }

          urls[quality] = url;
        } catch (e) {
          debugPrint('Could not get download URL for $path : $e');
          // continue; failing one resolution should not block others
        }
      }

      _qualityUrls = urls;
      // ensure deterministic ordering: Auto + sorted by bitrate/quality string
      availableQualities = ['Auto', ..._qualityUrls.keys];
      debugPrint('✅ Loaded qualities: $availableQualities');
    } catch (e) {
      debugPrint('Error loading video resolutions: $e');
      errorMessage.value = 'Failed to load video qualities';
    }
  }

  /// Measures approximate download speed by fetching video headers
  Future<double> _estimateNetworkSpeedMbps(String testUrl) async {
    try {
      final stopwatch = Stopwatch()..start();
      final request = await html.HttpRequest.request(testUrl, method: 'HEAD');
      stopwatch.stop();

      // estimate content length and time
      final contentLength =
          int.tryParse(request.getResponseHeader('content-length') ?? '0') ?? 0;
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds == 0) return 0.0;

      final bits = contentLength * 8;
      final mbps = (bits / seconds) / 1e6;
      debugPrint('🌐 Estimated speed: ${mbps.toStringAsFixed(2)} Mbps');
      return mbps;
    } catch (e) {
      debugPrint('⚠️ Network speed test failed: $e');
      return 5.0; // assume decent connection
    }
  }

  /// Picks best available quality based on network speed and bitrate metadata
  Future<String> _chooseBestQuality(double speedMbps) async {
    if (_qualityUrls.isEmpty) return 'Auto';

    // Define minimum speed requirements (roughly)
    final Map<String, double> qualityMinSpeed = {
      '144p': 0.3,
      '240p': 0.5,
      '360p': 1.0,
      '480p': 2.0,
      '720p': 3.5,
      '1080p': 6.0,
      '1440p': 8.0,
      '2160p': 15.0,
    };

    final available = _qualityUrls.keys.toList();
    String best = available.first;

    for (final q in available) {
      final reqSpeed = qualityMinSpeed[q] ?? 0;
      if (speedMbps >= reqSpeed) best = q;
    }

    debugPrint('🎯 Auto-selected best quality: $best for $speedMbps Mbps');
    return best;
  }

  /// Automatically selects and initializes best video quality
  Future<void> autoSelectBestQuality() async {
    if (_qualityUrls.isEmpty) return;
    final testUrl = _qualityUrls.values.first;
    final speed = await _estimateNetworkSpeedMbps(testUrl);
    final bestQuality = await _chooseBestQuality(speed);

    if (bestQuality.isNotEmpty) {
      await setVideoQuality(bestQuality);
    }
  }

  void setVideoPlayerController(VideoPlayerController controller) {
    videoPlayerController?.removeListener(_videoPlayerListener);
    videoPlayerController?.dispose();
    videoPlayerController = controller;
    videoPlayerController?.addListener(_videoPlayerListener);
    isInitialized.value = controller.value.isInitialized;
    duration.value = controller.value.duration;
    position.value = controller.value.position;
    isPlaying.value = controller.value.isPlaying;
    volume.value = controller.value.volume;
    isMuted.value = controller.value.volume == 0.0;
    isLooping.value = controller.value.isLooping;
    isBuffering.value = controller.value.isBuffering;
    errorMessage.value = controller.value.errorDescription ?? '';

    if (kIsWeb) {
      // Disable native video controls to prevent browser defaults in fullscreen
      Timer(const Duration(milliseconds: 100), () {
        final videos = html.document.getElementsByTagName('video');
        if (videos.isNotEmpty) {
          final videoElement = videos.first as html.VideoElement;
          videoElement.controls = false;
        }
      });
    }
  }

  void _videoPlayerListener() {
    if (videoPlayerController == null) return;
    final value = videoPlayerController!.value;
    isInitialized.value = value.isInitialized;
    duration.value = value.duration;
    position.value = value.position;
    isPlaying.value = value.isPlaying;
    volume.value = value.volume;
    isMuted.value = value.volume == 0.0;
    isLooping.value = value.isLooping;
    isBuffering.value = value.isBuffering;
    errorMessage.value = value.errorDescription ?? '';
  }

  void handleFullScreenChange() {
    final bool currentFullScreenState = html.document.fullscreenElement != null;
    if (isFullScreen.value != currentFullScreenState) {
      isFullScreen.value = currentFullScreenState;
      if (isFullScreen.value) {
        showControlsTemporarily();
      } else {
        showControls.value = false;
        _hideControlsTimer?.cancel();
        _singleTapTimer?.cancel();
        _lastTapDownTime = null;
        if (kIsWeb) {
          html.document.body?.style.cursor = 'auto';
          try {
            html.window.screen?.orientation?.unlock();
          } catch (e) {
            debugPrint('Could not unlock orientation on exit: $e');
          }
        }
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }
  }

  void toggleFullScreen() async {
    if (videoPlayerController == null) return;
    try {
      if (isFullScreen.value) {
        if (kIsWeb) {
          await FullScreenHelper.exitFullScreen();
        } else {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      } else {
        if (kIsWeb) {
          // Always use FullScreenHelper for web (including mobile) to include custom controls
          await FullScreenHelper.enterFullScreen();
          final userAgent = html.window.navigator.userAgent.toLowerCase();
          final isMobileWeb = userAgent.contains('mobi');
          if (isMobileWeb) {
            try {
              await html.window.screen?.orientation?.lock('landscape');
            } catch (e) {
              debugPrint('Could not lock orientation: $e');
            }
          }
        } else {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      }
    } catch (e) {
      debugPrint('Error toggling fullscreen: $e');
    }
  }

  void _handleSingleTap() {
    bool isMobile = !kIsWeb;
    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      isMobile = userAgent.contains('mobi');
    }
    if (isMobile) {
      showControlsTemporarily();
    } else {
      toggleControlsVisibility();
    }
  }

  void togglePlayPause() {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }
    if (videoPlayerController!.value.isPlaying) {
      videoPlayerController?.pause();
    } else {
      videoPlayerController?.play();
    }
    showControlsTemporarily();
  }

  void seekRelative(Duration offset) {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }
    final currentPosition = videoPlayerController!.value.position;
    final maxDuration = videoPlayerController!.value.duration;
    final targetPosition = currentPosition + offset;
    Duration newPosition;
    if (offset > Duration.zero) {
      newPosition = (maxDuration == Duration.zero)
          ? targetPosition
          : (targetPosition <= maxDuration ? targetPosition : maxDuration);
    } else {
      newPosition = targetPosition >= Duration.zero
          ? targetPosition
          : Duration.zero;
    }
    videoPlayerController?.seekTo(newPosition);
    showControlsTemporarily();
  }

  void setVolume(double vol) {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }
    final clampedVol = vol.clamp(0.0, 1.0);
    videoPlayerController?.setVolume(clampedVol);
    volume.value = clampedVol;
    isMuted.value = clampedVol == 0.0;
    showControlsTemporarily();
  }

  void toggleMute() {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }
    final targetVolume = isMuted.value ? 1.0 : 0.0;
    setVolume(targetVolume);
  }

  void setPlaybackSpeed(double speed) {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }
    playbackSpeed.value = speed;
    videoPlayerController?.setPlaybackSpeed(speed);
    showControlsTemporarily();
  }

  Future<void> setVideoQuality(String quality) async {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }

    if (_qualityUrls.isEmpty) {
      debugPrint('No quality URLs available');
      return;
    }

    videoQuality.value = quality;

    // pick url for requested quality or fallback to first available
    final newSource = _qualityUrls[quality] ?? _qualityUrls.values.first;

    final currentPosition = videoPlayerController!.value.position;
    final wasPlaying = videoPlayerController!.value.isPlaying;

    try {
      await videoPlayerController!.pause();
      videoPlayerController?.removeListener(_videoPlayerListener);
      await videoPlayerController?.dispose();

      final newController = VideoPlayerController.networkUrl(Uri.parse(newSource));

      await newController.initialize();

      // Apply state
      newController.setLooping(isLooping.value);
      newController.setVolume(volume.value);
      await newController.seekTo(currentPosition);

      videoPlayerController = newController;
      videoPlayerController!.addListener(_videoPlayerListener);

      if (wasPlaying) await videoPlayerController!.play();
      showControlsTemporarily();
    } catch (e) {
      debugPrint('Error switching quality to $quality: $e');
      errorMessage.value = 'Failed to switch quality';
    }
  }

  void toggleLooping(bool loop) {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }
    isLooping.value = loop;
    videoPlayerController?.setLooping(loop);
    showControlsTemporarily();
  }

  void enterPictureInPicture() {
    if (kIsWeb) {
      final videos = html.document.getElementsByTagName('video');
      if (videos.isNotEmpty) {
        final videoElement = videos.first as html.VideoElement;
        try {
          // Check if standard PiP is supported
          if (!videoElement.hasAttribute('disablePictureInPicture')) {
            (videoElement as dynamic).requestPictureInPicture();
            return;
          }
          // Fallback for webkit (Safari)
          if (videoElement.hasAttribute('webkitSupportsPresentationMode')) {
            (videoElement as dynamic).webkitSetPresentationMode(
              'picture-in-picture',
            );
            return;
          }
        } catch (e) {
          debugPrint('Picture-in-Picture not supported: $e');
        }
      }
    }
  }

  void showControlsTemporarily() {
    if (!showControls.value) {
      showControls.value = true;
    }
    if (kIsWeb) {
      html.document.body?.style.cursor = 'auto';
    }
    if (!(Get.isBottomSheetOpen ?? false)) {
      _startHideControlsTimer();
    }
  }

  void toggleControlsVisibility() {
    if (!(Get.isBottomSheetOpen ?? false)) {
      showControls.value = !showControls.value;
      if (showControls.value) {
        if (kIsWeb) {
          html.document.body?.style.cursor = 'auto';
        }
        _startHideControlsTimer();
      } else {
        _hideControlsTimer?.cancel();
        _singleTapTimer?.cancel();
        _lastTapDownTime = null;
        if (kIsWeb) {
          html.document.body?.style.cursor = 'none';
        }
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!(Get.isBottomSheetOpen ?? false)) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (showControls.value) {
          showControls.value = false;
          if (kIsWeb) {
            html.document.body?.style.cursor = 'none';
          }
        }
      });
    }
  }

  void handleTapDown(TapDownDetails details, BoxConstraints constraints) {
    final now = DateTime.now();
    final isBottomSheetOpen = Get.isBottomSheetOpen ?? false;
    if (_lastTapDownTime != null &&
        now.difference(_lastTapDownTime!) <=
            const Duration(milliseconds: 300)) {
      _singleTapTimer?.cancel();
      _lastTapDownTime = null;
      _performDoubleTapSeekGesture(details, constraints);
    } else {
      _lastTapDownTime = now;
      _singleTapTimer?.cancel();
      _singleTapTimer = Timer(const Duration(milliseconds: 300), () {
        _lastTapDownTime = null;
        if (isBottomSheetOpen) {
          Get.back();
        } else {
          _handleSingleTap();
        }
      });
    }
  }

  void _performDoubleTapSeekGesture(
    TapDownDetails details,
    BoxConstraints constraints,
  ) {
    final tapX = details.localPosition.dx;
    final width = constraints.maxWidth;
    if (tapX < width * 0.4) {
      seekRelative(const Duration(seconds: -10));
      triggerRewindOverlay();
    } else if (tapX > width * 0.6) {
      seekRelative(const Duration(seconds: 10));
      triggerForwardOverlay();
    } else {
      final willPlay = !isPlaying.value;
      togglePlayPause();
      triggerCenterOverlay(willPlay);
    }
  }

  void triggerRewindOverlay() {
    showRewindOverlay.value = true;
    Timer(const Duration(milliseconds: 800), () {
      showRewindOverlay.value = false;
    });
  }

  void triggerForwardOverlay() {
    showForwardOverlay.value = true;
    Timer(const Duration(milliseconds: 800), () {
      showForwardOverlay.value = false;
    });
  }

  void triggerCenterOverlay(bool willPlay) {
    centerOverlayIcon.value = willPlay ? Icons.play_arrow : Icons.pause;
    showCenterOverlay.value = true;
    Timer(const Duration(milliseconds: 800), () {
      showCenterOverlay.value = false;
    });
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyJ) {
        seekRelative(const Duration(seconds: -10));
      } else if (event.logicalKey == LogicalKeyboardKey.keyK ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.keyL) {
        seekRelative(const Duration(seconds: 10));
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        toggleMute();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setVolume(volume.value + 0.1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setVolume(volume.value - 0.1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        seekRelative(const Duration(seconds: -5));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        seekRelative(const Duration(seconds: 5));
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        toggleFullScreen();
      }
    }
  }

  String formatDuration(Duration duration) {
    if (duration.inSeconds.isNaN || duration.inMilliseconds < 0) {
      return '-:--';
    }
    final totalSeconds = duration.inSeconds;
    if (totalSeconds < 0) {
      return '-:--';
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    } else {
      return '$minutesStr:$secondsStr';
    }
  }

  IconData getQualityIcon(String quality) {
    switch (quality) {
      case '144p':
      case '240p':
        return Icons.signal_cellular_alt_1_bar;
      case '360p':
      case '480p':
        return Icons.signal_cellular_alt_2_bar;
      case '720p':
        return Icons.hd;
      case '1080p':
        return Icons.high_quality;
      default:
        return Icons.videocam;
    }
  }

  Color getQualityColor(String quality) {
    switch (quality) {
      case '144p':
      case '240p':
        return AppColors.brand;
      case '360p':
      case '480p':
        return Colors.orangeAccent;
      case '720p':
        return Colors.lightGreenAccent;
      case '1080p':
      case '1440p':
      case '2K':
      case '4K':
        return Colors.lightBlueAccent;
      default:
        return Colors.white70;
    }
  }

  @override
  void onClose() {
    videoPlayerController?.removeListener(_videoPlayerListener);
    videoPlayerController?.dispose();
    _hideControlsTimer?.cancel();
    _singleTapTimer?.cancel();
    if (kIsWeb) {
      html.document.body?.style.cursor = 'auto';
      try {
        html.window.screen?.orientation?.unlock();
      } catch (e) {
        debugPrint('Could not unlock orientation on close: $e');
      }
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.onClose();
  }
}

class VideoSettingsSheet extends StatelessWidget {
  const VideoSettingsSheet({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CustomController>(tag: tag);
    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Get.back(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  tooltip: 'Close settings',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPlaybackSpeedSection(controller),
                  const SizedBox(height: 16),
                  _buildVideoQualitySection(controller),
                  const SizedBox(height: 16),
                  _buildLoopSection(controller),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackSpeedSection(CustomController controller) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Playback Speed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brand, width: 1),
                ),
                child: Text(
                  '${controller.playbackSpeed.toStringAsFixed(2).replaceFirst('.00', '')}x',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: SliderTheme(
              data: SliderTheme.of(Get.context!).copyWith(
                activeTrackColor: AppColors.brand,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: AppColors.brand,
                overlayColor: AppColors.brand.withValues(alpha: 0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorColor: AppColors.brand,
                valueIndicatorTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Slider(
                min: CustomController.speedOptions.first,
                max: CustomController.speedOptions.last,
                divisions:
                    ((CustomController.speedOptions.last -
                                CustomController.speedOptions.first) /
                            0.25)
                        .round(),
                value: controller.playbackSpeed.value,
                label:
                    '${controller.playbackSpeed.toStringAsFixed(2).replaceFirst('.00', '')}x',
                onChanged: (value) {
                  double roundedValue = (value * 4).round() / 4;
                  controller.setPlaybackSpeed(roundedValue);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CustomController.speedOptions.map((speed) {
              final isSelected =
                  (controller.playbackSpeed - speed).abs() < 0.001;
              return InkWell(
                onTap: () => controller.setPlaybackSpeed(speed),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brand
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.brand : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${speed.toStringAsFixed(2).replaceFirst('.00', '')}x',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoQualitySection(CustomController controller) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quality',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<String>(
              value: controller.videoQuality.value,
              dropdownColor: Colors.black87,
              iconEnabledColor: Colors.white,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(color: Colors.white, fontSize: 14),
              items: controller.availableQualities
                  .map(
                    (quality) => DropdownMenuItem(
                      value: quality,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (quality == 'Auto')
                            const Icon(
                              Icons.auto_fix_high,
                              size: 16,
                              color: Colors.white70,
                            ),
                          if (quality != 'Auto')
                            Icon(
                              controller.getQualityIcon(quality),
                              size: 16,
                              color: controller.getQualityColor(quality),
                            ),
                          const SizedBox(width: 8),
                          Text(quality, style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  )
                  .toList(),

              onChanged: (value) async {
                if (value == null) return;
                if (value == 'Auto') {
                  await controller.autoSelectBestQuality();
                } else {
                  await controller.setVideoQuality(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoopSection(CustomController controller) {
    return Obx(() {
      if (!controller.isInitialized.value ||
          controller.duration.value == Duration.zero) {
        return const SizedBox.shrink();
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Loop Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: controller.isLooping.value,
            onChanged: controller.toggleLooping,
            activeThumbColor: AppColors.brand,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      );
    });
  }
}

class MyCustomControls extends StatefulWidget {
  final String videoId;
  final VideoPlayerController videoPlayerController;

  const MyCustomControls({
    super.key,
    required this.videoId,
    required this.videoPlayerController,
  });

  @override
  State<MyCustomControls> createState() => _MyCustomControlsState();
}

class _MyCustomControlsState extends State<MyCustomControls> {
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<CustomController>(tag: 'video_${widget.videoId}')) {
      Get.put(
        CustomController(),
        tag: 'video_${widget.videoId}',
        permanent: true,
      );
    }
    final controller = Get.find<CustomController>(
      tag: 'video_${widget.videoId}',
    );
    controller.setVideoPlayerController(widget.videoPlayerController);

    // load and auto-select in a controlled async method
    _initResolutions(controller);
  }

  Future<void> _initResolutions(CustomController controller) async {
    await controller.loadVideoResolutions(widget.videoId);
    // try auto select only if 'Auto' is selected or available
    if (controller.availableQualities.length > 1) {
      await controller.autoSelectBestQuality();
    } else {
      // fallback: if only one url available, set that as source
      final urls = controller._qualityUrls; // make getter if private
      if (urls.isNotEmpty) {
        // reinitialize the native controller to this URL (if your initial videoPlayerController wasn't set to it)
        await controller.setVideoQuality(
          controller.availableQualities.length > 1
              ? controller.availableQualities[1]
              : urls.keys.first,
        );
      }
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<CustomController>(tag: 'video_${widget.videoId}')) {
      final controller = Get.find<CustomController>(
        tag: 'video_${widget.videoId}',
      );
      controller.videoPlayerController?.dispose();
      Get.delete<CustomController>(tag: 'video_${widget.videoId}');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CustomController>(
      tag: 'video_${widget.videoId}',
    );
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: controller.handleKeyEvent,
      child: Obx(() {
        if (!controller.isInitialized.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Text(
              'Error: ${controller.errorMessage.value}',
              style: TextStyle(color: AppColors.brand),
            ),
          );
        }
        if (controller.isBuffering.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        final bool isPlaying = controller.isPlaying.value;
        final bool shouldShowControls = controller.showControls.value;
        final currentPosition = controller.position.value;
        final totalDuration = controller.duration.value;
        final formattedCurrentTime = controller.formatDuration(currentPosition);
        final formattedTotalDuration = totalDuration.inMilliseconds > 0
            ? controller.formatDuration(totalDuration)
            : '--:--';
        IconData volumeIcon;
        if (controller.volume.value == 0) {
          volumeIcon = Icons.volume_off;
        } else if (controller.volume.value < 0.5) {
          volumeIcon = Icons.volume_down;
        } else {
          volumeIcon = Icons.volume_up;
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;
            final iconSize = isSmallScreen ? 20.0 : 24.0;
            final fontSize = isSmallScreen ? 12.0 : 14.0;
            final sliderWidth = isSmallScreen ? 80.0 : 120.0;
            return InkWell(
              onTapDown: (details) =>
                  controller.handleTapDown(details, constraints),
              child: MouseRegion(
                onEnter: (_) {
                  if (isPlaying) {
                    controller.showControlsTemporarily();
                  }
                },
                onHover: (_) {
                  if (isPlaying) {
                    controller.showControlsTemporarily();
                  }
                },
                child: Stack(
                  children: [
                    if (shouldShowControls && !isPlaying)
                      Center(
                        child: _buildControlButton(
                          icon: Icons.play_arrow,
                          onPressed: controller.togglePlayPause,
                          tooltip: 'Play',
                          size: iconSize * 2,
                        ),
                      ),
                    Obx(() {
                      if (controller.showRewindOverlay.value) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 32),
                            child: AnimatedOpacity(
                              opacity: controller.showRewindOverlay.value
                                  ? 1.0
                                  : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: EdgeInsets.all(20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.replay_10,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    Text(
                                      '10',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    Obx(() {
                      if (controller.showForwardOverlay.value) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 32),
                            child: AnimatedOpacity(
                              opacity: controller.showForwardOverlay.value
                                  ? 1.0
                                  : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: EdgeInsets.all(20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.forward_10,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    Text(
                                      '10',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    Obx(() {
                      if (controller.showCenterOverlay.value) {
                        return Center(
                          child: AnimatedOpacity(
                            opacity: controller.showCenterOverlay.value
                                ? 1.0
                                : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              controller.centerOverlayIcon.value,
                              color: Colors.white,
                              size: 100,
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    AnimatedOpacity(
                      opacity: shouldShowControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: IgnorePointer(
                          ignoring: !shouldShowControls,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8 : 16,
                              vertical: isSmallScreen ? 8 : 12,
                            ),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        formattedCurrentTime,
                                        style: GoogleFonts.robotoMono(
                                          color: Colors.white,
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: VideoProgressIndicator(
                                          controller.videoPlayerController!,
                                          allowScrubbing: true,
                                          colors: VideoProgressColors(
                                            playedColor: AppColors.brand,
                                            bufferedColor: Colors.white30,
                                            backgroundColor: Colors.white12,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formattedTotalDuration,
                                        style: GoogleFonts.robotoMono(
                                          color: Colors.white,
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Stack(
                                    children: [
                                      if (!isSmallScreen)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            children: [
                                              _buildControlButton(
                                                icon: volumeIcon,
                                                onPressed:
                                                    controller.toggleMute,
                                                tooltip: 'Toggle mute',
                                                size: iconSize,
                                              ),
                                              const SizedBox(width: 4),
                                              SizedBox(
                                                width: sliderWidth,
                                                child: SliderTheme(
                                                  data: SliderTheme.of(context).copyWith(
                                                    trackHeight: 2,
                                                    thumbShape:
                                                        const RoundSliderThumbShape(
                                                          enabledThumbRadius: 6,
                                                        ),
                                                    overlayShape:
                                                        const RoundSliderOverlayShape(
                                                          overlayRadius: 12,
                                                        ),
                                                    activeTrackColor:
                                                        AppColors.brand,
                                                    inactiveTrackColor:
                                                        Colors.white30,
                                                    thumbColor:
                                                        AppColors.brand,
                                                    overlayColor: AppColors.brand
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                  child: Slider(
                                                    min: 0.0,
                                                    max: 1.0,
                                                    value:
                                                        controller.volume.value,
                                                    onChanged:
                                                        controller.setVolume,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Align(
                                        alignment: Alignment.center,
                                        child: _buildControlButton(
                                          icon: isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          onPressed: controller.togglePlayPause,
                                          tooltip: isPlaying ? 'Pause' : 'Play',
                                          size: iconSize,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (kIsWeb) ...[
                                              _buildControlButton(
                                                icon: Icons
                                                    .picture_in_picture_alt,
                                                onPressed: controller
                                                    .enterPictureInPicture,
                                                tooltip: 'Picture in Picture',
                                                size: iconSize,
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            _buildControlButton(
                                              icon: Icons.settings,
                                              onPressed: () {
                                                controller._hideControlsTimer
                                                    ?.cancel();
                                                Get.bottomSheet(
                                                  VideoSettingsSheet(
                                                    tag:
                                                        'video_${widget.videoId}',
                                                  ),
                                                  isDismissible: true,
                                                  enableDrag: true,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                ).then((_) {
                                                  controller
                                                      .showControlsTemporarily();
                                                });
                                              },
                                              tooltip: 'Open settings',
                                              size: iconSize,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildControlButton(
                                              icon:
                                                  controller.isFullScreen.value
                                                  ? Icons.fullscreen_exit
                                                  : Icons.fullscreen,
                                              onPressed:
                                                  controller.toggleFullScreen,
                                              tooltip:
                                                  controller.isFullScreen.value
                                                  ? 'Exit fullscreen'
                                                  : 'Enter fullscreen',
                                              size: iconSize,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double size = 24.0,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size),
        onPressed: onPressed,
        padding: EdgeInsets.all(size / 3),
        constraints: BoxConstraints(
          minWidth: size * 1.5,
          minHeight: size * 1.5,
        ),
        splashRadius: size,
        tooltip: tooltip,
      ),
    );
  }
}




