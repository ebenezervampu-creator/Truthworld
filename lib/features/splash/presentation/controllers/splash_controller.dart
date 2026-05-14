import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'dart:math' as math; // For animations

// Ã°Å¸â€Â¹ Use GetTickerProviderStateMixin to handle multiple AnimationControllers
class SplashController extends GetxController with GetTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- All your animation controllers and animations ---
  late AnimationController mainController;
  late AnimationController rotationController;
  late AnimationController particleController;
  late AnimationController pulseController;
  late AnimationController textController;

  late Animation<double> fadeInAnimation;
  late Animation<double> scaleAnimation;
  late Animation<double> rotationAnimation;
  late Animation<double> particleAnimation;
  late Animation<double> pulseAnimation;
  late Animation<double> textSlideAnimation;
  late Animation<double> textOpacityAnimation;

  // This is the GetX equivalent of initState()
  @override
  void onInit() {
    super.onInit();
    _initializeAnimations(); // Set up animations
    _startAnimations(); // Start them
    _handleAuthCheck(); // Run auth logic
  }

  // This is the GetX equivalent of dispose()
  @override
  void onClose() {
    mainController.dispose();
    rotationController.dispose();
    particleController.dispose();
    pulseController.dispose();
    textController.dispose();
    super.onClose();
  }

  /// Initializes all animation controllers and animations
  void _initializeAnimations() {
    // `vsync: this` works because of `GetTickerProviderStateMixin`
    mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1),
    );
    particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Initialize animations
    fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: mainController, curve: Curves.easeInOut));
    scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: mainController, curve: Curves.elasticOut),
    );
    rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: rotationController, curve: Curves.easeInOut),
    );
    particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: particleController, curve: Curves.easeOut),
    );
    pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
    textSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: textController, curve: Curves.easeOutBack),
    );
    textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: textController, curve: Curves.easeIn));
  }

  /// Starts all animations with their delays
  void _startAnimations() async {
    particleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    mainController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    rotationController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    textController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    pulseController.repeat(reverse: true);
  }

  /// Ã°Å¸â€Â¹ Runs auth logic AND min animation time in parallel
  Future<void> _handleAuthCheck() async {
    // This is the *minimum* time the splash screen will be visible
    final minAnimationTime = Future.delayed(const Duration(milliseconds: 1500));

    // This runs the auth check (including web redirect)
    final authCheck = _performAuthLogic();

    // Wait for BOTH the minimum time AND the auth check to complete
    await Future.wait([minAnimationTime, authCheck]);

    // After both are done, get the navigation route from the auth check
    final String? route = await authCheck;

    // If the auth check returned a route (and wasn't handled by redirect),
    // navigate to it.
    if (route != null) {
      Get.offAllNamed(route);
    }
  }

  /// Performs auth logic and returns the route to navigate to.
  /// Returns `null` if navigation was already handled (e.g., by redirect).
  Future<String?> _performAuthLogic() async {
    // Step 1: Check for a web redirect.
    bool redirectHandled = await _checkRedirectResult();

    // If redirect was handled, it already navigated. Return null.
    if (redirectHandled) return null;

    // Step 2: Check if user is already logged in
    try {
      final authService = Get.find<AuthService>();
      if (authService.isAuthenticated.value) {
        debugPrint('[SplashController] User is authenticated, navigating to /home');
        return '/home';
      } else {
        debugPrint('[SplashController] User not authenticated, navigating to /');
        return '/'; // Go to home/login screen
      }
    } catch (e) {
      debugPrint('[SplashController] Error checking auth: $e');
      return '/'; // Default to home if error
    }
  }

  /// Ã°Å¸â€Â¹ The logic from the previous step, now inside the controller
  /// Checks for a web redirect result and returns `true` if handled.
  Future<bool> _checkRedirectResult() async {
    if (kIsWeb) {
      try {
        final userCredential = await _auth.getRedirectResult();

        if (userCredential.user != null) {
          // Removed redundant _handleUserData(user) call as AuthService now handles this via its auth state stream

          Get.snackbar(
            'Welcome back!',
            'Successfully signed in as ${userCredential.user?.displayName ?? 'User'}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.colors.success,
            colorText: AppTheme.colors.textPrimary,
          );

          Get.offAllNamed('/home'); // Navigate
          return true; // IMPORTANT: Signal that we handled it
        }
      } catch (e) {
        debugPrint('Error getting redirect result: $e');
        Get.snackbar(
          'Sign In Error',
          'Failed to complete sign-in: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.colors.primary,
          colorText: AppTheme.colors.textPrimary,
        );
      }
    }
    return false; // No redirect was handled
  }

}





