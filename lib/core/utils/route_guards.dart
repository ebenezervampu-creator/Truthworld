import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';

/// Route guard middleware for protecting authenticated routes
class AuthGuard extends GetMiddleware {
  @override
  int? get priority => 9; // High priority to execute early

  AuthService get _authService => Get.find<AuthService>();

  /// List of routes that require authentication
  static const List<String> protectedRoutes = [
    '/studio',
    '/dashboard',
    '/uploadscreen',
    '/myvideos',
    '/subscriptions',
  ];

  @override
  RouteSettings? redirect(String? route) {
    if (route != null && protectedRoutes.contains(route)) {
      // Check if user is authenticated
      if (!_authService.isAuthenticated.value) {
        // Show auth required dialog
        _showAuthRequiredDialog();
        // Redirect safely back to home screen instead of returning null to avoid router crash
        return const RouteSettings(name: '/');
      }
    }
    return null;
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





