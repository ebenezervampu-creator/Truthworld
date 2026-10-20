import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Clean Architecture navigation contract and abstraction layer.
///
/// Decouples UI widgets, controllers, and domain use cases from direct
/// framework router calls (GetX / Navigator), enabling mockability in tests
/// and strict boundary enforcement across architectural layers.
abstract class INavigationService {
  Future<T?>? toNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  });

  Future<T?>? offNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  });

  Future<T?>? offAllNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    Map<String, String>? parameters,
  });

  void back<T>({T? result, bool closeOverlays = false, bool canPop = true});

  bool canPop();
}

/// Concrete implementation of [INavigationService] powered by the GetX router.
class GetXNavigationService implements INavigationService {
  const GetXNavigationService();

  @override
  Future<T?>? toNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) {
    return Get.toNamed<T>(
      page,
      arguments: arguments,
      id: id,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  @override
  Future<T?>? offNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) {
    return Get.offNamed<T>(
      page,
      arguments: arguments,
      id: id,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  @override
  Future<T?>? offAllNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    Map<String, String>? parameters,
  }) {
    return Get.offAllNamed<T>(
      page,
      arguments: arguments,
      id: id,
      parameters: parameters,
    );
  }

  @override
  void back<T>({T? result, bool closeOverlays = false, bool canPop = true}) {
    Get.back<T>(
      result: result,
      closeOverlays: closeOverlays,
      canPop: canPop,
    );
  }

  @override
  bool canPop() {
    final context = Get.context;
    if (context != null) {
      return Navigator.of(context).canPop();
    }
    return false;
  }
}

/// High-level navigation facade providing type-safe routing across the TruthWorld application.
class AppNavigator {
  AppNavigator._();

  static INavigationService _service = const GetXNavigationService();

  /// Visible for testing: inject a mock navigation service.
  static void setMockService(INavigationService mockService) {
    _service = mockService;
  }

  /// Reset to standard navigation service.
  static void resetService() {
    _service = const GetXNavigationService();
  }

  // --- Primitives ---

  static Future<T?>? toNamed<T>(
    String page, {
    dynamic arguments,
    Map<String, String>? parameters,
    bool preventDuplicates = true,
  }) {
    return _service.toNamed<T>(
      page,
      arguments: arguments,
      parameters: parameters,
      preventDuplicates: preventDuplicates,
    );
  }

  static Future<T?>? offNamed<T>(
    String page, {
    dynamic arguments,
    Map<String, String>? parameters,
    bool preventDuplicates = true,
  }) {
    return _service.offNamed<T>(
      page,
      arguments: arguments,
      parameters: parameters,
      preventDuplicates: preventDuplicates,
    );
  }

  static Future<T?>? offAllNamed<T>(
    String page, {
    dynamic arguments,
    Map<String, String>? parameters,
  }) {
    return _service.offAllNamed<T>(
      page,
      arguments: arguments,
      parameters: parameters,
    );
  }

  static void back<T>({T? result, bool closeOverlays = false}) {
    _service.back<T>(result: result, closeOverlays: closeOverlays);
  }

  static bool canPop() => _service.canPop();

  // --- Type-Safe Semantic Actions ---

  /// Navigate to full-screen or permalink video player.
  static Future<void>? toWatch(
    String videoId, {
    dynamic video,
  }) {
    return _service.toNamed(
      AppRoutes.watch,
      arguments: {'video': video, 'videoId': videoId},
      parameters: {'v': videoId},
    );
  }

  /// Navigate to channel profile by channelId.
  static Future<void>? toChannel(
    String channelId, {
    dynamic channel,
  }) {
    return _service.toNamed(
      '/channel/$channelId',
      arguments: {'channel': channel},
    );
  }

  /// Navigate to channel profile by custom handle (e.g. '@truthcreator').
  static Future<void>? toChannelHandle(String handle) {
    final cleanHandle = handle.startsWith('@') ? handle : '@$handle';
    return _service.toNamed(
      '/$cleanHandle',
    );
  }

  /// Navigate to creator studio dashboard.
  static Future<void>? toStudio() {
    return _service.toNamed(AppRoutes.studio);
  }

  /// Alias for toStudio (/dashboard).
  static Future<void>? toDashboard() {
    return _service.toNamed(AppRoutes.dashboard);
  }

  /// Navigate to content creation hub.
  static Future<void>? toUpload() {
    return _service.toNamed(AppRoutes.upload);
  }

  /// Navigate to video creation screen.
  static Future<void>? toUploadVideo() {
    return _service.toNamed(AppRoutes.uploadVideo);
  }

  /// Navigate to channel creation wizard.
  static Future<void>? toChannelWizard() {
    return _service.toNamed(AppRoutes.channelWizard);
  }

