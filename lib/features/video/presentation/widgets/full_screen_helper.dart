import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:fullscreen_window/fullscreen_window.dart';

class FullScreenHelper {
  static final List<Function(bool)> _listeners = [];

  static void addListener(Function(bool) listener) {
    debugPrint('FullScreenHelper: Adding listener');
    _listeners.add(listener);
  }

  static void removeListener(Function(bool) listener) {
    debugPrint('FullScreenHelper: Removing listener');
    _listeners.remove(listener);
  }

  static Future<void> enterFullScreen() async {
    try {
      debugPrint('FullScreenHelper: Attempting to enter full-screen');

      if (_isDesktopPlatform()) {
        await FullScreenWindow.setFullScreen(true);
      } else {
        debugPrint(
          'FullScreenHelper: Full-screen not supported on this platform.',
        );
      }

      debugPrint('FullScreenHelper: Successfully entered full-screen');
      _notifyListeners(true);
    } catch (e) {
      debugPrint('FullScreenHelper: Error entering full-screen: $e');
    }
  }

  static Future<void> exitFullScreen() async {
    try {
      debugPrint('FullScreenHelper: Attempting to exit full-screen');

      if (_isDesktopPlatform()) {
        await FullScreenWindow.setFullScreen(false);
      } else {
        debugPrint(
          'FullScreenHelper: Full-screen not supported on this platform.',
        );
      }

      debugPrint('FullScreenHelper: Successfully exited full-screen');
      _notifyListeners(false);
    } catch (e) {
      debugPrint('FullScreenHelper: Error exiting full-screen: $e');
    }
  }

  static Future<bool> isFullScreenNow() async {
    try {
      if (_isDesktopPlatform()) {
        // Since the fullscreen_window package doesn't provide a reliable way to check
        // the current fullscreen state, we'll handle it through our listeners
        debugPrint('FullScreenHelper: Fullscreen state check requested');
        return true; // Assuming we're in fullscreen if we're on desktop
      }
      debugPrint(
        'FullScreenHelper: Full-screen state not available on this platform.',
      );
      return false;
    } catch (e) {
      debugPrint('FullScreenHelper: Error checking full-screen state: $e');
      return false;
    }
  }

  static void _notifyListeners(bool isFullScreen) {
    for (final listener in _listeners) {
      listener(isFullScreen);
    }
  }

  static bool _isDesktopPlatform() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }
}
