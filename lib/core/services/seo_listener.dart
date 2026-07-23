import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/seo_helper.dart';
import 'package:truthworld/routes/route_metadata.dart';

/// SEO Listener for GetX routing
/// Automatically updates meta tags when route changes
class SeoRouteListener extends GetxController {
  late final Rx<String> _currentRoute = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeRouteListener();
  }

  /// Initialize route change listener
  void _initializeRouteListener() {
    if (!kIsWeb) return;

    // Listen to route changes using onRouteChanged callback
    ever(_currentRoute, _onRouteChange);

    // Initial SEO setup
    _updateSeoForCurrentRoute();

    // Use a more reliable way to detect route changes
    _scheduleRouteCheck();
  }

  /// Schedule periodic route checks
  void _scheduleRouteCheck() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      final newRoute = Get.currentRoute;
      if (newRoute != _currentRoute.value) {
        _currentRoute.value = newRoute;
        _updateSeoForCurrentRoute();
      }
      return true; // Continue the loop
    });
  }

  /// Handle route change
  void _onRouteChange(String newRoute) {
    Future.delayed(const Duration(milliseconds: 100), _updateSeoForCurrentRoute);
  }

  /// Update SEO metadata for current route
  void _updateSeoForCurrentRoute() {
    if (!kIsWeb) return;

    final currentRoute = Get.currentRoute;
    final metadata = RouteMetadataConfig.getMetadata(currentRoute);

    if (metadata != null) {
      SeoHelper.setPage(
        title: metadata.title,
        description: metadata.description,
        url: currentRoute,
        image: metadata.image,
        keywords: metadata.keywords,
        author: metadata.author,
      );

      debugPrint('✅ SEO Updated: $currentRoute → ${metadata.title}');
    } else {
      debugPrint('⚠️ SEO: No metadata found for route: $currentRoute');
    }
  }

  /// Manually update SEO (for dynamic content)
  static void updateSeo({
    required String title,
    required String description,
    String? url,
    String? image,
    String? keywords,
    String? author,
  }) {
    if (!kIsWeb) return;

    SeoHelper.setPage(
      title: title,
      description: description,
      url: url ?? Get.currentRoute,
      image: image,
      keywords: keywords,
      author: author,
    );

    debugPrint('✅ SEO Updated (Manual): $title');
  }
}





