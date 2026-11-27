import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';

/// 🏛 SourceAvatarService
///
/// Collects and resolves authentic brand & institutional logos/avatars
/// for source citations, fact-checking cards, and credibility reports.
class SourceAvatarService {
  SourceAvatarService._();

  // In-memory cache for ultra-fast lookup
  static final Map<String, String> _memoryCache = <String, String>{};

  // Curated authoritative institutional emblems and verified publisher logos
  static const Map<String, String> _institutionalAvatars = <String, String>{
    // Government Ministries & Health Councils
    'mohfw.gov.in':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/5/55/Emblem_of_India.svg/250px-Emblem_of_India.svg.png',
    'icmr.gov.in':
        'https://upload.wikimedia.org/wikipedia/en/thumb/d/d4/Indian_Council_of_Medical_Research_Logo.svg/250px-Indian_Council_of_Medical_Research_Logo.svg.png',
    'fao.org':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/FAO_logo.svg/250px-FAO_logo.svg.png',
    'who.int':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c2/WHO_logo.svg/250px-WHO_logo.svg.png',
    'cdc.gov':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/US_CDC_logo.svg/250px-US_CDC_logo.svg.png',
    'nih.gov':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/National_Institutes_of_Health_logo.svg/250px-National_Institutes_of_Health_logo.svg.png',
    'fda.gov':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/FDA_logo.svg/250px-FDA_logo.svg.png',
    'nasa.gov':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/NASA_logo.svg/250px-NASA_logo.svg.png',
    'isro.gov.in':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/ISRO_Logo.svg/250px-ISRO_Logo.svg.png',
    'un.org':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Flag_of_the_United_Nations.svg/250px-Flag_of_the_United_Nations.svg.png',
    'unesco.org':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/UNESCO_logo.svg/250px-UNESCO_logo.svg.png',
    'unicef.org':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/UNICEF_Logo.svg/250px-UNICEF_Logo.svg.png',
    'worldbank.org':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/The_World_Bank_logo.svg/250px-The_World_Bank_logo.svg.png',

    // News & Media Outlets (High-availability Google S2 Favicon CDN)
    'dnaindia.com':
        'https://www.google.com/s2/favicons?domain=dnaindia.com&sz=128',
    'bbc.com':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/BBC.svg/250px-BBC.svg.png',
    'bbc.co.uk':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/BBC.svg/250px-BBC.svg.png',
    'reuters.com':
        'https://www.google.com/s2/favicons?domain=reuters.com&sz=128',
    'apnews.com':
        'https://www.google.com/s2/favicons?domain=apnews.com&sz=128',
    'thehindu.com':
        'https://www.google.com/s2/favicons?domain=thehindu.com&sz=128',
    'indianexpress.com':
        'https://www.google.com/s2/favicons?domain=indianexpress.com&sz=128',
    'timesofindia.indiatimes.com':
        'https://www.google.com/s2/favicons?domain=timesofindia.indiatimes.com&sz=128',
    'ndtv.com':
        'https://www.google.com/s2/favicons?domain=ndtv.com&sz=128',
    'nytimes.com':
        'https://www.google.com/s2/favicons?domain=nytimes.com&sz=128',
    'wsj.com':
        'https://www.google.com/s2/favicons?domain=wsj.com&sz=128',
    'bloomberg.com':
        'https://www.google.com/s2/favicons?domain=bloomberg.com&sz=128',

    // Scientific Journals & Fact Checkers
    'nature.com':
        'https://www.google.com/s2/favicons?domain=nature.com&sz=128',
    'science.org':
        'https://www.google.com/s2/favicons?domain=science.org&sz=128',
    'thelancet.com':
        'https://www.google.com/s2/favicons?domain=thelancet.com&sz=128',
    'nejm.org':
        'https://www.google.com/s2/favicons?domain=nejm.org&sz=128',
    'bmj.com':
        'https://www.google.com/s2/favicons?domain=bmj.com&sz=128',
    'snopes.com':
        'https://www.google.com/s2/favicons?domain=snopes.com&sz=128',
    'factcheck.org':
        'https://www.google.com/s2/favicons?domain=factcheck.org&sz=128',
    'politifact.com':
        'https://www.google.com/s2/favicons?domain=politifact.com&sz=128',
    'wikipedia.org':
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Wikipedia-logo-v2.svg/250px-Wikipedia-logo-v2.svg.png',
  };

