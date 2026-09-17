import 'dart:math';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/views/player/dialogs/keyboard_shortcuts_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerKeyboardMixin on GetxController {
  bool get isShowingAdValue;
  bool get isFullScreenValue;
  void togglePlayPauseAd();
  void toggleFullscreen();
  void toggleMuteAd();
  Future<void> togglePlayPause();
  void executeDoubleTapSeek({required bool isLeft, bool resetAccumulator = false});
  Future<void> seekRelative(int seconds, {bool showFeedbackToast = true});
  void setVolume(double vol);
  void showToast(String msg);
  RxDouble get volume;
  void toggleMute();
  void playNext();
  void playPrevious();
  Future<void> togglePiP();
  RxDouble get playbackSpeed;
  void setSpeed(double speed);
  VideoPlayerValue get vv;
  Future<void> seekTo(Duration pos);

  void handleKeyJ() => executeDoubleTapSeek(isLeft: true);
  void handleKeyL() => executeDoubleTapSeek(isLeft: false);

  void showShortcutsDialog() {
    Get.dialog(
      const KeyboardShortcutsDialog(),
      barrierColor: AppColors.bgPage.withValues(alpha: 0.8),
    );
  }

  void adjustSpeedRelative(double delta) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final current = playbackSpeed.value;
    var index = speeds.indexOf(current);
    if (index == -1) {
      var minDiff = double.infinity;
      var closestIdx = 3; // 1.0
      for (var i = 0; i < speeds.length; i++) {
        final diff = (speeds[i] - current).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestIdx = i;
        }
      }
      index = closestIdx;
    }
    final newIndex = (index + (delta > 0 ? 1 : -1)).clamp(0, speeds.length - 1);
    setSpeed(speeds[newIndex]);
    showToast('Speed: ${speeds[newIndex]}×');
  }

  void handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;

    if (isShowingAdValue) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
        togglePlayPauseAd();
      } else if (key == LogicalKeyboardKey.keyF) {
        toggleFullscreen();
      } else if (key == LogicalKeyboardKey.keyM) {
        toggleMuteAd();
      } else if (key == LogicalKeyboardKey.escape) {
        if (isFullScreenValue) toggleFullscreen();
      }
      return;
    }

    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      togglePlayPause();
    } else if (key == LogicalKeyboardKey.keyJ) {
      handleKeyJ();
    } else if (key == LogicalKeyboardKey.keyL) {
      handleKeyL();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      seekRelative(5);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      seekRelative(-5);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setVolume(min(1, volume.value + 0.1));
      showToast('Volume ${(volume.value * 100).round()}%');
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setVolume(max(0, volume.value - 0.1));
      showToast('Volume ${(volume.value * 100).round()}%');
    } else if (key == LogicalKeyboardKey.keyF) {
      toggleFullscreen();
    } else if (key == LogicalKeyboardKey.keyM) {
      toggleMute();
    } else if (key == LogicalKeyboardKey.keyN) {
      playNext();
    } else if (key == LogicalKeyboardKey.keyP) {
      playPrevious();
    } else if (key == LogicalKeyboardKey.keyI) {
      togglePiP();
    } else if (key == LogicalKeyboardKey.escape) {
      if (isFullScreenValue) toggleFullscreen();
    } else if (key == LogicalKeyboardKey.slash) {
      if (HardwareKeyboard.instance.isShiftPressed) showShortcutsDialog();
    } else if (key == LogicalKeyboardKey.comma) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        adjustSpeedRelative(-0.25);
      } else {
        seekRelative(-1);
      }
    } else if (key == LogicalKeyboardKey.period) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        adjustSpeedRelative(0.25);
      } else {
        seekRelative(1);
      }
    } else {
      final digitMap = {
        LogicalKeyboardKey.digit0: 0.0,
        LogicalKeyboardKey.digit1: 0.1,
        LogicalKeyboardKey.digit2: 0.2,
        LogicalKeyboardKey.digit3: 0.3,
        LogicalKeyboardKey.digit4: 0.4,
        LogicalKeyboardKey.digit5: 0.5,
        LogicalKeyboardKey.digit6: 0.6,
        LogicalKeyboardKey.digit7: 0.7,
        LogicalKeyboardKey.digit8: 0.8,
        LogicalKeyboardKey.digit9: 0.9,
        LogicalKeyboardKey.numpad0: 0.0,
        LogicalKeyboardKey.numpad1: 0.1,
        LogicalKeyboardKey.numpad2: 0.2,
        LogicalKeyboardKey.numpad3: 0.3,
        LogicalKeyboardKey.numpad4: 0.4,
        LogicalKeyboardKey.numpad5: 0.5,
        LogicalKeyboardKey.numpad6: 0.6,
        LogicalKeyboardKey.numpad7: 0.7,
        LogicalKeyboardKey.numpad8: 0.8,
        LogicalKeyboardKey.numpad9: 0.9,
      };
      if (digitMap.containsKey(key)) {
        final fraction = digitMap[key]!;
        final dur = vv.duration;
        if (dur > Duration.zero) {
          seekTo(dur * fraction);
          showToast('Seek to ${(fraction * 100).round()}%');
        }
      }
    }
  }
}
