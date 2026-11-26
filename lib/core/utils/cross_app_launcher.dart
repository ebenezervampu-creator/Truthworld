import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized Cross-App Deep Link Launcher for all four TruthWorld applications:
/// 1. Consumer App (`com.truthworld.app` / `truthworld://` / `https://www.truthworld.in`)
/// 2. Creator Studio (`com.truthworld.studio` / `truthworldstudio://` / `https://studio.truthworld.in`)
/// 3. Admin & Moderation (`com.truthworld.admin` / `truthworldadmin://` / `https://admin.truthworld.in`)
/// 4. Advertiser Portal (`com.truthworld.advertiser` / `truthworldads://` / `https://ads.truthworld.in`)
class CrossAppLauncher {
  const CrossAppLauncher._();

  // Package names for Android
  static const String consumerPackage = 'com.truthworld.app';
  static const String studioPackage = 'com.truthworld.studio';
  static const String adminPackage = 'com.truthworld.admin';
  static const String advertiserPackage = 'com.truthworld.advertiser';
  static const String dubbingPackage = 'com.truthworld.dubbing';

  // Custom URI schemes
  static const String consumerScheme = 'truthworld';
  static const String studioScheme = 'truthworldstudio';
  static const String adminScheme = 'truthworldadmin';
  static const String advertiserScheme = 'truthworldads';
  static const String dubbingScheme = 'truthworlddubbing';

  // Web production URLs
  static const String consumerWebProduction = 'https://www.truthworld.in';
  static const String consumerWebFallback = 'https://truthworld.in';

  static const bool _isStaging =
      String.fromEnvironment('FIREBASE_ENV') == 'staging';
  static const String _stagingProjectId = String.fromEnvironment(
    'STAGING_PROJECT_ID',
    defaultValue: 'truthworld-staging',
  );

  static const String studioWebProduction = 'https://studio.truthworld.in';
  static const String studioWebAlternative = 'https://www.truthworld.in/studio';
  static const String studioWebFallback = _isStaging
      ? 'https://$_stagingProjectId-studio.web.app/'
      : 'https://truthworld-1-studio.web.app/';

  static const String adminWebProduction = 'https://admin.truthworld.in';
  static const String adminWebFallback = _isStaging
      ? 'https://$_stagingProjectId-admin.web.app/'
      : 'https://truthworld-1-admin.web.app/';

  static const String advertiserWebProduction = 'https://ads.truthworld.in';
  static const String advertiserWebFallback = _isStaging
      ? 'https://$_stagingProjectId-ads.web.app/'
      : 'https://truthworld-1-ads.web.app/';

  static const String dubbingWebProduction = 'https://dubbing.truthworld.in';
  static const String dubbingWebAlternative = 'https://www.truthworld.in/dubbing';
  static const String dubbingWebFallback = _isStaging
      ? 'https://$_stagingProjectId-dubbing.web.app/'
      : 'https://truthworld-1-dubbing.web.app/';

