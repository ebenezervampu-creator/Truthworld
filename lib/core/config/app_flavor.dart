import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show appFlavor;

/// Identifies which product flavor this binary was built for.
///
/// Each value maps 1-to-1 with an Android [productFlavor] /
/// iOS build scheme of the same name and its corresponding
/// `lib/main_<flavor>.dart` entry-point file.
enum AppFlavor {
  /// The default consumer-facing Truthworld app.
  app,

  /// Creator/Studio dashboard (Truthworld Studio).
  studio,

  /// Internal administration panel (Truthworld Admin).
  admin,

  /// Advertiser self-serve portal (Truthworld Advertiser).
  advertiser;

  /// Holds the current flavor set explicitly during bootstrap.
  static AppFlavor current = AppFlavor.app;

  /// Returns the dynamically determined active flavor.
  /// Checks explicit [current], then Flutter's native [appFlavor],
  /// then web URL hostname/query parameters.
  static AppFlavor get active {
    if (current != AppFlavor.app) {
      return current;
    }
    if (appFlavor != null && appFlavor!.isNotEmpty) {
      final flavorLower = appFlavor!.toLowerCase();
      if (flavorLower == 'studio') return AppFlavor.studio;
      if (flavorLower == 'admin') return AppFlavor.admin;
      if (flavorLower == 'advertiser') return AppFlavor.advertiser;
      if (flavorLower == 'app') return AppFlavor.app;
    }
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final uriStr = Uri.base.toString().toLowerCase();
      if (host.startsWith('admin') ||
          host.contains('admin') ||
          uriStr.contains('admin') ||
          Uri.base.queryParameters.containsKey('admin')) {
        return AppFlavor.admin;
      }
      if (host.startsWith('studio') ||
          host.contains('studio') ||
          uriStr.contains('studio') ||
          Uri.base.queryParameters.containsKey('studio')) {
        return AppFlavor.studio;
      }
      if (host.startsWith('advertiser') ||
          host.contains('advertiser') ||
          uriStr.contains('advertiser') ||
          Uri.base.queryParameters.containsKey('advertiser')) {
        return AppFlavor.advertiser;
      }
    }
    return current;
  }

  /// Whether the app is currently running in Creator Studio mode.
  static bool get isStudio => active == AppFlavor.studio;

  /// Whether the app is currently running in Admin mode.
  static bool get isAdmin => active == AppFlavor.admin;

  /// Whether the app is currently running in Advertiser mode.
  static bool get isAdvertiser => active == AppFlavor.advertiser;

  /// Whether the app is currently running in standard Consumer mode.
  static bool get isConsumer => active == AppFlavor.app;

  /// Returns the initial route that the [AppFlavor] should
  /// land on when running as a native mobile binary.
  String get initialRoute {
    switch (this) {
      case AppFlavor.studio:
        return '/studio';
      case AppFlavor.admin:
        return '/admin/login';
      case AppFlavor.advertiser:
        return '/advertiser';
      case AppFlavor.app:
        return '/';
    }
  }

  /// Human-readable title shown in the OS task-switcher.
  String get appTitle {
    switch (this) {
      case AppFlavor.studio:
        return 'Truthworld Studio';
      case AppFlavor.admin:
        return 'Truthworld Admin';
      case AppFlavor.advertiser:
        return 'Truthworld Advertiser';
      case AppFlavor.app:
        return 'Truthworld';
    }
  }
}
