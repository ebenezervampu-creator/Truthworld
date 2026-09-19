import 'dart:async';

import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

/// Client contract for any card capable of hover/mobile autoplay previews.
abstract class HoverPreviewClient {
  bool get isDisposed;
  bool get disableHoverPreview;
  bool get isHovered;
  bool get hasActivePlayer;
  void handleHoverExit();
  void startHoverPlayback();
}

/// Central coordinator managing active hover previews and mobile feed autoplay.
class HoverPreviewCoordinator {
  static final RxBool globalMute = false.obs;
  static dynamic _activeCard;
  static dynamic _pendingCard;

  // Centralized mobile visibility registry (card -> visibleFraction)
  static final Map<dynamic, double> _mobileCardVisibilities = {};
  static Timer? _mobileVisibilityDebounce;

  /// Checks if any active main video playback on Homepage or VideoScreen is currently muted.
  static bool isMainVideoMuted() {
    // 1. Check all active TowerPlayerController instances
    for (final player in TowerPlayerController.activePlayers) {
      if (player.isMuted.value || player.volume.value == 0.0) {
        return true;
      }
    }
    if (Get.isRegistered<TowerPlayerController>()) {
      try {
        final tower = Get.find<TowerPlayerController>();
        if (tower.isMuted.value || tower.volume.value == 0.0) {
          return true;
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'VideoCard.isMainVideoMuted.tower',
        );
      }
    }

    // 2. Check MiniplayerController
    if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
      try {
        final mini = Get.find<MiniplayerController>(tag: 'miniplayer');
        if (mini.isPlaying.value) {
          if (mini.isMuted.value ||
              (mini.videoPlayerController?.value.volume ?? 1.0) == 0.0) {
            return true;
          }
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'VideoCard.isMainVideoMuted.miniplayer',
        );
      }
    }

    return false;
  }

  /// Sets the currently active card and immediately deactivates any previously active card.
  static void setActiveCard(dynamic card) {
    if (_activeCard != null && _activeCard != card) {
      _safelyCallHoverExit(_activeCard);
    }
    _activeCard = card;
    _pendingCard = null;
    if (!globalMute.value) {
      pauseAllMainPlayers();
    }
  }

  /// Clears the active or pending card if it matches.
  static void clearActiveCard(dynamic card) {
    if (_activeCard == card) {
      _activeCard = null;
    }
    if (_pendingCard == card) {
      _pendingCard = null;
    }
  }

  /// Completely unregisters a card when disposed or scrolled off-screen.
  static void unregisterCard(dynamic card) {
    _mobileCardVisibilities.remove(card);
    if (_activeCard == card) {
      _activeCard = null;
    }
    if (_pendingCard == card) {
      _pendingCard = null;
    }
  }

  /// Reports visibleFraction (0.0 to 1.0) for a VideoCard on mobile feeds.
  /// Automatically determines the single card with the highest visibility and starts preview.
  static void reportMobileVisibility(
    dynamic card,
    double visibleFraction,
  ) {
    if (card is HoverPreviewClient) {
      if (card.isDisposed || card.disableHoverPreview) {
        _mobileCardVisibilities.remove(card);
        return;
      }
    }

    if (visibleFraction < 0.1) {
      _mobileCardVisibilities.remove(card);
      if (_activeCard == card) {
        _safelyCallHoverExit(card);
        _activeCard = null;
      }
      if (_pendingCard == card) {
        _safelyCallHoverExit(card);
        _pendingCard = null;
      }
    } else {
      _mobileCardVisibilities[card] = visibleFraction;
    }

    // Debounce visibility evaluation during active scrolling / flings
    _mobileVisibilityDebounce?.cancel();
    _mobileVisibilityDebounce = Timer(
      const Duration(milliseconds: 150),
      _evaluateMobileAutoplay,
    );
  }

  /// Evaluates which video card in the mobile feed should autoplay.
  static void _evaluateMobileAutoplay() {
    // 1. Clean up any disposed cards
    _mobileCardVisibilities.removeWhere((card, _) {
      if (card is HoverPreviewClient) {
        return card.isDisposed;
      }
      return false;
    });

    if (_mobileCardVisibilities.isEmpty) {
      if (_activeCard != null) {
        _safelyCallHoverExit(_activeCard);
        _activeCard = null;
      }
      _pendingCard = null;
      return;
    }

    // 2. Find the card with the highest visible fraction
    dynamic topCard;
    var maxFraction = 0.0;

    for (final entry in _mobileCardVisibilities.entries) {
      if (entry.value > maxFraction) {
        maxFraction = entry.value;
        topCard = entry.key;
      }
    }

    // 3. Minimum visibility threshold to qualify for autoplay preview (70%)
    const minVisibleThreshold = 0.70;

    if (topCard != null && maxFraction >= minVisibleThreshold) {
      if (_activeCard == topCard) {
        for (final card in _mobileCardVisibilities.keys) {
          if (card != topCard) {
            if (card is HoverPreviewClient &&
                (card.isHovered || card.hasActivePlayer)) {
              _safelyCallHoverExit(card);
            }
          }
        }
        return;
      }

      if (_pendingCard == topCard) {
        return;
      }

      if (_activeCard != null && _activeCard != topCard) {
        _safelyCallHoverExit(_activeCard);
        _activeCard = null;
      }
      if (_pendingCard != null && _pendingCard != topCard) {
        _safelyCallHoverExit(_pendingCard);
        _pendingCard = null;
      }
      for (final card in _mobileCardVisibilities.keys) {
        if (card != topCard) {
          _safelyCallHoverExit(card);
        }
      }

      _pendingCard = topCard;
      if (topCard is HoverPreviewClient) {
        topCard.startHoverPlayback();
      }
    } else {
      if (_activeCard != null) {
        _safelyCallHoverExit(_activeCard);
        _activeCard = null;
      }
      if (_pendingCard != null) {
        _safelyCallHoverExit(_pendingCard);
        _pendingCard = null;
      }
    }
  }

  static void _safelyCallHoverExit(dynamic card) {
    if (card is HoverPreviewClient) {
      card.handleHoverExit();
    }
  }

  /// Pauses active players on MiniplayerController and TowerPlayerController.
  static void pauseAllMainPlayers() {
    try {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
        final mini = Get.find<MiniplayerController>(tag: 'miniplayer');
        if (mini.isPlaying.value) {
          mini.videoPlayerController?.pause();
          mini.isPlaying.value = false;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoCard.pauseAllMainPlayers.miniplayer',
      );
    }
    try {
      TowerPlayerController.pauseAllActivePlayers();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoCard.pauseAllMainPlayers.tower',
      );
    }
  }
}