  /// Returns the Android package name for the target [flavor].
  static String getPackageName(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.studio:
        return studioPackage;
      case AppFlavor.admin:
        return adminPackage;
      case AppFlavor.advertiser:
        return advertiserPackage;
      case AppFlavor.dubbing:
        return dubbingPackage;
      case AppFlavor.app:
        return consumerPackage;
    }
  }

  /// Returns the custom URL scheme (without '://') for the target [flavor].
  static String getScheme(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.studio:
        return studioScheme;
      case AppFlavor.admin:
        return adminScheme;
      case AppFlavor.advertiser:
        return advertiserScheme;
      case AppFlavor.dubbing:
        return dubbingScheme;
      case AppFlavor.app:
        return consumerScheme;
    }
  }

  /// Returns the production web portal base URL for the target [flavor].
  static String getWebProductionUrl(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.studio:
        return studioWebProduction;
      case AppFlavor.admin:
        return adminWebProduction;
      case AppFlavor.advertiser:
        return advertiserWebProduction;
      case AppFlavor.dubbing:
        return dubbingWebProduction;
      case AppFlavor.app:
        return consumerWebProduction;
    }
  }

  /// Returns the alternative web portal URL for the target [flavor] if defined.
  static String? getWebAlternativeUrl(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.studio:
        return studioWebAlternative;
      case AppFlavor.dubbing:
        return dubbingWebAlternative;
      case AppFlavor.admin:
      case AppFlavor.advertiser:
      case AppFlavor.app:
        return null;
    }
  }

  /// Returns the fallback web portal URL for the target [flavor].
  static String getWebFallbackUrl(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.studio:
        return studioWebFallback;
      case AppFlavor.admin:
        return adminWebFallback;
      case AppFlavor.advertiser:
        return advertiserWebFallback;
      case AppFlavor.dubbing:
        return dubbingWebFallback;
      case AppFlavor.app:
        return consumerWebFallback;
    }
  }

  /// Launches the target Truthworld product flavor natively or via web fallback.
  static Future<bool> launchFlavor(
    AppFlavor targetFlavor, {
    String? route,
    Map<String, dynamic>? arguments,
    Map<String, String>? parameters,
  }) async {
    try {
      final cleanRoute = _normalizeRoute(route, arguments, parameters);
      final scheme = getScheme(targetFlavor);
      final package = getPackageName(targetFlavor);
      final webBase = getWebProductionUrl(targetFlavor);
      final webAlt = getWebAlternativeUrl(targetFlavor);
      final webFallback = getWebFallbackUrl(targetFlavor);

      // ── Web Platform Execution ──
      if (kIsWeb) {
        final origin = Uri.base.origin;
        final isLocalhost =
            origin.contains('localhost') || origin.contains('127.0.0.1');

        String targetUrl;
        if (isLocalhost) {
          // In localhost dev, append path to current origin
          targetUrl = '$origin$cleanRoute';
        } else if (targetFlavor == AppFlavor.studio &&
            (origin.contains('truthworld.in') || origin.contains('truthworld.app'))) {
          // When already navigating on truthworld web app, open studio at /studio
          // (https://www.truthworld.in/studio) to keep active user credentials seamless
          targetUrl = '$origin/studio';
        } else {
          targetUrl = '$webBase$cleanRoute';
        }

        final uri = Uri.parse(targetUrl);
        var launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );

        if (!launched && webAlt != null) {
          final altUri = Uri.parse('$webAlt$cleanRoute');
          launched = await launchUrl(
            altUri,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          );
        }

        if (!launched) {
          final fallbackUri = Uri.parse('$webFallback$cleanRoute');
          return await launchUrl(
            fallbackUri,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          );
        }
        return true;
      }

      // ── Native Mobile / Desktop Execution ──
      // 1. Try Custom URL Scheme: <scheme>://<path>
      final relativePath = cleanRoute.startsWith('/') ? cleanRoute.substring(1) : cleanRoute;
      final customUri = Uri.parse('$scheme://$relativePath');
      if (await canLaunchUrl(customUri)) {
        final launched = await launchUrl(
          customUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (launched) return true;
      }

      // 2. Android native app protocol
      final androidAppUri = Uri.parse('android-app://$package');
      if (await canLaunchUrl(androidAppUri)) {
        final launched = await launchUrl(
          androidAppUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (launched) return true;
      }

      // 3. Android Intent URI format
      final intentUri = Uri.parse(
        'intent://$relativePath#Intent;package=$package;scheme=$scheme;end',
      );
      if (await canLaunchUrl(intentUri)) {
        final launched = await launchUrl(
          intentUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (launched) return true;
      }

      // 4. Standalone app is not installed -> Fall back to external web browser
      final webUri = Uri.parse('$webBase$cleanRoute');
      var launchedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launchedWeb && webAlt != null) {
        final altUri = Uri.parse('$webAlt$cleanRoute');
        launchedWeb = await launchUrl(
          altUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launchedWeb) {
        final fallbackUri = Uri.parse('$webFallback$cleanRoute');
        return await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      }
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'CrossAppLauncher.launchFlavor.${targetFlavor.name}',
      );
      return false;
    }
  }

  /// Checks whether the target flavor's standalone mobile app is installed on the device.
  static Future<bool> isFlavorInstalled(AppFlavor targetFlavor) async {
    if (kIsWeb) return false;
    try {
      final scheme = getScheme(targetFlavor);
      final customUri = Uri.parse('$scheme://studio');
      if (await canLaunchUrl(customUri)) {
        return true;
      }
      final rootUri = Uri.parse('$scheme://');
      if (await canLaunchUrl(rootUri)) {
        return true;
      }
      final package = getPackageName(targetFlavor);
      final androidAppUri = Uri.parse('android-app://$package');
      if (await canLaunchUrl(androidAppUri)) {
        return true;
      }
    } catch (_) {
      // Platform handler not present or not supported (e.g. unit test runtime)
      return false;
    }
    return false;
  }

  /// Builds a clean route string including query parameters from args and params.
  static String _normalizeRoute(
    String? route,
    Map<String, dynamic>? arguments,
    Map<String, String>? parameters,
  ) {
    var baseRoute = (route != null && route.isNotEmpty) ? route : '/';
    if (!baseRoute.startsWith('/')) {
      baseRoute = '/$baseRoute';
    }

    final queryMap = <String, String>{};

    // Copy parameters if provided
    if (parameters != null) {
      queryMap.addAll(parameters);
    }

    // Extract relevant primitives from arguments
    if (arguments != null) {
      for (final entry in arguments.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val == null) continue;
        if (key == 'video' || key == 'channel' || key == 'playlist') continue;
        if (val is String && val.isNotEmpty && !queryMap.containsKey(key)) {
          queryMap[key] = val;
        } else if (val is num && !queryMap.containsKey(key)) {
          queryMap[key] = val.toString();
        } else if (val is bool && !queryMap.containsKey(key)) {
          queryMap[key] = val.toString();
        }
      }
    }

    if (queryMap.isEmpty) {
      return baseRoute;
    }

    final uri = Uri.parse(baseRoute);
    final mergedParams = Map<String, String>.from(uri.queryParameters)..addAll(queryMap);
    return uri.replace(queryParameters: mergedParams).toString();
  }
}
