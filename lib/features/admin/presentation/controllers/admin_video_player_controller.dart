import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Controller for managing video playback inside Admin Dashboard view
class AdminVideoPlayerController extends GetxController {
  AdminVideoPlayerController(this.url);
  final String url;

  late VideoPlayerController videoCtrl;
  ChewieController? chewieCtrl;
  final RxBool isPlayerInitialized = false.obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(_initPlayer());
  }

  Future<void> _initPlayer() async {
    try {
      videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await videoCtrl.initialize();
      chewieCtrl = ChewieController(
        videoPlayerController: videoCtrl,
        aspectRatio: videoCtrl.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.brand,
          handleColor: AppColors.brand,
          bufferedColor: AppColors.progressBuffered,
          backgroundColor: AppColors.progressTrack,
        ),
      );
      isPlayerInitialized.value = true;
    } catch (e) {
      error.value = 'Error loading video player: $e';
    }
  }

  @override
  void onClose() {
    unawaited(videoCtrl.dispose());
    chewieCtrl?.dispose();
    super.onClose();
  }
}
