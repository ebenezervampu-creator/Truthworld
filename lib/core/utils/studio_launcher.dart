import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/cross_app_launcher.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Helper utility for opening Truthworld Studio:
/// Opens installed Truthworld Studio app if available, otherwise opens in external web browser.
class StudioLauncher {
  StudioLauncher._();

  static const String androidPackage = 'com.truthworld.studio';
  static const String customScheme = 'truthworldstudio://';
  static const String studioWebUrlProduction = 'https://studio.truthworld.in';
  static const String studioWebUrlAlternative =
      'https://www.truthworld.in/studio';
  static const String studioWebUrlFallback =
      'https://truthworld-1-studio.web.app/';

  /// Opens Truthworld Studio in installed app or web browser.
  static Future<void> openStudio({
    String? route,
    Map<String, dynamic>? arguments,
    Map<String, String>? parameters,
  }) async {
    try {
      final authService = Get.isRegistered<AuthService>()
          ? Get.find<AuthService>()
          : AuthService.to;

      // 1. Verify Authentication
      if (!authService.isAuthenticated.value) {
        AppSnackbar.warning(
          'Please sign in to access Truthworld Studio.',
          title: 'Sign In Required',
        );
        return;
      }

      // 2. Verify Channel Existence
      var channel = authService.userChannel;
      if (channel == null && !authService.hasChannel.value) {
        channel = await authService.ensureChannelLoaded();
      }

      if (channel == null && !authService.hasChannel.value) {
        Get.toNamed('/channelscreen');
        return;
      }

      // Delegate launching to CrossAppLauncher
      await CrossAppLauncher.launchFlavor(
        AppFlavor.studio,
        route: route ?? '/studio',
        arguments: arguments,
        parameters: parameters,
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'StudioLauncher.openStudio');
    }
  }
}

