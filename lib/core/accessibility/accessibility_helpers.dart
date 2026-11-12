import 'package:flutter/material.dart';

/// Accessibility utility extensions and helpers.
///
/// Provides convenience methods for common accessibility patterns
/// following WCAG 2.1 guidelines.

/// Extension on BuildContext for accessibility queries.
extension AccessibilityContext on BuildContext {
  /// Whether the user has enabled screen reader (TalkBack/VoiceOver)
  bool get isScreenReaderActive =>
      MediaQuery.of(this).accessibleNavigation;

  /// Whether the user prefers reduced motion
  bool get prefersReducedMotion =>
      MediaQuery.of(this).disableAnimations;

  /// Whether the user has enabled bold text
  bool get prefersBoldText =>
      MediaQuery.of(this).boldText;

  /// Whether the user has enabled high contrast
  bool get prefersHighContrast =>
      MediaQuery.of(this).highContrast;

  /// Whether the user has inverted colors
  bool get hasInvertedColors =>
      MediaQuery.of(this).invertColors;

  /// Current text scale factor (for respecting system font size)
  double get textScale =>
      MediaQuery.textScalerOf(this).scale(1.0);

  /// Whether text is scaled above normal (user increased system font)
  bool get isTextScaled => textScale > 1.0;
}

/// Semantic label builders for common TruthWorld content.
///
/// Standardizes how content is described to screen readers
/// across the entire app.
class SemanticLabels {
  SemanticLabels._();

  /// Video card label read by screen reader
  static String videoCard({
    required String title,
    required String channelName,
    String? duration,
    int? viewCount,
    bool isVerified = false,
  }) {
    final parts = <String>[title, 'by $channelName'];
    if (duration != null) parts.add(duration);
    if (viewCount != null) parts.add('$viewCount views');
    if (isVerified) parts.add('Fact-checked');
    return parts.join(', ');
  }

  /// Channel label
  static String channel({
    required String name,
    int? subscriberCount,
    String? tier,
  }) {
    final parts = <String>[name];
    if (subscriberCount != null) parts.add('$subscriberCount subscribers');
    if (tier != null && tier != 'basic') parts.add('$tier creator');
    return parts.join(', ');
  }

  /// Thumbnail description
  static String thumbnail(String videoTitle) =>
      'Thumbnail for $videoTitle';

  /// Duration badge
  static String duration(String formattedDuration) =>
      'Duration: $formattedDuration';

  /// Credibility badge (Zero Video Trust Score Policy)
  static String credibilityBadge({
    required bool isVerified,
  }) {
    if (!isVerified) return 'Not fact-checked';
    return 'Fact-checked on transparent claim ledger';
  }

  /// Like button
  static String likeButton({required bool isLiked, int? likeCount}) {
    if (isLiked) {
      return likeCount != null ? 'Liked, $likeCount likes' : 'Liked';
    }
    return likeCount != null ? 'Like, $likeCount likes' : 'Like';
  }

  /// Subscribe button
  static String subscribeButton({required bool isSubscribed}) =>
      isSubscribed ? 'Subscribed, tap to unsubscribe' : 'Subscribe';

  /// Navigation bar item
  static String navItem(String name, {bool isSelected = false}) =>
      isSelected ? '$name, selected' : name;

  /// Search field
  static String searchField({String? currentQuery}) =>
      currentQuery != null && currentQuery.isNotEmpty
          ? 'Search, current query: $currentQuery'
          : 'Search TruthWorld';

  /// Progress indicator
  static String progress(double percent) =>
      '${(percent * 100).round()} percent complete';

  /// Video player
  static String playerState({
    required bool isPlaying,
    required String position,
    required String duration,
  }) =>
      '${isPlaying ? "Playing" : "Paused"}, $position of $duration';
}

/// Mixin for widgets that need to handle reduced motion.
///
/// When the user has enabled "reduce motion" in system settings,
/// animations should be simplified or removed.
mixin ReducedMotionAware {
  /// Returns appropriate animation duration based on user preference.
  Duration getAnimationDuration(BuildContext context, Duration normal) {
    if (context.prefersReducedMotion) {
      return Duration.zero;
    }
    return normal;
  }

  /// Returns appropriate animation curve based on user preference.
  Curve getAnimationCurve(BuildContext context, Curve normal) {
    if (context.prefersReducedMotion) {
      return Curves.linear;
    }
    return normal;
  }
}
