import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';

/// Route guard middleware for protecting authenticated routes
class AuthGuard extends GetMiddleware {
  @override
  int? get priority => 9; // High priority to execute early

  final AuthService _authService = Get.find<AuthService>();

  /// List of routes that require authentication
  static const List<String> protectedRoutes = [
    '/upload',
    '/upload/video',
    '/upload/community',
    '/uploadscreen', // Backward compatibility
    '/myvideos',
    '/settings',
    '/subscriptions',
  ];

  @override
  RouteSettings? redirect(String? route) {
    if (route == '/studio' || route == '/dashboard') {
      return null;
    }

    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final isStudio =
          host.startsWith('studio') ||
          host.contains('studio') ||
          Uri.base.queryParameters.containsKey('studio');

      if (isStudio) {
        if (route == '/studio/auth' ||
            (route != null && route.contains('studio/auth'))) {
          return const RouteSettings(name: '/');
        }
      }
    }

    final cleanRoute = route?.split('?').first;
    final isProtected =
        (cleanRoute != null && protectedRoutes.contains(cleanRoute)) ||
        (route != null && protectedRoutes.contains(route));

    if (isProtected && !_authService.isAuthenticated.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAuthRequiredDialog();
      });
      return const RouteSettings(name: '/');
    }

    return null;
  }

  @override
  GetPage? onPageCalled(GetPage? page) {
    // Protection redirect handled in redirect() to prevent showing dialog during initial route build
    return page;
  }

  /// Show dialog informing user to sign in
  static void _showAuthRequiredDialog() {
    final context = Get.context;
    if (context == null || !context.mounted) return;
    if (Get.isDialogOpen ?? false) return;

    unawaited(
      Get.dialog(
        AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text('You need to sign in to access this page.'),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                unawaited(Get.offNamed('/'));
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route guard to prevent navigating to channel creation if they already have one
class ChannelCreationGuard extends GetMiddleware {
  @override
  int? get priority => 8;

  final AuthService _authService = Get.find<AuthService>();

  @override
  RouteSettings? redirect(String? route) {
    if (_authService.isAuthenticated.value &&
        (_authService.hasChannel.value || _authService.userChannel != null)) {
      if (kIsWeb) {
        final host = Uri.base.host.toLowerCase();
        if (host.startsWith('studio') || host.contains('studio.truthworld.in')) {
          return const RouteSettings(name: '/');
        }
      }
      return const RouteSettings(name: '/studio');
    }
    return null;
  }
}

/// Utility class for route protection
class RouteProtection {
  /// Check if user is authenticated before navigating to protected route
  static Future<bool> checkAuthBeforeNavigate(String routeName) async {
    final authService = Get.find<AuthService>();

    if (!authService.isAuthenticated.value) {
      // User is not authenticated
      AuthGuard._showAuthRequiredDialog();
      return false;
    }

    return true;
  }

  /// Navigate to protected route with auth check
  static Future<dynamic>? navigateProtected(
    String routeName, {
    dynamic arguments,
  }) async {
    if (await checkAuthBeforeNavigate(routeName)) {
      return Get.toNamed(routeName, arguments: arguments);
    }
    return null;
  }
}
