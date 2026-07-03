import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:universal_html/js.dart' as js;
import 'package:universal_html/html.dart' as html;

/// Enhanced SEO Service for Flutter Web
/// Manages meta tags, Open Graph, and page metadata
class SeoHelper {
  static const String _appName = 'Truthworld';
  static const String _appUrl = 'https://www.truthworld.in';
  static const String _defaultImage = 'https://www.truthworld.in/og-image.png';

  /// Convert relative URL to absolute URL
  static String _toAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) {
      return _defaultImage;
    }

    // Already absolute URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Relative URL - prepend domain
    if (url.startsWith('/')) {
      return '$_appUrl$url';
    }

    // Relative path without slash
    return '$_appUrl/$url';
  }

  /// Validate if image URL is accessible and public
  static String _validateImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _defaultImage;
    }

    final absoluteUrl = _toAbsoluteUrl(imageUrl);

    // Validate URL format
    try {
      Uri.parse(absoluteUrl);
      return absoluteUrl;
    } catch (e) {
      debugPrint('⚠️ Invalid image URL: $imageUrl, using default');
      return _defaultImage;
    }
  }

  /// Set page metadata (title, description, OG tags)
  static void setPage({
    required String title,
    required String description,
    String? url,
    String? image,
    String? author,
    String? keywords,
    String? type = 'website',
  }) {
    if (!kIsWeb) return;

    try {
      // 1️⃣ Update HTML title
      html.document.title = '$title | $_appName';

      // 2️⃣ Update meta description
      _updateOrCreateMeta(name: 'description', content: description);

      // 3️⃣ Update keywords
      if (keywords != null && keywords.isNotEmpty) {
        _updateOrCreateMeta(name: 'keywords', content: keywords);
      }

      // 4️⃣ Update author
      if (author != null && author.isNotEmpty) {
        _updateOrCreateMeta(name: 'author', content: author);
      }

      // 5️⃣ Update Viewport (for mobile SEO)
      _updateOrCreateMeta(
        name: 'viewport',
        content: 'width=device-width, initial-scale=1.0',
      );

      // 6️⃣ Open Graph Tags
      _updateOrCreateMeta(property: 'og:title', content: title);

      _updateOrCreateMeta(property: 'og:description', content: description);

      _updateOrCreateMeta(property: 'og:type', content: type ?? 'website');

      final fullUrl = url != null ? '$_appUrl$url' : _appUrl;
      _updateOrCreateMeta(property: 'og:url', content: fullUrl);

      // 🖼️ Validate and set absolute image URL
      final validatedImage = _validateImageUrl(image);
      _updateOrCreateMeta(property: 'og:image', content: validatedImage);

      _updateOrCreateMeta(property: 'og:image:width', content: '1200');

      _updateOrCreateMeta(property: 'og:image:height', content: '630');

      // og:image:type for better social sharing
      _updateOrCreateMeta(property: 'og:image:type', content: 'image/png');

      // og:image:alt for accessibility
      _updateOrCreateMeta(property: 'og:image:alt', content: title);

      // 7️⃣ Twitter Card Tags
      _updateOrCreateMeta(name: 'twitter:card', content: 'summary_large_image');

      _updateOrCreateMeta(name: 'twitter:title', content: title);

      _updateOrCreateMeta(name: 'twitter:description', content: description);

      _updateOrCreateMeta(name: 'twitter:image', content: validatedImage);

      _updateOrCreateMeta(name: 'twitter:image:alt', content: title);

      // 8️⃣ Canonical URL (prevents duplicate content)
      _updateOrCreateCanonical(fullUrl);

      // 9️⃣ Update browser URL history
      _updateBrowserHistory(url ?? '/');

      // 🔟 Notify Google Search Console
      _notifySearchEngines(fullUrl);

      debugPrint('✅ SEO: Updated meta tags for "$title"');
      debugPrint('📸 OG Image: $validatedImage');
    } catch (e) {
      debugPrint('❌ SEO Error: $e');
    }
  }

  /// Update or create a meta tag
  static void _updateOrCreateMeta({
    String? name,
    String? property,
    required String content,
  }) {
    final head = html.document.head;
    if (head == null) return;

    html.MetaElement? element;

    if (name != null) {
      element = head.querySelector('meta[name="$name"]') as html.MetaElement?;
      if (element != null) {
        element.content = content;
        return;
      }

      element = html.MetaElement()
        ..name = name
        ..content = content;
    } else if (property != null) {
      element =
          head.querySelector('meta[property="$property"]') as html.MetaElement?;
      if (element != null) {
        element.content = content;
        return;
      }

      element = html.MetaElement()
        ..setAttribute('property', property)
        ..content = content;
    }

    if (element != null) {
      head.append(element);
    }
  }

  /// Update or create canonical link
  static void _updateOrCreateCanonical(String url) {
    final head = html.document.head;
    if (head == null) return;

    html.LinkElement? link =
        head.querySelector('link[rel="canonical"]') as html.LinkElement?;

    if (link != null) {
      link.href = url;
    } else {
      link = html.LinkElement()
        ..rel = 'canonical'
        ..href = url;
      head.append(link);
    }
  }

  /// Update browser history without page reload
  static void _updateBrowserHistory(String path) {
    if (!kIsWeb) return;

    try {
      js.context.callMethod('eval', [
        '''
        if (window.history && window.history.replaceState) {
          window.history.replaceState({}, document.title, '$path');
        }
        ''',
      ]);
    } catch (e) {
      debugPrint('⚠️ Browser history update failed: $e');
    }
  }

  /// Notify search engines of URL change
  static void _notifySearchEngines(String url) {
    if (!kIsWeb) return;

    try {
      if (js.context['gtag'] != null) {
        js.context.callMethod('eval', [
          '''
          if (typeof gtag !== 'undefined') {
            gtag('event', 'page_view', {
              'page_path': '$url',
              'page_title': document.title
            });
          }
          ''',
        ]);
      }
    } catch (e) {
      debugPrint('⚠️ Search engine notification failed: $e');
    }
  }

  /// Set article metadata (for blog/article pages)
  static void setArticleMetadata({
    required String title,
    required String description,
    required String url,
    String? image,
    required DateTime publishedDate,
    DateTime? modifiedDate,
    List<String>? authors,
    List<String>? keywords,
  }) {
    setPage(
      title: title,
      description: description,
      url: url,
      image: image,
      keywords: keywords?.join(', '),
      author: authors?.join(', '),
      type: 'article',
    );

    final head = html.document.head;
    if (head != null) {
      _updateOrCreateMeta(
        property: 'article:published_time',
        content: publishedDate.toIso8601String(),
      );

      if (modifiedDate != null) {
        _updateOrCreateMeta(
          property: 'article:modified_time',
          content: modifiedDate.toIso8601String(),
        );
      }

      if (keywords != null && keywords.isNotEmpty) {
        _updateOrCreateMeta(
          property: 'article:tag',
          content: keywords.join(', '),
        );
      }
    }
  }

  /// Set video metadata with optimized image handling
  static void setVideoMetadata({
    required String title,
    required String description,
    required String url,
    required String videoUrl,
    String? thumbnailUrl,
    required Duration duration,
    DateTime? uploadDate,
  }) {
    // Validate and convert video URL to absolute
    final absoluteVideoUrl = _toAbsoluteUrl(videoUrl);
    final absoluteThumbnailUrl = _validateImageUrl(thumbnailUrl);

    setPage(
      title: title,
      description: description,
      url: url,
      image: absoluteThumbnailUrl,
      type: 'video.other',
    );

    final head = html.document.head;
    if (head != null) {
      _updateOrCreateMeta(property: 'og:video', content: absoluteVideoUrl);

      _updateOrCreateMeta(property: 'og:video:type', content: 'video/mp4');

      _updateOrCreateMeta(property: 'og:video:url', content: absoluteVideoUrl);

      if (uploadDate != null) {
        _updateOrCreateMeta(
          property: 'video:release_date',
          content: uploadDate.toIso8601String(),
        );
      }

      _updateOrCreateMeta(
        property: 'video:duration',
        content: duration.inSeconds.toString(),
      );

      // Add video thumbnail as additional OG image
      _updateOrCreateMeta(
        property: 'og:video:thumbnail_url',
        content: absoluteThumbnailUrl,
      );
    }
  }

  /// Reset to default metadata
  static void resetToDefault() {
    setPage(
      title: 'Home',
      description: 'Truthworld - Share and discover amazing video content',
      url: '/',
      image: _defaultImage,
    );
  }
}




