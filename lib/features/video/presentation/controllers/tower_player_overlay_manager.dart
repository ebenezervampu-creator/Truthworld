import 'package:get/get.dart';

/// Explicit enumeration of distinct video player overlays.
/// Invariant: At most ONE overlay can be active at a time.
enum TowerPlayerOverlay {
  none,
  truthReport,
  factCheck,
  liveChat,
  comments,
  transcript,
  settings,
  audioTracks,
  subtitles,
  share,
  statsForNerds,
  moreVideos,
}

/// Orchestration component for video player overlays and modal side-sheets.
///
/// Ensures deterministic single-active-overlay invariant, preventing competing
/// or overlapping modal sheets and driving the auto-hide control lock.
class TowerPlayerOverlayManager {
  TowerPlayerOverlayManager({this.onOverlayChanged});

  /// Optional notification callback when overlay state transitions.
  final void Function(TowerPlayerOverlay overlay)? onOverlayChanged;

  /// Reactive active overlay state.
  final Rx<TowerPlayerOverlay> activeOverlay = TowerPlayerOverlay.none.obs;

  /// Current active overlay value.
  TowerPlayerOverlay get current => activeOverlay.value;

  /// Whether any modal overlay is actively blocking or open.
  bool get hasBlockingOverlay => activeOverlay.value != TowerPlayerOverlay.none;

  /// Whether no overlay is open.
  bool get isNone => activeOverlay.value == TowerPlayerOverlay.none;

  // ── Typed Convenience Getters ──────────────────────────────
  bool get isTruthReportOpen =>
      activeOverlay.value == TowerPlayerOverlay.truthReport ||
      activeOverlay.value == TowerPlayerOverlay.factCheck;
  bool get isFactCheckOpen =>
      activeOverlay.value == TowerPlayerOverlay.factCheck;
  bool get isLiveChatOpen => activeOverlay.value == TowerPlayerOverlay.liveChat;
  bool get isCommentsOpen => activeOverlay.value == TowerPlayerOverlay.comments;
  bool get isTranscriptOpen =>
      activeOverlay.value == TowerPlayerOverlay.transcript;
  bool get isSettingsOpen => activeOverlay.value == TowerPlayerOverlay.settings;
  bool get isAudioTracksOpen =>
      activeOverlay.value == TowerPlayerOverlay.audioTracks;
  bool get isSubtitlesOpen =>
      activeOverlay.value == TowerPlayerOverlay.subtitles;
  bool get isShareOpen => activeOverlay.value == TowerPlayerOverlay.share;
  bool get isStatsForNerdsOpen =>
      activeOverlay.value == TowerPlayerOverlay.statsForNerds;
  bool get isMoreVideosOpen =>
      activeOverlay.value == TowerPlayerOverlay.moreVideos;

  // ── State Transitions ──────────────────────────────────────

  /// Opens the specified overlay, automatically closing any previously active overlay.
  void open(TowerPlayerOverlay overlay) {
    if (activeOverlay.value != overlay) {
      activeOverlay.value = overlay;
      onOverlayChanged?.call(overlay);
    }
  }

  /// Closes the currently active overlay.
  void close() {
    if (activeOverlay.value != TowerPlayerOverlay.none) {
      activeOverlay.value = TowerPlayerOverlay.none;
      onOverlayChanged?.call(TowerPlayerOverlay.none);
    }
  }

  /// Toggles the specified overlay: closes if already active, opens otherwise.
  void toggle(TowerPlayerOverlay overlay) {
    if (activeOverlay.value == overlay) {
      close();
    } else {
      open(overlay);
    }
  }

  /// Disposes resources.
  void dispose() {
    activeOverlay.value = TowerPlayerOverlay.none;
  }
}
