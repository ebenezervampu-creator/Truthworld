import 'package:flutter/material.dart';

/// Scroll position restoration service for maintaining scroll state
/// across navigation and widget rebuilds
class ScrollRestorationService {
  static final ScrollRestorationService _instance =
      ScrollRestorationService._internal();
  factory ScrollRestorationService() => _instance;
  ScrollRestorationService._internal();

  // Store scroll positions by page identifier
  final Map<String, double> _scrollPositions = {};
  final Map<String, ScrollController> _controllers = {};

  /// Get or create a scroll controller with restoration
  ScrollController getController(String pageId, {double initialScrollOffset = 0.0}) {
    if (_controllers.containsKey(pageId)) {
      final existingController = _controllers[pageId];
      if (existingController != null && existingController.hasClients) {
        return existingController;
      }
    }

    final scrollOffset = _scrollPositions[pageId] ?? initialScrollOffset;
    final controller = ScrollController(initialScrollOffset: scrollOffset);
    
    // Listen to save position on scroll
    controller.addListener(() {
      if (controller.hasClients) {
        _scrollPositions[pageId] = controller.offset;
      }
    });

    _controllers[pageId] = controller;
    return controller;
  }

  /// Save current scroll position
  void savePosition(String pageId, double offset) {
    _scrollPositions[pageId] = offset;
  }

  /// Restore scroll position with animation
  Future<void> restorePosition(String pageId, {Duration duration = const Duration(milliseconds: 300)}) async {
    final controller = _controllers[pageId];
    if (controller == null || !controller.hasClients) return;

    final targetOffset = _scrollPositions[pageId] ?? 0.0;
    await controller.animateTo(
      targetOffset,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  /// Clear stored position
  void clearPosition(String pageId) {
    _scrollPositions.remove(pageId);
  }

  /// Dispose controller
  void disposeController(String pageId) {
    final controller = _controllers.remove(pageId);
    controller?.dispose();
    _scrollPositions.remove(pageId);
  }

  /// Dispose all controllers
  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _scrollPositions.clear();
  }
}

/// Extension for easy scroll restoration on ScrollController
extension ScrollControllerExtension on ScrollController {
  void enableRestoration(String pageId) {
    addListener(() {
      if (hasClients) {
        ScrollRestorationService().savePosition(pageId, offset);
      }
    });
  }
}
