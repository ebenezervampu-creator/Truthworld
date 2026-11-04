import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/cross_app_launcher.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const String playStoreMarketUrl =
      'market://details?id=com.truthworld.studio';
  static const String playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=com.truthworld.studio';

  /// Checks whether Truthworld Studio native app is installed on this device.
  static Future<bool> isStudioInstalled() async {
    return CrossAppLauncher.isFlavorInstalled(AppFlavor.studio);
  }

  /// Opens Google Play Store or web download page for Truthworld Studio app.
  static Future<void> downloadStudioApp() async {
    try {
      final marketUri = Uri.parse(playStoreMarketUrl);
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
      final playStoreUri = Uri.parse(playStoreWebUrl);
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        return;
      }
      final webUri = Uri.parse(studioWebUrlProduction);
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'StudioLauncher.downloadStudioApp');
      AppSnackbar.error(
        'Unable to open the download page. Please try again later.',
      );
    }
  }

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
      AppSnackbar.error(
        'Unable to open Truthworld Studio. Please check your connection and try again.',
      );
    }
  }
}

