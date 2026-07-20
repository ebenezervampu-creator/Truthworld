import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';

/// Route guard middleware for protecting authenticated routes
class AuthGuard extends GetMiddleware {
  @override
  int? get priority => 9; // High priority to execute early

  final AuthService _authService = Get.find<AuthService>();

  @override
  RouteSettings? redirect(String? route) {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final isStudio = host.startsWith('studio') ||
          Uri.base.queryParameters.containsKey('studio');

      if (isStudio) {
        if (route == '/studio' || route == '/studio/auth' || route == '/dashboard' || (route != null && route.contains('studio/auth'))) {
          return const RouteSettings(name: '/');
        }
      }
    }
    return null;
  }

  /// List of routes that require authentication
  static const List<String> protectedRoutes = [
    '/studio',
    '/dashboard',
    '/uploadscreen',
    '/myvideos',
    '/settings',
    '/subscriptions',
  ];

  @override
  GetPage? onPageCalled(GetPage? page) {
    // Check if current route is protected
    if (page != null && protectedRoutes.contains(page.name)) {
      // Check if user is authenticated
      if (!_authService.isAuthenticated.value) {
        // Show auth required dialog
        _showAuthRequiredDialog();
        // Return null to prevent navigation
        return null;
      }
    }
    return page;
  }

  /// Show dialog informing user to sign in
  static void _showAuthRequiredDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('You need to sign in to access this page.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              Get.offNamed('/');
            },
            child: const Text('Sign In'),
          ),
        ],
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
    if (_authService.isAuthenticated.value && _authService.hasChannel.value) {
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





