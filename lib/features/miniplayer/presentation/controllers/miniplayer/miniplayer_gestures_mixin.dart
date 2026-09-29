import 'package:flutter/material.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_state_base.dart';

/// Mixin providing expand/collapse transitions, dragging, and free-form docking.
mixin MiniplayerGesturesMixin on MiniplayerStateBase {
  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW STATE TRANSITIONS (expand / collapse / drag)
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void expand() {
    if (mode.value == MiniplayerMode.expanded) return;
    mode.value = MiniplayerMode.expanded;
    dragProgress.value = 1.0;
  }

  @override
  void collapse() {
    if (mode.value == MiniplayerMode.collapsed) return;
    mode.value = MiniplayerMode.collapsed;
    dragProgress.value = 0.0;
  }

  void onDragUpdate(double delta, double screenHeight) {
    if (mode.value == MiniplayerMode.dismissed) return;
    mode.value = MiniplayerMode.dragging;
    // Delta is negative when dragging up (expanding)
    final newProgress = (dragProgress.value - delta / screenHeight).clamp(
      0.0,
      1.0,
    );
    dragProgress.value = newProgress;
  }

  void onDragEnd() {
    if (mode.value != MiniplayerMode.dragging) return;

    // If dragging down from collapsed state past dismiss threshold, dismiss
    if (dragProgress.value < 0.15 && mode.value == MiniplayerMode.dragging) {
      // Check if we were collapsed and dragged down
      final previousMode = mode.value;
      if (previousMode == MiniplayerMode.dragging &&
          dragProgress.value < MiniplayerConfig.dismissThreshold) {
        dismiss();
        return;
      }
    }

    // Otherwise, snap to nearest state based on snap threshold
    if (dragProgress.value > MiniplayerConfig.snapThreshold) {
      expand();
    } else {
      collapse();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Free-positioning drag (card can be moved anywhere)
  // ───────────────────────────────────────────────────────────────────────────

  /// Translate the floating card by [delta] pixels, keeping it on-screen.
  /// [cardSize] is the card's logical size and [screenSize] the viewport.
  void onPanCard(Offset delta, Size cardSize, Size screenSize) {
    if (mode.value != MiniplayerMode.collapsed &&
        mode.value != MiniplayerMode.dragging) {
      return;
    }
    final current =
        dragOffset.value ?? defaultDockOffset(cardSize, screenSize);
    final maxX = (screenSize.width - cardSize.width).clamp(
      0.0,
      double.infinity,
    );
    final maxY = (screenSize.height - cardSize.height).clamp(
      0.0,
      double.infinity,
    );
    dragOffset.value = Offset(
      (current.dx + delta.dx).clamp(0.0, maxX),
      (current.dy + delta.dy).clamp(0.0, maxY),
    );
  }

  /// Resolve the effective top-left position of the card given the viewport.
  /// Falls back to bottom-right docking when the user hasn't moved it yet.
  Offset effectiveOffset(Size cardSize, Size screenSize) {
    final stored = dragOffset.value;
    if (stored == null) return defaultDockOffset(cardSize, screenSize);
    final maxX = (screenSize.width - cardSize.width).clamp(
      0.0,
      double.infinity,
    );
    final maxY = (screenSize.height - cardSize.height).clamp(
      0.0,
      double.infinity,
    );
    return Offset(
      stored.dx.clamp(0.0, maxX),
      stored.dy.clamp(0.0, maxY),
    );
  }

  Offset defaultDockOffset(Size cardSize, Size screenSize) {
    final isMobile = MiniplayerConfig.isMobileLayout(screenSize.width);
    final insetX =
        isMobile ? MiniplayerConfig.mobileDockInset : MiniplayerConfig.dockInset;
    final insetY = isMobile
        ? MiniplayerConfig.mobileDockBottomInset
        : MiniplayerConfig.dockInset;
    return Offset(
      (screenSize.width - cardSize.width - insetX).clamp(0.0, double.infinity),
      (screenSize.height - cardSize.height - insetY).clamp(0.0, double.infinity),
    );
  }

  /// Hover state — used to fade overlay controls in and out.
  void setHovering(bool value) {
    if (isHovering.value != value) isHovering.value = value;
  }
}
