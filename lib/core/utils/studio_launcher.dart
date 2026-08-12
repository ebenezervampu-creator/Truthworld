import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper utility for opening Truthworld Studio externally as a standalone app or separate browser tab,
/// matching Truthworld's exact behavior.
class StudioLauncher {
  StudioLauncher._();

  static const String androidPackage = 'com.truthworld.studio';
  static const String customScheme = 'truthworldstudio://';
  static const String studioWebUrlProduction = 'https://studio.truthworld.in';
  static const String studioWebUrlFallback =
      'https://truthworld-1-studio.web.app/';

  /// Opens Truthworld Studio as an external app or separate tab/window.
  static Future<void> openStudio({Map<String, dynamic>? arguments}) async {
    try {
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

      // Native Mobile Platforms (Android / iOS)
      // 1. Try launching native Studio app via custom scheme or deep link
      final schemeUri = Uri.parse(customScheme);
      if (await canLaunchUrl(schemeUri)) {
        await launchUrl(
          schemeUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        return;
      }

      // 2. Try Android intent package link
      final androidPackageUri = Uri.parse('android-app://$androidPackage');
      if (await canLaunchUrl(androidPackageUri)) {
        await launchUrl(
          androidPackageUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        return;
      }

      // 3. Fallback: Launch web Studio URL in external mobile browser
      final webUri = Uri.parse(studioWebUrlProduction);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        final fallbackUri = Uri.parse(studioWebUrlFallback);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(
            fallbackUri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          Get.snackbar(
            'Truthworld Studio',
            'Could not launch Studio app. Please visit studio.truthworld.in',
            backgroundColor: const Color(0xFF222222),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching Studio app: $e');
      Get.snackbar(
        'Truthworld Studio',
        'Could not open Studio app.',
        backgroundColor: const Color(0xFF222222),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