  /// Cleans any raw URL or domain string into a canonical domain.
  static String cleanDomain(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var domain = raw.trim().toLowerCase();
    domain = domain.replaceFirst(RegExp('^https?://', caseSensitive: false), '');
    domain = domain.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    if (domain.contains('/')) domain = domain.split('/').first;
    if (domain.contains('?')) domain = domain.split('?').first;
    if (domain.contains('#')) domain = domain.split('#').first;
    return domain.trim();
  }

  static bool _isUnhelpfulHost(String host) {
    final h = host.trim().toLowerCase();
    return h.isEmpty ||
        h.contains('vertexaisearch') ||
        h == 'google.com' ||
        h.endsWith('.google.com') ||
        h == 'verified source' ||
        h == 'reference source' ||
        h == 'authoritative source';
  }

  /// Resolves the authentic avatar URL synchronously.
  static String resolveAvatarUrl({
    String? domain,
    String? publisher,
    String? url,
    String? avatarUrl,
    String? title,
  }) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty && avatarUrl.startsWith('http')) {
      return avatarUrl.trim();
    }

    var cleanedDomain = cleanDomain(domain);
    if (_isUnhelpfulHost(cleanedDomain)) {
      final rawUrlHost = cleanDomain(url);
      cleanedDomain = _isUnhelpfulHost(rawUrlHost) ? '' : rawUrlHost;
    }
    if (cleanedDomain.isEmpty) {
      cleanedDomain =
          SourceUrlSanitizer.extractDomainFromText(publisher) ??
          SourceUrlSanitizer.extractDomainFromText(title) ??
          '';
    }

    // 1. Check memory cache
    if (cleanedDomain.isNotEmpty && _memoryCache.containsKey(cleanedDomain)) {
      return _memoryCache[cleanedDomain]!;
    }
    if (publisher != null && publisher.isNotEmpty && _memoryCache.containsKey(publisher.toLowerCase().trim())) {
      return _memoryCache[publisher.toLowerCase().trim()]!;
    }

    // 2. Direct institutional domain match
    if (cleanedDomain.isNotEmpty && _institutionalAvatars.containsKey(cleanedDomain)) {
      final logo = _institutionalAvatars[cleanedDomain]!;
      _memoryCache[cleanedDomain] = logo;
      return logo;
    }

    // 3. Publisher name matching (curated institutional mappings)
    if (publisher != null && publisher.trim().isNotEmpty) {
      final pubLower = publisher.toLowerCase().trim();
      if (pubLower.contains('health and family welfare') || pubLower == 'mohfw') {
        return _institutionalAvatars['mohfw.gov.in']!;
      }
      if (pubLower.contains('icmr') || pubLower.contains('indian council of medical research')) {
        return _institutionalAvatars['icmr.gov.in']!;
      }
      if (pubLower.contains('food and agriculture') || pubLower == 'fao') {
        return _institutionalAvatars['fao.org']!;
      }
      if (pubLower.contains('dna india') || pubLower == 'dna') {
        return _institutionalAvatars['dnaindia.com']!;
      }
      if (pubLower.contains('bbc')) {
        return _institutionalAvatars['bbc.com']!;
      }
      if (pubLower.contains('world health') || pubLower == 'who') {
        return _institutionalAvatars['who.int']!;
      }
      if (pubLower.contains('reuters')) {
        return _institutionalAvatars['reuters.com']!;
      }
      if (pubLower.contains('national institutes of health') || pubLower == 'nih') {
        return _institutionalAvatars['nih.gov']!;
      }
      if (pubLower.contains('cdc')) {
        return _institutionalAvatars['cdc.gov']!;
      }
      if (pubLower.contains('nasa')) {
        return _institutionalAvatars['nasa.gov']!;
      }

      // Canonical resolution from known publisher domain dictionary
      final canonicalFromPub = SourceUrlSanitizer.resolveCanonicalDomain(publisher);
      if (canonicalFromPub != null && canonicalFromPub.isNotEmpty) {
        if (_institutionalAvatars.containsKey(canonicalFromPub)) {
          final logo = _institutionalAvatars[canonicalFromPub]!;
          _memoryCache[pubLower] = logo;
          _memoryCache[canonicalFromPub] = logo;
          return logo;
        }
        final googleFaviconUrl = 'https://www.google.com/s2/favicons?domain=$canonicalFromPub&sz=128';
        _memoryCache[pubLower] = googleFaviconUrl;
        _memoryCache[canonicalFromPub] = googleFaviconUrl;
        return googleFaviconUrl;
      }
    }

    // 4. Canonical domain resolution from domain / url
    final canonicalFromDomain = SourceUrlSanitizer.resolveCanonicalDomain(cleanedDomain);
    final targetDomain = canonicalFromDomain ?? cleanedDomain;

    // 5. Authoritative Google High-Resolution 128px Favicon Service
    if (targetDomain.isNotEmpty && targetDomain.contains('.')) {
      final googleFaviconUrl = 'https://www.google.com/s2/favicons?domain=$targetDomain&sz=128';
      _memoryCache[targetDomain] = googleFaviconUrl;
      if (cleanedDomain.isNotEmpty) _memoryCache[cleanedDomain] = googleFaviconUrl;
      return googleFaviconUrl;
    }

    return '';
  }

  /// Asynchronously queries the backend `getSourceAvatars` Cloud Function to collect
  /// and update avatars for a list of sources.
  static Future<Map<String, String>> fetchAvatarsFromBackend({
    List<String>? domains,
    List<Map<String, dynamic>>? sources,
  }) async {
    // 1. Immediately pre-resolve all domains into memory cache using Google S2 and curated emblems
    final result = <String, String>{};
    if (domains != null) {
      for (final d in domains) {
        final clean = cleanDomain(d);
        if (clean.isNotEmpty) {
          final resolved = resolveAvatarUrl(domain: clean);
          if (resolved.isNotEmpty) {
            result[clean] = resolved;
            _memoryCache[clean] = resolved;
          }
        }
      }
    }
    if (sources != null) {
      for (final s in sources) {
        final domain = s['domain']?.toString();
        final pub = s['publisher']?.toString();
        final url = s['url']?.toString();
        final resolved = resolveAvatarUrl(domain: domain, publisher: pub, url: url);
        final key = cleanDomain(domain ?? url);
        if (key.isNotEmpty && resolved.isNotEmpty) {
          result[key] = resolved;
          _memoryCache[key] = resolved;
        }
      }
    }

    // 2. Query backend Cloud Function with graceful fallback
    try {
      final callable = FirebaseFunctions.instanceFor(region: AppConfig.credibilityFunctionsRegion)
          .httpsCallable('getSourceAvatars');
      final response = await callable.call<Map<String, dynamic>>({
        'domains': ?domains,
        'sources': ?sources,
      });

      final avatarsRaw = response.data['avatars'];
      if (avatarsRaw is Map) {
        avatarsRaw.forEach((k, v) {
          if (k is String && v is String && v.isNotEmpty) {
            result[k] = v;
            _memoryCache[k] = v;
          }
        });
        return result;
      }
    } catch (e) {
      // If Cloud Function is not yet deployed or temporarily unavailable,
      // the local pre-resolved Google S2 & institutional avatars remain active.
      debugPrint('[SourceAvatarService] Backend avatar fetch fallback active: $e');
    }
    return result;
  }

  /// Builds a high-contrast circular source avatar widget.
  static Widget buildAvatar({
    String? domain,
    String? publisher,
    String? url,
    String? title,
    String? avatarUrl,
    IconData? fallbackIcon,
    double size = 48,
    EdgeInsetsGeometry? padding,
  }) {
    final effectiveAvatarUrl = resolveAvatarUrl(
      domain: domain,
      publisher: publisher,
      url: url,
      title: title,
      avatarUrl: avatarUrl,
    );

    final initialChar = (publisher != null && publisher.trim().isNotEmpty)
        ? publisher.trim()[0].toUpperCase()
        : (domain != null && domain.trim().isNotEmpty ? domain.trim()[0].toUpperCase() : 'S');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: padding ?? EdgeInsets.all(size * 0.12),
          child: effectiveAvatarUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: effectiveAvatarUrl,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 150),
                  fadeOutDuration: const Duration(milliseconds: 150),
                  placeholder: (context, u) => _buildFallback(initialChar, fallbackIcon, size),
                  errorWidget: (context, u, e) => _buildFallback(initialChar, fallbackIcon, size),
                )
              : _buildFallback(initialChar, fallbackIcon, size),
        ),
      ),
    );
  }

  static Widget _buildFallback(String initial, IconData? fallbackIcon, double size) {
    if (fallbackIcon != null) {
      return Center(
        child: Icon(
          fallbackIcon,
          size: size * 0.52,
          color: Colors.black87, // Must be black on white container
        ),
      );
    }
    return _buildFallbackMonogram(initial, size);
  }

  static Widget _buildFallbackMonogram(String initial, double size) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: Colors.black87, // Must be black on white container
        ),
      ),
    );
  }
}
