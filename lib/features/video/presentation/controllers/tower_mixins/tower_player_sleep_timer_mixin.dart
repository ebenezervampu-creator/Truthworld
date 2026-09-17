import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerSleepTimerMixin on GetxController {
  VideoPlayerController get videoPlayerController;
  RxDouble get playbackSpeed;
  SleepTimerService get sleepTimerService;
  PlaybackSource get activePlayback;
  void showToast(String msg);

  final RxBool isLongPressSpeedUp = false.obs;
  double preLongPressSpeed = 1.0;

  void startLongPressSpeedUp() {
    if (isLongPressSpeedUp.value) return;
    preLongPressSpeed = playbackSpeed.value;
    videoPlayerController.setPlaybackSpeed(2);
    playbackSpeed.value = 2.0;
    isLongPressSpeedUp.value = true;
  }

  void endLongPressSpeedUp() {
    if (!isLongPressSpeedUp.value) return;
    videoPlayerController.setPlaybackSpeed(preLongPressSpeed);
    playbackSpeed.value = preLongPressSpeed;
    isLongPressSpeedUp.value = false;
  }

  void setSleepTimer(Duration duration, {bool isEndOfVideo = false}) {
    sleepTimerService.setActivePlayback(activePlayback);
    sleepTimerService.startTimer(duration, isEndOfVideo: isEndOfVideo);
    showToast(
      isEndOfVideo
          ? 'Sleep timer: End of video'
          : 'Sleep timer: ${duration.inMinutes} min',
    );
  }

  void extendSleepTimer(Duration addDuration) {
    sleepTimerService.extendTimer(addDuration);
    showToast('+${addDuration.inMinutes} min added to sleep timer');
  }

  void cancelSleepTimer() {
    sleepTimerService.cancelTimer();
    showToast('Sleep timer cancelled');
  }
}
