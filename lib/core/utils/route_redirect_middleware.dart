import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
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
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ChannelDetailsRedirectMiddleware.redirect',
        );
      }
    }
    // No valid channel — redirect to home
    return const RouteSettings(name: '/');
  }
}

/// Middleware that redirects `/home` to `/` (or `/studio` in Studio flavor)
/// to avoid duplicate route definitions that cause controller disposal/recreation.
class HomeRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (AppFlavor.isStudio) {
      return RouteSettings(name: '/studio', arguments: Get.arguments);
    }
    return RouteSettings(name: '/', arguments: Get.arguments);
  }
}

/// Middleware that redirects `/dashboard` to `/studio` (or `/` on studio.truthworld.in).
class DashboardRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.startsWith('studio') || host.contains('studio.truthworld.in')) {
        return RouteSettings(name: '/', arguments: Get.arguments);
      }
    }
    return RouteSettings(name: '/studio', arguments: Get.arguments);
  }
}

/// Middleware that redirects `/studio` to `/` if accessed on studio.truthworld.in domain.
class StudioRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.startsWith('studio') || host.contains('studio.truthworld.in')) {
        return const RouteSettings(name: '/');
      }
    }
    return null;
  }
}

/// Middleware that redirects `/admin` or `/admin/login` to `/` if accessed on admin.truthworld.in domain.
class AdminRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.startsWith('admin') || host.contains('admin.truthworld.in')) {
        if (route == '/admin' || route == '/admin/login') {
          return const RouteSettings(name: '/');
        }
      }
    }
    return null;
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
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'PlaylistDetailRedirectMiddleware.redirect',
        );
      }

      return RouteSettings(name: '/', arguments: {'openPlaylist': playlist});
    }

    return const RouteSettings(name: '/');
  }
}

/// Middleware that redirects `/topic/:slug` to the topic's proper `/T/:slug` or `/T/:handle` route
/// *before* the page widget is built.
class TopicRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    // Prevent infinite redirect loop if we are already on a '/T/' route
    if (route != null) {
      final cleanRoute = route.split('?').first;
      if (cleanRoute.startsWith('/T/')) {
        return null;
      }
    }

    final args = Get.arguments;
    if (args != null && args is Map && args['topic'] != null) {
      final topic = args['topic'];
      try {
        final topicRoute = topic.topicRoute as String?;
        if (topicRoute != null && topicRoute.isNotEmpty) {
          if (route == topicRoute) return null;
          return RouteSettings(name: topicRoute, arguments: args);
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'TopicRedirectMiddleware.redirect',
        );
      }
    }

    // Fallback: parse route path parameter
    final uri = Uri.tryParse(route ?? '');
    if (uri != null) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2 &&
          (pathSegments[0] == 'topic' || pathSegments[0] == 'T')) {
        final slug = pathSegments[1];
        // Clean handle prefix if present
        var clean = slug.trim();
        if (clean.startsWith('T/')) {
          clean = clean.substring(2);
        } else if (clean.startsWith('t/')) {
          clean = clean.substring(2);
        }
        final targetRoute = '/T/$clean';
        if (route == targetRoute || route == '/T/$slug') {
          return null;
        }
        return RouteSettings(name: targetRoute, arguments: args);
      }
    }

    return null;
  }
}

/// Observer that keeps track of the active route stack to prevent pushing duplicate routes
/// and ensure clean stack transitions.
class RouteStackObserver extends NavigatorObserver {
  static final List<Route<dynamic>> routeStack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routeStack.add(route);
    debugPrint(
      '[RouteStackObserver] Pushed: ${route.settings.name}. Stack: ${routeStack.map((r) => r.settings.name).toList()}',
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routeStack.remove(route);
    debugPrint(
      '[RouteStackObserver] Popped: ${route.settings.name}. Stack: ${routeStack.map((r) => r.settings.name).toList()}',
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routeStack.remove(route);
    debugPrint(
      '[RouteStackObserver] Removed: ${route.settings.name}. Stack: ${routeStack.map((r) => r.settings.name).toList()}',
    );
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) routeStack.remove(oldRoute);
    if (newRoute != null) routeStack.add(newRoute);
    debugPrint(
      '[RouteStackObserver] Replaced: ${oldRoute?.settings.name} with ${newRoute?.settings.name}. Stack: ${routeStack.map((r) => r.settings.name).toList()}',
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  static bool hasRoute(String namePattern) {
    return routeStack.any(
      (route) => route.settings.name?.contains(namePattern) ?? false,
    );
  }
}

/// Middleware that protects `/admin/dashboard` routes.
/// Verifies that the user is authenticated and is the owner or has admin claim.
class AdminAuthGuardMiddleware extends GetMiddleware {
  static const List<String> authorizedOwnerEmails = [
    'ebenezervampy@towervsp.com',
    'ebenezervampu@towervsp.com',
    'ebenezervampu4@gmail.com',
    'admin@truthworld.com',
  ];

  @override
  int? get priority => 0;

  @override
  RouteSettings? redirect(String? route) {
    // 1. Check if AdminController is registered and explicitly verified as admin
    if (Get.isRegistered<AdminController>()) {
      final ctrl = Get.find<AdminController>();
      if (ctrl.isAdmin.value) {
        return null;
      }
    }

    // 2. Check persistent admin protocol session
    try {
      final storage = GetStorage();
      final session = storage.read<Map<dynamic, dynamic>>('truthworld_admin_session');
      if (session != null && session['email'] != null) {
        return null;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AdminAuthGuardMiddleware.redirect',
      );
    }

    // 3. Fallback check for owner account in Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final email = user.email!.toLowerCase();
      if (authorizedOwnerEmails.contains(email)) {
        return null;
      }
    }

    // Strict protocol gate: redirect anyone unauthenticated to login
    return const RouteSettings(name: '/admin/login');
  }
}
