import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Helper class for dynamic SEO updates in Flutter Web
class SeoHelper {
  /// Updates the page title and meta description dynamically
  static void updatePageMetadata({
    required String title,
    required String description,
  }) {
    if (!kIsWeb) return;

    try {
      // Update browser tab title
      web.document.title = title;

      // Update meta description
      final metaDescription = web.document.querySelector('meta[name="description"]');
      if (metaDescription != null) {
        metaDescription.setAttribute('content', description);
      }

      // Update Open Graph tags for better social sharing
      _updateMetaProperty('og:title', title);
      _updateMetaProperty('og:description', description);
      
      debugPrint('SEO Metadata updated: $title');
    } catch (e) {
      debugPrint('Error updating SEO metadata: $e');
    }
  }

  /// Helper to update meta property tags (og:*)
  static void _updateMetaProperty(String property, String content) {
    try {
      final element = web.document.querySelector('meta[property="$property"]');
      if (element != null) {
        element.setAttribute('content', content);
      }
    } catch (_) {
      // Ignore errors in meta property updates
    }
  }
}
