import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js.dart' as js;

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
    required String content,
    String? name,
    String? property,
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

    var link = head.querySelector('link[rel="canonical"]') as html.LinkElement?;

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
    required DateTime publishedDate,
    String? image,
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

  /// Update or create JSON-LD script tag in head
  static void _updateOrCreateJsonLd(String id, Map<String, dynamic> jsonLdData) {
    if (!kIsWeb) return;
    final head = html.document.head;
    if (head == null) return;

    var script = head.querySelector('script#$id') as html.ScriptElement?;
    final jsonStr = json.encode(jsonLdData);

    if (script != null) {
      script.text = jsonStr;
    } else {
      script = html.ScriptElement()
        ..id = id
        ..type = 'application/ld+json'
        ..text = jsonStr;
      head.append(script);
    }
  }

  /// Set video metadata with optimized image handling
  static void setVideoMetadata({
    required String title,
    required String description,
    required String url,
    required String videoUrl,
    required Duration duration,
    String? thumbnailUrl,
    DateTime? uploadDate,
    String? channelName,
    String? channelUrl,
    bool isKidFriendly = true,
  }) {
    // Validate and convert video URL to absolute
    final absoluteVideoUrl = _toAbsoluteUrl(videoUrl);
    final absoluteThumbnailUrl = _validateImageUrl(thumbnailUrl);
    final fullUrl = url.startsWith('http') ? url : '$_appUrl$url';
    final isHls = videoUrl.contains('.m3u8') || videoUrl.contains('hls');
    final videoMimeType = isHls ? 'application/x-mpegURL' : 'video/mp4';

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

      _updateOrCreateMeta(property: 'og:video:type', content: videoMimeType);

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

      // Inject Schema.org VideoObject JSON-LD for Google Rich Results
      final embedUrl = fullUrl.replaceAll('/watch?v=', '/embed/').replaceAll('/watch/', '/embed/');
      _updateOrCreateJsonLd('video-jsonld', {
        '@context': 'https://schema.org',
        '@type': 'VideoObject',
        'name': title,
        'description': description,
        'thumbnailUrl': [absoluteThumbnailUrl],
        if (uploadDate != null) 'uploadDate': uploadDate.toIso8601String(),
        'duration': () {
          final totalSec = duration.inSeconds;
          final h = totalSec ~/ 3600;
          final m = (totalSec % 3600) ~/ 60;
          final s = totalSec % 60;
          final parts = <String>[];
          if (h > 0) parts.add('${h}H');
          if (m > 0) parts.add('${m}M');
          if (s > 0 || parts.isEmpty) parts.add('${s}S');
          return 'PT${parts.join()}';
        }(),
        'contentUrl': absoluteVideoUrl,
        'embedUrl': embedUrl,
        'isFamilyFriendly': isKidFriendly,
        'publisher': {
          '@type': 'Organization',
          'name': 'Truthworld',
          'url': _appUrl,
          'logo': {
            '@type': 'ImageObject',
            'url': '$_appUrl/icons/Icon-192.png',
          },
        },
        if (channelName != null && channelName.isNotEmpty)
          'author': {
            '@type': 'Person',
            'name': channelName,
            'url': channelUrl ?? _appUrl,
          },
        'potentialAction': [
          {
            '@type': 'SeekToAction',
            'target': '$fullUrl&t={seek_to_second_number}',
            'startOffset-input': 'required name=seek_to_second_number',
          },
          {
            '@type': 'WatchAction',
            'target': fullUrl,
          },
        ],
      });
    }
  }

  /// Set channel metadata with optimized banner and avatar image handling
  static void setChannelMetadata({
    required String channelName,
    required String description,
    required String url,
    String? bannerUrl,
    String? avatarUrl,
    String? handle,
    int? subscriberCount,
    int? videoCount,
  }) {
    // Prioritize high-res banner for wide social card, fallback to avatar
    final effectiveImage = (bannerUrl != null && bannerUrl.isNotEmpty)
        ? bannerUrl
        : avatarUrl;
    final absoluteImageUrl = _validateImageUrl(effectiveImage);

    final cleanHandle = (handle ?? '').replaceAll(RegExp('^@'), '').trim();
    final handleWithAt = cleanHandle.isNotEmpty ? '@$cleanHandle' : '';

    String pageTitle;
    if (channelName.toLowerCase() == 'truthworld' ||
        channelName.toLowerCase() == 'truth world') {
      pageTitle = handleWithAt.isNotEmpty
          ? 'Truthworld ($handleWithAt) - Official Video Channel'
          : 'Truthworld - Official Video Channel';
    } else if (handleWithAt.isNotEmpty) {
      pageTitle = '$channelName ($handleWithAt)';
    } else {
      pageTitle = channelName;
    }

    setPage(
      title: pageTitle,
      description: description,
      url: url,
      image: absoluteImageUrl,
      author: channelName,
      type: 'profile',
    );

    final head = html.document.head;
    if (head != null && cleanHandle.isNotEmpty) {
      _updateOrCreateMeta(
        property: 'profile:username',
        content: cleanHandle,
      );
    }
  }

  /// Set playlist metadata with optimized image handling
  static void setPlaylistMetadata({
    required String playlistName,
    required String description,
    required String url,
    String? thumbnailUrl,
    String? channelName,
    int? videoCount,
  }) {
    final absoluteImageUrl = _validateImageUrl(thumbnailUrl);
    final vidStr = videoCount != null ? ' • $videoCount Videos' : '';
    final channelStr = channelName != null && channelName.isNotEmpty ? ' by $channelName' : '';
    final pageTitle = '$playlistName$channelStr | Playlist | Truthworld';

    setPage(
      title: pageTitle,
      description: '$description$vidStr on Truthworld',
      url: url,
      image: absoluteImageUrl,
      author: channelName,
    );
  }

  /// Set topic metadata with optimized image handling
  static void setTopicMetadata({
    required String topicName,
    required String description,
    required String url,
    String? thumbnailUrl,
    int? videoCount,
    int? followerCount,
  }) {
    final cleanTopic = topicName.replaceAll(RegExp('^[#Tt]/'), '').trim();
    final absoluteImageUrl = _validateImageUrl(thumbnailUrl);
    final statsStr = (videoCount != null || followerCount != null)
        ? ' • ${followerCount ?? 0} Followers • ${videoCount ?? 0} Videos'
        : '';
    final pageTitle = '#$cleanTopic - Topic | Truthworld';

    setPage(
      title: pageTitle,
      description: '$description$statsStr on Truthworld',
      url: url,
      image: absoluteImageUrl,
    );
  }

  /// Reset to default metadata
  static void resetToDefault() {
    if (kIsWeb) {
      final head = html.document.head;
      if (head != null) {
        head.querySelector('script#video-jsonld')?.remove();
        head.querySelector('meta[property="og:video"]')?.remove();
        head.querySelector('meta[property="og:video:type"]')?.remove();
        head.querySelector('meta[property="og:video:url"]')?.remove();
        head.querySelector('meta[property="og:video:thumbnail_url"]')?.remove();
        head.querySelector('meta[property="video:release_date"]')?.remove();
        head.querySelector('meta[property="video:duration"]')?.remove();
        head.querySelector('meta[property="og:video:secure_url"]')?.remove();
      }
    }
    setPage(
      title: 'Home',
      description: 'Truthworld - Share and discover amazing video content',
      url: '/',
      image: _defaultImage,
    );
  }
}
