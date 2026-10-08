import 'package:flutter/semantics.dart';

/// Centralized screen reader announcement service.
///
/// WCAG 2.1 SC 4.1.3 (Level AA): Status messages can be programmatically
/// determined through role or properties such that they can be presented
/// to the user by assistive technologies without receiving focus.
///
/// Usage:
/// ```dart
/// ScreenReaderService.announce('Video liked');
/// ScreenReaderService.announcePolite('5 new videos loaded');
/// ```
class ScreenReaderService {
  ScreenReaderService._();

  /// Announce immediately (interrupts current speech).
  /// Use for critical actions: errors, navigation, confirmations.
  static Future<void> announce(String message) async {
    await SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Announce politely (waits for current speech to finish).
  /// Use for status updates: loading complete, content refreshed.
  static Future<void> announcePolite(String message) async {
    // Flutter doesn't distinguish assertive vs polite natively,
    // but the standard announce is treated as polite by most platforms.
    await SemanticsService.announce(message, TextDirection.ltr);
  }

  // ─── Pre-built Announcements ────────────────────────────────────────────

  /// Video playback state changes
  static Future<void> announceVideoPlay(String title) =>
      announce('Playing: $title');

  static Future<void> announceVideoPause() =>
      announce('Video paused');

  static Future<void> announceVideoEnd() =>
      announce('Video ended');

  /// Navigation
  static Future<void> announceScreenChange(String screenName) =>
      announce('Navigated to $screenName');

  static Future<void> announceTabChange(String tabName) =>
      announce('$tabName tab selected');

  /// Content actions
  static Future<void> announceLike(bool isLiked) =>
      announce(isLiked ? 'Liked' : 'Like removed');

  static Future<void> announceSubscribe(bool isSubscribed) =>
      announce(isSubscribed ? 'Subscribed' : 'Unsubscribed');

  static Future<void> announceSave(bool isSaved) =>
      announce(isSaved ? 'Saved to Watch Later' : 'Removed from Watch Later');

  /// Loading states
  static Future<void> announceLoading() =>
      announcePolite('Loading content');

  static Future<void> announceLoadComplete(int count) =>
      announcePolite('$count items loaded');

  static Future<void> announceError(String userFriendlyMessage) =>
      announce(userFriendlyMessage);

  /// Search
  static Future<void> announceSearchResults(int count, String query) =>
      announcePolite('$count results for $query');
}
