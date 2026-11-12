import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link/deep_link_url_parser.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

/// Middleware that redirects `/videoscreen` to `/watch?v=VIDEO_ID` *before*
/// the page widget is built — eliminating the blank-frame flash caused by
/// the old pattern of rendering `SizedBox.shrink()` + `addPostFrameCallback`.
class VideoScreenRedirectMiddleware extends GetMiddleware {
  @override
  int? get priority => 1; // Run early

  @override
  RouteSettings? redirect(String? route) {
    final args = Get.arguments;
    var videoId = '';
    if (args != null && args is Map) {
      final video = args['video'];
      videoId = (video != null ? video.id as String? : null) ??
          args['videoId'] as String? ??
          args['targetVideoId'] as String? ??
          args['video_id'] as String? ??
          args['id'] as String? ??
          '';
    }
    if (videoId.isEmpty) {
      videoId = Get.parameters['v'] ??
          Get.parameters['videoId'] ??
          Get.parameters['id'] ??
          '';
    }
    if (videoId.isNotEmpty) {
      return RouteSettings(name: '/watch?v=$videoId', arguments: args);
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

/// Middleware that intercepts catch-all creator handle route (`/:handle`).
/// Strictly prevents hijacking video, watch, query strings, or reserved platform routes,
/// and redirects to the proper video or core route instead of failing on ChannelDetailsPage.
class HandleRouteGuardMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final handle = (Get.parameters['handle'] ?? '').trim();
    if (handle.isEmpty) return null;

    final handleLower = handle.toLowerCase();

    // 1. If handle is in reserved routes list, do not treat as channel handle
    if (DeepLinkUrlParser.reservedRoutes.contains(handleLower)) {
      return RouteSettings(name: '/$handleLower', arguments: Get.arguments);
    }

    // 2. If handle contains watch, video, or query params (e.g. watch?v=ID or watch%3Fv=ID)
    if (handleLower.startsWith('watch') ||
        handleLower.startsWith('video') ||
        handleLower.contains('v=') ||
        handleLower.contains('%3fv=')) {
      String? videoId;
      if (handle.contains('v=')) {
        final parts = handle.split('v=');
        if (parts.length > 1) {
          videoId = parts[1].split('&')[0];
        }
      }
      if (videoId != null && videoId.isNotEmpty) {
        return RouteSettings(
          name: '/watch?v=$videoId',
          arguments: Get.arguments,
        );
      }
      return const RouteSettings(name: '/');
    }

    // 3. If handle contains invalid handle characters like ? or = or %
    if (handle.contains('?') || handle.contains('=') || handle.contains('%')) {
      return const RouteSettings(name: '/');
    }

    return null; // Valid channel handle - allow proceeding to ChannelDetailsPage
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
    if (route == null) return null;
    final normalizedRoute = route.split('?').first.replaceAll(RegExp('/+'), '/');

    // Prevent infinite redirect loop if we are already on a canonical '/T/' route
    if (normalizedRoute.startsWith('/T/') && !route.startsWith('//')) {
      return null;
    }

    final args = Get.arguments;
    if (args != null && args is Map && args['topic'] != null) {
      final topic = args['topic'];
      try {
        final topicRoute = topic.topicRoute as String?;
        if (topicRoute != null && topicRoute.isNotEmpty) {
          if (normalizedRoute == topicRoute && !route.startsWith('//')) return null;
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
    final uri = Uri.tryParse(normalizedRoute);
    if (uri != null) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2 &&
          (pathSegments[0] == 'topic' || pathSegments[0] == 'T' || pathSegments[0] == 'topics' || pathSegments[0] == 't')) {
        final slug = pathSegments[1];
        // Clean handle prefix if present
        var clean = slug.trim();
        while (clean.startsWith('@')) {
          clean = clean.substring(1).trim();
        }
        if (clean.toLowerCase().startsWith('t/')) {
          clean = clean.substring(2).trim();
        }
        while (clean.startsWith('/')) {
          clean = clean.substring(1).trim();
        }
        final targetRoute = '/T/$clean';
        if (normalizedRoute == targetRoute && !route.startsWith('//')) {
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

  /// Safely navigates to Home without duplicate controller recreation or route stack churn.
  /// If Home is already in the Navigator history, pops back to it (`Get.until`).
  /// Otherwise, replaces the stack with Home (`Get.offAllNamed('/')`).
  static void navigateToHome() {
    final currentRoute = Get.currentRoute;
    final isAtHome = currentRoute == '/' || currentRoute == '/home';

    if (isAtHome) {
      if (Get.isRegistered<HomeController>()) {
        final homeCtrl = Get.find<HomeController>();
        if (homeCtrl.sideNavSelectedIndex.value != HomeController.indexHome) {
          homeCtrl.onSideNavItemSelect(HomeController.indexHome);
          return;
        } else {
          // Already on Home feed: scroll to top
          if (homeCtrl.scrollController.hasClients) {
            if (homeCtrl.scrollController.offset > 0) {
              homeCtrl.scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
              return;
            }
          }
        }
      }
      return;
    }

    final hasHomeInStack = routeStack.isNotEmpty &&
        routeStack.any((r) =>
            r.settings.name == '/' ||
            r.settings.name == '/home' ||
            (r.isFirst && !(r.settings.name?.contains('watch') ?? false)));

    if (hasHomeInStack && routeStack.length > 1) {
      Get.until((route) =>
          route.settings.name == '/' ||
          route.settings.name == '/home' ||
          route.isFirst);
    } else {
      Get.offAllNamed('/');
    }
  }

  static String _normalizedPath(String? routeName) {
    if (routeName == null || routeName.isEmpty) return '';
    final parsed = Uri.tryParse(routeName);
    final rawPath = parsed != null ? parsed.path : routeName.split('?').first;
    return rawPath.toLowerCase().replaceAll(RegExp('/+'), '/');
  }

  static bool _isStudioHost() {
    if (!kIsWeb) return false;
    final host = Uri.base.host.toLowerCase();
    return host.startsWith('studio') || host.contains('studio.truthworld.in');
  }

  /// Returns `true` when [routeName] targets the Creator Studio dashboard shell.
  static bool isStudioDashboardPath(String? routeName) {
    final path = _normalizedPath(routeName);
    if (path.isEmpty) return false;
    if (path == '/studio' ||
        path == '/dashboard' ||
        path == '/studio/chapters' ||
        path == '/studio/trash' ||
        path == '/studio/drafts' ||
        path == '/studio/community') {
      return true;
    }
    if ((path == '/' || path == '/home') &&
        (AppFlavor.isStudio || _isStudioHost())) {
      return true;
    }
    return false;
  }

  /// Predicate matching Creator Studio dashboard routes in the Navigator stack.
  static bool isStudioDashboardRoute(Route<dynamic> route) {
    return isStudioDashboardPath(route.settings.name);
  }

  static void _syncStudioReturnState({dynamic arguments}) {
    if (Get.isRegistered<DashboardController>()) {
      final dashboardCtrl = Get.find<DashboardController>();
      if (!dashboardCtrl.isDisposed &&
          arguments is Map &&
          arguments['tab'] != null) {
        final tabArg = arguments['tab'];
        if (tabArg is int && tabArg >= 1 && tabArg <= 20) {
          if (tabArg == 18 && !dashboardCtrl.isChannelMonetizationActive) {
            dashboardCtrl.setSelectedIndex(1);
          } else {
            dashboardCtrl.setSelectedIndex(tabArg);
          }
        }
      }
    }
    if (Get.isRegistered<DashboardViewController>()) {
      final viewCtrl = Get.find<DashboardViewController>();
      if (!viewCtrl.isDisposed) {
        viewCtrl.ensureAnimationsVisible();
      }
    }
  }

  /// Safely navigates back to Creator Studio without duplicating `/studio` routes
  /// or triggering GetX's `isDirty` controller-disposal race.
  ///
  /// When a Studio dashboard route is already in [routeStack], pops child routes
  /// back to it via `Get.until`; otherwise replaces the stack with `/studio`.
  static void navigateToStudio({
    dynamic arguments,
    Map<String, String>? parameters,
  }) {
    if (routeStack.isNotEmpty) {
      if (isStudioDashboardRoute(routeStack.last)) {
        _syncStudioReturnState(arguments: arguments);
        return;
      }
      if (routeStack.any(isStudioDashboardRoute)) {
        Get.until(isStudioDashboardRoute);
        _syncStudioReturnState(arguments: arguments);
        return;
      }
    } else if (isStudioDashboardPath(Get.currentRoute)) {
      _syncStudioReturnState(arguments: arguments);
      return;
    }

    Get.offAllNamed<dynamic>(
      '/studio',
      arguments: arguments,
      parameters: parameters,
    );
  }
}

/// Middleware that protects `/admin/dashboard` routes.
/// Verifies that the user is authenticated and is the owner or has admin claim.
class AdminAuthGuardMiddleware extends GetMiddleware {
  static const List<String> authorizedOwnerEmails = [
    'hello@truthworld.in',
    'ebenezervampu4@gmail.com',
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
