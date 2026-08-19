import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper utility for opening Truthworld Studio:
/// Opens installed Truthworld Studio app if available, otherwise opens in external web browser.
class StudioLauncher {
  StudioLauncher._();

  static const String androidPackage = 'com.truthworld.studio';
  static const String customScheme = 'truthworldstudio://';
  static const String studioWebUrlProduction = 'https://studio.truthworld.in';
  static const String studioWebUrlFallback =
      'https://truthworld-1-studio.web.app/';

  /// Opens Truthworld Studio in installed app or web browser.
  static Future<void> openStudio({Map<String, dynamic>? arguments}) async {
    try {
      final authService = Get.isRegistered<AuthService>()
          ? Get.find<AuthService>()
          : AuthService.to;

      // 1. Verify Authentication
      if (!authService.isAuthenticated.value) {
        if (Get.context != null) {
          Get.snackbar(
            'Sign In Required',
            'Please sign in to access Truthworld Studio.',
            backgroundColor: const Color(0xFF222222),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }

      // 2. Verify Channel Existence
      if (!authService.hasChannel.value && authService.userChannel == null) {
        Get.toNamed('/channelscreen');
        return;
      }

      // 3. Web Platform Execution
      if (kIsWeb) {
        final origin = Uri.base.origin;
        final isLocalhost =
            origin.contains('localhost') || origin.contains('127.0.0.1');
        final studioUrl = isLocalhost
            ? '$origin/studio'
            : studioWebUrlProduction;

        final uri = Uri.parse(studioUrl);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );

        if (!launched) {
          final fallbackUri = Uri.parse(studioWebUrlFallback);
          await launchUrl(
            fallbackUri,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          );
        }
        return;
      }

      // 4. Native Platforms (Android / iOS / Windows / Desktop)
      // First try launching installed Studio app via custom scheme or deep link
      final schemeUri = Uri.parse(customScheme);
      if (await canLaunchUrl(schemeUri)) {
        final launched = await launchUrl(
          schemeUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (launched) return;
      }

      final androidPackageUri = Uri.parse('android-app://$androidPackage');
      if (await canLaunchUrl(androidPackageUri)) {
        final launched = await launchUrl(
          androidPackageUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (launched) return;
      }

      final androidIntentUri = Uri.parse(
        'intent://open#Intent;package=$androidPackage;scheme=truthworldstudio;end',
      );
      if (await canLaunchUrl(androidIntentUri)) {
        final launched = await launchUrl(
          androidIntentUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (launched) return;
      }

      // 5. App is not installed -> Fallback: Open in external web browser
      final webUri = Uri.parse(studioWebUrlProduction);
      final launchedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launchedWeb) {
        final fallbackUri = Uri.parse(studioWebUrlFallback);
        await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Error launching Studio app: $e');
      try {
        final webUri = Uri.parse(studioWebUrlProduction);
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }
  }
}