  /// Navigate to premium subscription plans.
  static Future<void>? toPremium() {
    return _service.toNamed(AppRoutes.premium);
  }

  /// Navigate to user watch history.
  static Future<void>? toWatchHistory() {
    return _service.toNamed(AppRoutes.history);
  }

  /// Navigate to creator's own videos.
  static Future<void>? toMyVideos() {
    return _service.toNamed(AppRoutes.myvideos);
  }

  /// Navigate to channel subscriptions feed.
  static Future<void>? toSubscriptions() {
    return _service.toNamed(AppRoutes.subscriptions);
  }

  /// Navigate to user playlists screen.
  static Future<void>? toPlaylists() {
    return _service.toNamed(AppRoutes.playlistScreen);
  }

  /// Navigate to following discussion topics feed.
  static Future<void>? toFollowingTopics() {
    return _service.toNamed(AppRoutes.followingTopics);
  }

  /// Navigate to explore topics catalog.
  static Future<void>? toExploreTopics() {
    return _service.toNamed(AppRoutes.exploreTopics);
  }

  /// Navigate to liked videos playlist.
  static Future<void>? toLikedVideos() {
    return _service.toNamed(AppRoutes.likedVideos);
  }

  /// Navigate to bookmarks / saved community posts.
  static Future<void>? toSavedPosts() {
    return _service.toNamed(AppRoutes.savedPosts);
  }

  /// Navigate to saved comments collection.
  static Future<void>? toSavedComments() {
    return _service.toNamed(AppRoutes.savedComments);
  }

  /// Navigate to short clips feed.
  static Future<void>? toClips() {
    return _service.toNamed(AppRoutes.clips);
  }

  /// Navigate to offline downloads manager.
  static Future<void>? toDownloads() {
    return _service.toNamed(AppRoutes.downloads);
  }

  /// Navigate to trending videos list.
  static Future<void>? toTrending() {
    return _service.toNamed(AppRoutes.trending);
  }

  /// Navigate to genre/category browse page.
  static Future<void>? toCategory() {
    return _service.toNamed(AppRoutes.category);
  }

  /// Navigate to search screen.
  static Future<void>? toSearch({String? query}) {
    return _service.toNamed(
      AppRoutes.search,
      parameters: query != null ? {'q': query} : null,
    );
  }

  /// Navigate to home feed.
  static Future<void>? toHome() {
    return _service.offAllNamed(AppRoutes.home);
  }

  /// Navigate to admin portal.
  static Future<void>? toAdmin() {
    return _service.toNamed(AppRoutes.adminDashboard);
  }

  /// Navigate to advertiser campaign portal.
  static Future<void>? toAdvertiser() {
    return _service.toNamed(AppRoutes.advertiser);
  }

  /// Navigate to application settings.
  static Future<void>? toSettings() {
    return _service.toNamed(AppRoutes.settings);
  }

  /// Navigate to edit user profile screen.
  static Future<void>? toEditProfile() {
    return _service.toNamed(AppRoutes.editProfile);
  }

  /// Navigate to user onboarding wizard.
  static Future<void>? toOnboarding() {
    return _service.toNamed(AppRoutes.onboarding);
  }

  /// Navigate to notification feed.
  static Future<void>? toNotifications() {
    return _service.toNamed(AppRoutes.notifications);
  }

  /// Navigate to feedback submission page.
  static Future<void>? toFeedback() {
    return _service.toNamed(AppRoutes.feedback);
  }

  /// Navigate to about page.
  static Future<void>? toAbout() {
    return _service.toNamed(AppRoutes.about);
  }

  /// Navigate to terms of service.
  static Future<void>? toTerms() {
    return _service.toNamed(AppRoutes.terms);
  }

  /// Navigate to privacy policy.
  static Future<void>? toPrivacy() {
    return _service.toNamed(AppRoutes.privacy);
  }

  /// Navigate to community guidelines.
  static Future<void>? toCommunityGuidelines() {
    return _service.toNamed(AppRoutes.communityGuidelines);
  }

  /// Navigate to copyright complaint / DMCA screen.
  static Future<void>? toCopyrightComplaint() {
    return _service.toNamed(AppRoutes.copyrightComplaint);
  }

  /// Navigate to creator wallet.
  static Future<void>? toWallet() {
    return _service.toNamed(AppRoutes.wallet);
  }

  /// Navigate to payment checkout screen.
  static Future<void>? toCheckout() {
    return _service.toNamed(AppRoutes.checkout);
  }

  /// Navigate to topic detail thread.
  static Future<void>? toTopic(String slug) {
    return _service.toNamed('/topic/$slug');
  }

  /// Navigate to playlist details screen.
  static Future<void>? toPlaylist(String playlistId) {
    return _service.toNamed('/playlist/$playlistId');
  }
}
