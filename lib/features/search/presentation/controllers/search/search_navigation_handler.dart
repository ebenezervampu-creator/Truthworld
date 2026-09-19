import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Handles navigation and analytics logging when a search result is tapped.
class SearchNavigationHandler {
  /// Navigate to appropriate view screen when user taps a search result
  static Future<void> handleResultTapped(
    SearchResult result, {
    required RxBool isNavigating,
  }) async {
    if (isNavigating.value) return;
    isNavigating.value = true;

    debugPrint(
      '👆 [Search] User tapped: ${result.title} (Type: ${result.type}, ID: ${result.id})',
    );

    try {
      final collection = result.type == ResultType.video
          ? 'videos'
          : (result.type == ResultType.channel
                ? 'channels'
                : (result.type == ResultType.playlist
                      ? 'playlists'
                      : 'topics'));

      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(result.id)
          .get();

      if (!doc.exists) {
        final typeName = result.type.toString().split('.').last;
        AppSnackbar.warning(
          '${typeName.capitalizeFirst} is no longer available.',
        );
        return;
      }

      // Track tap to analytics
      await FirebaseAnalytics.instance.logEvent(
        name: 'search_result_tapped',
        parameters: {
          'result_id': result.id,
          'result_title': result.title,
          'result_type': result.type.toString(),
        },
      );

      // Navigate based on result type
      switch (result.type) {
        case ResultType.video:
          final video = Video.fromDocumentSnapshot(doc);
          MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
        case ResultType.channel:
          final channel = Channel.fromDocumentSnapshot(doc);
          Get.toNamed(channel.channelRoute, arguments: {'channel': channel});
        case ResultType.playlist:
          final playlist = PlaylistModel.fromDocumentSnapshot(doc);
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            homeController.navigateToPlaylistDetail(playlist);
          } else {
            Get.toNamed('/', arguments: {'openPlaylist': playlist});
          }
        case ResultType.topic:
          final topic = Topic.fromDocumentSnapshot(doc);
          if (!topic.isValidTopic || topic.videoCount <= 0) {
            AppSnackbar.warning('This topic is currently unavailable or has no videos.');
            return;
          }
          Get.toNamed(topic.topicRoute, arguments: {'topic': topic});
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'SearchNavigationHandler.handleResultTapped');
      AppSnackbar.error('Unable to open this result. Please try again.');
    } finally {
      isNavigating.value = false;
    }
  }
}
