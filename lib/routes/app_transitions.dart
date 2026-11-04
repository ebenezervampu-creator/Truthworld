import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Centralized, production-grade page transition configuration for TruthWorld.
///
/// Encapsulates the 5 best page routing animations tailored to specific navigation patterns
/// across all 4 TruthWorld applications (Consumer Streaming, Creator Studio, Admin Moderation,
/// and Advertiser Portal):
///
/// 1. [hierarchical]: Right-to-Left Slide with Fade (Master-to-Detail, Deep Dives, and Settings).
/// 2. [modal]: Bottom-to-Top Sheet/Modal Slide (Creation, Actions, Forms, Authentication, and Overlays).
/// 3. [peer]: Cross-Fade / Shared Axis Fade-Through (Primary Shells, Navigation Tabs, and Sibling Views).
/// 4. [mediaZoom]: Zoom & Container Expansion (Feed-to-Video Player, Playback Screens, and Analysis).
/// 5. [verticalFeed]: Vertical Snap Slide (Clips, Shorts, and Fullscreen Immersive Feeds).
abstract class AppTransitions {
  AppTransitions._();

  // --- 1. Master-to-Detail / Hierarchical (Right-to-Left with Fade) ---
  /// Communicates deeper entry into a hierarchy (e.g. Channel details, Settings, Playlist).
  static Transition get hierarchical =>
      kIsWeb ? Transition.noTransition : Transition.rightToLeftWithFade;
  static Duration get hierarchicalDuration =>
      kIsWeb ? Duration.zero : const Duration(milliseconds: 260);
  static const Curve hierarchicalCurve = Curves.easeOutCubic;

  // --- 2. Modal / Creation / Action Sheet (Bottom-to-Top) ---
  /// Signals a temporary task or creation mode (e.g. Upload, Create Post, AI Chat, Login).
  static Transition get modal =>
      kIsWeb ? Transition.noTransition : Transition.downToUp;
  static Duration get modalDuration =>
      kIsWeb ? Duration.zero : const Duration(milliseconds: 280);
  static const Curve modalCurve = Curves.easeOutCubic;

  // --- 3. Peer / Sibling / Shell Navigation (Cross-Fade / Fade-Through) ---
  /// Direction-neutral transition between equal-level tabs/screens (e.g. Home, Library, Dashboards).
  static Transition get peer =>
      kIsWeb ? Transition.noTransition : Transition.fadeIn;
  static Duration get peerDuration =>
      kIsWeb ? Duration.zero : const Duration(milliseconds: 200);
  static const Curve peerCurve = Curves.easeInOut;

  // --- 4. Media Player / Video Expansion (Zoom / Shared Container) ---
  /// Expands media thumbnails into the full playback canvas (e.g. Video player, Watch screen).
  static Transition get mediaZoom =>
      kIsWeb ? Transition.noTransition : Transition.zoom;
  static Duration get mediaZoomDuration =>
      kIsWeb ? Duration.zero : const Duration(milliseconds: 260);
  static const Curve mediaZoomCurve = Curves.fastLinearToSlowEaseIn;

  // --- 5. Short-Form / Clips Vertical Snap (Vertical Slide) ---
  /// Snappy vertical transition tailored to vertical video consumption (e.g. Shorts, Clips).
  static Transition get verticalFeed =>
      kIsWeb ? Transition.noTransition : Transition.downToUp;
  static Duration get verticalFeedDuration =>
      kIsWeb ? Duration.zero : const Duration(milliseconds: 250);
  static const Curve verticalFeedCurve = Curves.easeOutQuad;
}
