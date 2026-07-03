import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

/// Middleware that redirects `/videoscreen` to `/watch?v=VIDEO_ID` *before*
/// the page widget is built — eliminating the blank-frame flash caused by
/// the old pattern of rendering `SizedBox.shrink()` + `addPostFrameCallback`.
class VideoScreenRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1; // Run early

  @override
  RouteSettings? redirect(String? route) {
    // Extract the video from arguments (callers pass {video: Video})
    final args = Get.arguments;
    if (args != null && args is Map && args['video'] != null) {
      final video = args['video'];
      final videoId = video?.id ?? '';
      if (videoId.isNotEmpty) {
        return RouteSettings(name: '/watch?v=$videoId', arguments: args);
      }
    }
    // No valid video — redirect to home
    return const RouteSettings(name: '/');
  }
}

/// Middleware that redirects `/channel-details` to the channel's proper route
/// *before* the page widget is built.
class ChannelDetailsRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final args = Get.arguments;
    if (args != null && args is Map && args['channel'] != null) {
      final channel = args['channel'];
      try {
        final channelRoute = channel.channelRoute as String?;
        if (channelRoute != null && channelRoute.isNotEmpty) {
          return RouteSettings(name: channelRoute, arguments: args);
        }
      } catch (_) {}
    }
    // No valid channel — redirect to home
    return const RouteSettings(name: '/');
  }
}

/// Middleware that redirects `/home` to `/` to avoid duplicate route definitions
/// that cause controller disposal/recreation.
class HomeRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    return RouteSettings(name: '/', arguments: Get.arguments);
  }
}

/// Middleware that redirects `/dashboard` to `/studio` to consolidate.
class DashboardRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    return RouteSettings(name: '/studio', arguments: Get.arguments);
  }
}

/// Middleware that redirects `/playlist-detail` to the home dashboard.
class PlaylistDetailRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final args = Get.arguments;
    dynamic playlist;
    if (args != null && args is Map) {
      playlist = args['playlist'] ?? args['openPlaylist'];
    }

    if (playlist != null) {
      try {
        final homeController = Get.find<HomeController>();
        homeController.navigateToPlaylistDetail(playlist);
      } catch (_) {}

      return RouteSettings(name: '/', arguments: {'openPlaylist': playlist});
    }

    return const RouteSettings(name: '/');
  }
}
