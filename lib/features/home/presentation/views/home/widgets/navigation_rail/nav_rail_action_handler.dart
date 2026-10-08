import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

/// Encapsulates routing, auth checking, and web URL history updates for navigation rail.
class NavRailActionHandler {
  NavRailActionHandler._();

  /// Handles tap event on a standard navigation rail item.
  static void handleNavItemTap({
    required BuildContext context,
    required int index,
    required String? route,
    required bool requiresAuth,
    required User? currentUser,
    required Function(int) onSelectItem,
    required VoidCallback onShowSignInSnackbar,
  }) {
    final isAuth = (currentUser != null && !currentUser.isAnonymous) ||
        (Get.isRegistered<AuthService>() && AuthService.to.isAuthenticated.value);
    if (requiresAuth && !isAuth) {
      onShowSignInSnackbar();
      return;
    }

    final isDashboardPage = index == HomeController.indexHome ||
        index == HomeController.indexTrending ||
        index == HomeController.indexSubscriptions ||
        index == HomeController.indexDiscover ||
        index == HomeController.indexLibrary ||
        index == HomeController.indexHistory ||
        index == HomeController.indexYourVideos ||
        index == HomeController.indexLikedVideos ||
        index == HomeController.indexDownloads ||
        index == HomeController.indexWatchLater ||
        index == HomeController.indexPlaylists ||
        index == HomeController.indexFollowingTopics ||
        index == HomeController.indexClips ||
        index == HomeController.indexExploreTopics ||
        index == HomeController.indexCommunityGuidelines ||
        index == HomeController.indexPrivacy ||
        index == HomeController.indexTerms ||
        index == HomeController.indexAbout ||
        index == HomeController.indexSettings ||
        index == HomeController.indexFeedback;

    if (isDashboardPage) {
      onSelectItem(index);
      if (kIsWeb && route != null && route.isNotEmpty) {
        WebPlatformUtils.pushUrlHistory(route);
      }
    } else {
      if (route != null && Get.currentRoute != route) {
        final isAtHome = Get.currentRoute == '/home' || Get.currentRoute == '/';
        if (index == HomeController.indexHome) {
          RouteStackObserver.navigateToHome();
        } else {
          if (isAtHome) {
            Get.toNamed(route);
          } else {
            Get.offNamed(route);
          }
        }
      }
    }
  }

  /// Handles tapping a subscribed channel row to navigate to its channel details screen.
  static Future<void> handleChannelTap({
    required Channel channel,
    required HomeController homeController,
    int subscriberCount = 0,
  }) async {
    if (homeController.isNavigating.value) return;
    homeController.isNavigating.value = true;
    try {
      await Get.toNamed(
        channel.channelRoute,
        arguments: {'channel': channel, 'subscribercount': subscriberCount},
      );
    } finally {
      homeController.isNavigating.value = false;
    }
  }
}
