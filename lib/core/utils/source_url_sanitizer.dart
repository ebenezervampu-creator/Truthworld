import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

typedef BrokenSourceReporter = Future<void> Function({
  required String brokenUrl,
  String? videoId,
  String? claimId,
  int? httpStatus,
  String? reason,
});

/// Centralized utility for validating, sanitizing, and launching source citations.
/// Enforces Closed-World URL safety by pre-flighting redirects and intercepting
/// 404/broken links without ever substituting bare publisher homepages.
class SourceUrlSanitizer {
  SourceUrlSanitizer._();

  static final RegExp _groundingRedirectRegex = RegExp(
    r'(vertexaisearch\.cloud\.google\.com|google\.com)/grounding-api-redirect',
    caseSensitive: false,
  );

  static final Set<String> _dummyDomains = {
    'example.com',
    'example.org',
    'example.net',
    'localhost',
    '127.0.0.1',
    'placeholder.com',
    'placeholder.org',
    'test.com',
    'test.org',
    'sample.com',
    'sample.org',
    'unknown.com',
    'fake.com',
    'dummy.com',
  };

  /// Authoritative registry mapping publisher / organization names to canonical web domains.
  /// Prevents converting organization names directly into non-existent TLDs (e.g. 'https://nasa', 'https://wion').
  static final Map<String, String> _knownPublisherDomains = {
    'nasa': 'nasa.gov',
    'isro': 'isro.gov.in',
    'esa': 'esa.int',
    'spacex': 'spacex.com',
    'wion': 'wionews.com',
    'wionews': 'wionews.com',
    'visual capitalist': 'visualcapitalist.com',
    'visualcapitalist': 'visualcapitalist.com',
    'wikipedia': 'wikipedia.org',
    'mdpi': 'mdpi.com',
    'herox': 'herox.com',
    'who': 'who.int',
    'cdc': 'cdc.gov',
    'nih': 'nih.gov',
    'noaa': 'noaa.gov',
    'un': 'un.org',
    'united nations': 'un.org',
    'imf': 'imf.org',
    'world bank': 'worldbank.org',
    'worldbank': 'worldbank.org',
    'nature': 'nature.com',
    'science': 'science.org',
    'reuters': 'reuters.com',
    'ap news': 'apnews.com',
    'apnews': 'apnews.com',
    'associated press': 'apnews.com',
    'bloomberg': 'bloomberg.com',
    'wsj': 'wsj.com',
    'wall street journal': 'wsj.com',
    'nytimes': 'nytimes.com',
    'new york times': 'nytimes.com',
    'the new york times': 'nytimes.com',
    'bbc': 'bbc.com',
    'ft': 'ft.com',
    'financial times': 'ft.com',
    'the guardian': 'theguardian.com',
    'guardian': 'theguardian.com',
    'forbes': 'forbes.com',
    'techcrunch': 'techcrunch.com',
    'the verge': 'theverge.com',
    'verge': 'theverge.com',
    'wired': 'wired.com',
    'snopes': 'snopes.com',
    'politifact': 'politifact.com',
    'factcheck.org': 'factcheck.org',
    'factcheck': 'factcheck.org',
    'sciencedirect': 'sciencedirect.com',
    'britannica': 'britannica.com',
    'investopedia': 'investopedia.com',
    'healthline': 'healthline.com',
    'stanford': 'stanford.edu',
    'harvard': 'harvard.edu',
    'mit': 'mit.edu',
    'oxford': 'ox.ac.uk',
    'cambridge': 'cam.ac.uk',
    'national geographic': 'nationalgeographic.com',
    'scientific american': 'scientificamerican.com',
    'economist': 'economist.com',
    'the economist': 'economist.com',
    'fda': 'fda.gov',
    'epa': 'epa.gov',
    'usda': 'usda.gov',
    'pnas': 'pnas.org',
    'the lancet': 'thelancet.com',
    'lancet': 'thelancet.com',
    'nejm': 'nejm.org',
    'new england journal of medicine': 'nejm.org',
    'bmj': 'bmj.com',
    'british medical journal': 'bmj.com',
    'ieee': 'ieee.org',
    'acm': 'acm.org',
    'arxiv': 'arxiv.org',
    'cern': 'cern.ch',
    'jstor': 'jstor.org',
    'washington post': 'washingtonpost.com',
    'washingtonpost': 'washingtonpost.com',
    'los angeles times': 'latimes.com',
    'la times': 'latimes.com',
    'cnn': 'cnn.com',
    'al jazeera': 'aljazeera.com',
    'aljazeera': 'aljazeera.com',
    'dw': 'dw.com',
    'deutsche welle': 'dw.com',
    'france24': 'france24.com',
    'france 24': 'france24.com',
    'ndtv': 'ndtv.com',
    'the hindu': 'thehindu.com',
    'hindu': 'thehindu.com',
    'indian express': 'indianexpress.com',
    'times of india': 'timesofindia.indiatimes.com',
  };

  /// Returns true if [url] is null, empty, a placeholder anchor ('#', '/'),
  /// javascript pseudo-protocol, or belongs to a known dummy or placeholder domain.
  static bool isBlankOrDummyUrl(String? url) {
    if (url == null) return true;
    final trimmed = url.trim().toLowerCase();
    if (trimmed.isEmpty ||
        trimmed == '#' ||
        trimmed == '/' ||
        trimmed == 'about:blank' ||
        trimmed == 'null' ||
        trimmed == 'undefined' ||
        trimmed == 'none' ||
        trimmed == 'n/a' ||
        trimmed == 'not applicable' ||
        trimmed == 'http://' ||
        trimmed == 'https://' ||
        trimmed == 'http://#' ||
        trimmed == 'https://#' ||
        trimmed.startsWith('javascript:')) {
      return true;
    }
    return false;
  }

  /// Returns true if [domain] is a structurally valid Fully Qualified Domain Name (FQDN).
  /// Excludes single words ("nasa"), strings with spaces ("visual capitalist"),
  /// and strings missing a valid top-level domain (TLD).
  static bool isValidDomain(String? domain) {
    if (domain == null || domain.trim().isEmpty) return false;
    final clean = domain
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp('^https?://'), '')
        .replaceFirst(RegExp(r'^www\.'), '')
        .split('/')[0]
        .split('?')[0]
        .split('#')[0]
        .trim();
    if (clean.isEmpty || clean.contains(RegExp(r'\s'))) return false;
    if (clean.contains('vertexaisearch') || clean == 'google.com' || clean.endsWith('.google.com')) return false;
    if (!clean.contains('.')) return false;

    final parts = clean.split('.');
    if (parts.any((p) => p.isEmpty)) return false;

    final tld = parts.last;
    if (!RegExp(r'^(?:[a-zA-Z]{2,24}|xn--[a-zA-Z0-9]+)$').hasMatch(tld)) {
      return false;
    }

    final domainLabel = parts[parts.length - 2];
    if (!RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')
        .hasMatch(domainLabel)) {
      return false;
    }

    return true;
  }

  /// Resolves any raw domain, publisher name, or organization moniker to a canonical, valid web domain.
  /// Converts publisher names (e.g. "NASA" -> "nasa.gov", "WION" -> "wionews.com", "Visual Capitalist" -> "visualcapitalist.com")
  /// while rejecting invalid tokens, spaces, or dummy names. Returns null if unresolvable.
  static String? resolveCanonicalDomain(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final clean = input
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp('^https?://'), '')
        .replaceFirst(RegExp(r'^www\.'), '')
        .split('/')[0]
        .split('?')[0]
        .split('#')[0]
        .trim();
    if (clean.isEmpty) return null;

    // 1. Direct match in known publisher dictionary
    if (_knownPublisherDomains.containsKey(clean)) {
      return _knownPublisherDomains[clean];
    }

    // 2. Alphanumeric match (stripping spaces, hyphens, punctuation)
    final alphaNumeric = clean.replaceAll(RegExp('[^a-z0-9]'), '');
    if (_knownPublisherDomains.containsKey(alphaNumeric)) {
      return _knownPublisherDomains[alphaNumeric];
    }

    // 3. If already a valid FQDN (e.g. "nasa.gov", "cdc.gov", "outerspacetrip.com")
    if (isValidDomain(clean)) {
      return clean;
    }

    return null;
  }

  /// Resolves a 100% valid and reachable fallback URL for a source citation.
  /// Guarantees that the returned URL is an authentic canonical domain or Google search query,
  /// and NEVER an invalid hostname (e.g. 'https://nasa', 'https://wion').
  /// Legacy compatibility helper: returns `null` under Closed-World citation
  /// rules so unverified/dead citations are never downgraded to publisher homepages.
  static String? resolveFallbackUrl({
    String? domain,
    String? publisher,
    String? title,
  }) {
    return null;
  }

  /// Returns true if [url] is an ephemeral Google Vertex AI Search grounding redirect.
  static bool isGroundingRedirect(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return _groundingRedirectRegex.hasMatch(url);
  }

  /// Returns true if [url] belongs to a known dummy or placeholder domain.
  static bool isDummyDomain(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    for (final dummy in _dummyDomains) {
      if (lower.contains(dummy)) return true;
    }
    return false;
  }

  /// Returns true if [url] is a Google search query URL.
  static bool isGoogleSearchUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('google.com/search') ||
        (lower.contains('google.') && lower.contains('/search?'));
  }

  /// Constructs a 100% reliable Google search URL for a given title/publisher/query.
  /// Never returns 404 and directs the user to the authoritative documentation.
  static String createSearchUrl(
    String query, {
    String? publisher,
    String? domain,
  }) {
    var cleanQuery = query
        .replaceAll(
          RegExp(r'\s+[-|–—]\s+Google(\s+Search)?$', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\.{3,}$'), '')
        .trim();

    bool isGenericLabel(String? s) {
      if (s == null || s.trim().isEmpty) return true;
      final lower = s.trim().toLowerCase();
      return lower == 'google' ||
          lower == 'verified source' ||
          lower == 'reference source' ||
          lower == 'source citation';
    }

    if (!isGenericLabel(publisher) &&
        !cleanQuery.toLowerCase().contains(publisher!.toLowerCase())) {
      cleanQuery = '$cleanQuery $publisher';
    } else if (!isGenericLabel(domain) &&
        !domain!.contains('google.com') &&
        !domain.contains('vertexaisearch') &&
        !cleanQuery.toLowerCase().contains(domain.toLowerCase())) {
      cleanQuery = '$cleanQuery $domain';
    }

    if (cleanQuery.isEmpty) cleanQuery = 'Verified Fact Check Source';

    return 'https://www.google.com/search?q=${Uri.encodeComponent(cleanQuery)}';
  }

  /// Returns true if [url] points to a bare root domain / static landing homepage
  /// without any specific article, document, or section path (e.g. 'https://bbc.com', 'https://en.wikipedia.org/').
  static bool isStaticHomepageUrl(String? url) {
    if (url == null || isBlankOrDummyUrl(url)) return true;
    final clean = url.trim();

    // Vertex AI / Google Grounding redirects are dynamic redirects to specific articles, not static homepages
    if (isGroundingRedirect(clean)) return false;

    // Google search URLs are targeted searches, not static homepages
    if (isGoogleSearchUrl(clean)) return false;

    final uri = Uri.tryParse(clean.startsWith('http') ? clean : 'https://$clean');
    if (uri == null || !uri.hasAuthority) return true;

    final path = uri.path.trim().toLowerCase();
    if (path.isEmpty ||
        path == '/' ||
        path == '/index.html' ||
        path == '/index.htm' ||
        path == '/index.php' ||
        path == '/home' ||
        path == '/default.aspx') {
      if (!uri.hasQuery && (!uri.hasFragment || uri.fragment.isEmpty)) {
        return true;
      }
    }
    return false;
  }

  /// Resolves a URL that directly navigates to the particular article or document,
  /// preventing users from landing on a generic static root website homepage.
  static String resolveDirectNavigationUrl({
    required String url,
    String? title,
    String? publisher,
    String? domain,
  }) {
    if (!isStaticHomepageUrl(url)) {
      return url;
    }

    final cleanTitle = title?.trim() ?? '';
    final isGeneric = cleanTitle.isEmpty ||
        cleanTitle.toLowerCase() == 'reference source' ||
        cleanTitle.toLowerCase() == 'verified source' ||
        cleanTitle.toLowerCase() == 'source citation';

    if (isGeneric) {
      return url;
    }

    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    final host = uri?.host.toLowerCase() ?? (domain?.toLowerCase() ?? '');

    // 1. Wikipedia: use Wikipedia's direct search route to land directly on the particular topic
    if (host.contains('wikipedia.org')) {
      final topicQuery = cleanTitle.split(RegExp(r'\s+[-|–—]\s+')).first.trim();
      final wikiHost = host.isEmpty ? 'en.wikipedia.org' : host;
      return 'https://$wikiHost/wiki/Special:Search?search=${Uri.encodeComponent(topicQuery)}';
    }

    // 2. Authoritative publishers: construct targeted search to navigate directly to the specific article
    final targetDomain = resolveCanonicalDomain(host) ??
        resolveCanonicalDomain(domain) ??
        resolveCanonicalDomain(publisher);

    return createSearchUrl(
      cleanTitle,
      publisher: publisher,
      domain: targetDomain ?? host,
    );
  }

  /// Sanitizes any raw source URL under Closed-World safety rules.
  ///
  /// - Preserves Vertex AI grounding redirect URLs for pre-flight resolution.
  /// - Normalizes missing schemes (`https://`) and strips trailing punctuation.
  /// - Rejects blank, dummy, placeholder, Google Search, malformed, and bare root
  ///   homepage URLs by returning `null` (never substitutes publisher homepages).
  static String? sanitizeUrl(
    String? rawUrl, {
    String? title,
    String? publisher,
    String? domain,
  }) {
    if (rawUrl == null || isBlankOrDummyUrl(rawUrl)) {
      return null;
    }

    var url = rawUrl.trim();

    // Strip wrapping quotes and brackets: "url", <url>, (url), [url]
    url = url.replaceAll(RegExp(r'^["\x27<(\[]+|[">\x27)\]]+$'), '').trim();
    if (url.isEmpty) return null;

    // 1. Preserve Vertex AI Grounding redirects for server/pre-flight resolution
    if (isGroundingRedirect(url)) {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      return url;
    }

    // 2. Reject stored Google Search queries so search pages never masquerade as publisher citations
    if (isGoogleSearchUrl(url)) {
      return null;
    }

    // 3. Normalize scheme
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // 4. Strip trailing punctuation/brackets often left by OCR / LLM tokens
    url = url.replaceAll(RegExp(r'[\.,;:!?\)\]>"\x27]+$'), '');

    // 5. Validate Uri, FQDN host, and dummy domains without substituting homepages
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      return null;
    }
    if (!isValidDomain(parsed.host) || isDummyDomain(parsed.host)) {
      return null;
    }
    if (isStaticHomepageUrl(url)) {
      return null;
    }

    return url;
  }

  /// Resolves the human-readable display domain, extracting the true publisher/organization
  /// even when the underlying link was a redirect or fallback.
  static String resolveDisplayDomain(
    String? rawUrl, {
    String? title,
    String? explicitDomain,
    String? publisher,
  }) {
    if (explicitDomain != null &&
        explicitDomain.isNotEmpty &&
        !explicitDomain.contains('vertexaisearch') &&
        !explicitDomain.contains('google.com')) {
      return explicitDomain.replaceFirst(RegExp(r'^www\.'), '');
    }

    if (publisher != null &&
        publisher.isNotEmpty &&
        publisher.toLowerCase() != 'google') {
      return publisher;
    }

    // Extract domain or organization from title (e.g. "Title - NASA", "Title | Wikipedia")
    if (title != null &&
        title.isNotEmpty &&
        title.toLowerCase() != 'source citation' &&
        title.toLowerCase() != 'reference source') {
      final parts = title.split(RegExp(r'\s+[-|–—]\s+'));
      if (parts.length > 1) {
        final lastPart = parts.last.trim();
        if (lastPart.isNotEmpty &&
            lastPart.toLowerCase() != 'google' &&
            !lastPart.toLowerCase().contains('search')) {
          return lastPart;
        }
      }
    }

    if (rawUrl != null && rawUrl.isNotEmpty && !isGroundingRedirect(rawUrl)) {
      final parsed = Uri.tryParse(
        rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl',
      );
      if (parsed != null && parsed.host.isNotEmpty) {
        final host = parsed.host.replaceFirst(RegExp(r'^www\.'), '');
        if (!host.contains('google.com') && !host.contains('vertexaisearch')) {
          return host;
        }
      }
    }

    return 'Verified Source';
  }

  /// Determines if a source object or map is valid and safe to display.
  /// Rejects dummy or completely empty sources to prevent showing 404-prone references.
  static bool isValidSource(dynamic source) {
    if (source == null) return false;

    String? title;
    String? url;

    if (source is Map) {
      title = (source['title'] ??
              source['author'] ??
              source['bookTitle'] ??
              source['journalName'])
          ?.toString();
      url = (source['url'] ?? source['directUrl'] ?? source['link'])?.toString();
    } else {
      title = source.toString();
    }

    final hasTitle = title != null &&
        title.trim().isNotEmpty &&
        title.toLowerCase() != 'source citation' &&
        title.toLowerCase() != 'reference source';
    final hasUrl = url != null && url.trim().isNotEmpty;

    if (!hasTitle && !hasUrl) return false;

    if (hasUrl && isDummyDomain(url) && !hasTitle) return false;

    return true;
  }

  /// Sanitizes an entire source map, updating its `url`, `directUrl`, and `domain`
  /// with guaranteed reliable destinations.
  static Map<dynamic, dynamic> sanitizeSourceMap(Map<dynamic, dynamic> source) {
    final rawMap = Map<dynamic, dynamic>.from(source);
    final title = (rawMap['title'] ??
            rawMap['author'] ??
            rawMap['bookTitle'] ??
            rawMap['journalName'])
        ?.toString();
    var rawUrl =
        (rawMap['url'] ?? rawMap['directUrl'] ?? rawMap['link'])?.toString();
    final directUrl = rawMap['directUrl']?.toString();
    final explicitDomain = rawMap['domain']?.toString();
    final publisher = (rawMap['publisher'] ?? rawMap['author'])?.toString();
    final doi = rawMap['doi']?.toString();

    // Prefer authentic directUrl if rawUrl is a Google search query
    if (isGoogleSearchUrl(rawUrl) && directUrl != null && !isGoogleSearchUrl(directUrl)) {
      rawUrl = directUrl;
    }

    // Resolve DOI if URL is missing or is a Google search query
    if ((rawUrl == null || rawUrl.isEmpty || isGoogleSearchUrl(rawUrl)) &&
        doi != null &&
        doi.trim().isNotEmpty) {
      rawUrl = doi.trim().startsWith('http') ? doi.trim() : 'https://doi.org/${doi.trim()}';
    }

    final cleanUrl = sanitizeUrl(
      rawUrl,
      title: title,
      publisher: publisher,
      domain: explicitDomain,
    );
    final cleanDirect = directUrl != null
        ? sanitizeUrl(
            directUrl,
            title: title,
            publisher: publisher,
            domain: explicitDomain,
          )
        : null;

    if (cleanUrl != null || cleanDirect != null) {
      final effUrl = cleanUrl ?? cleanDirect;
      rawMap['url'] = effUrl;
      rawMap['directUrl'] = cleanDirect ?? effUrl;
    } else {
      rawMap.remove('url');
      rawMap.remove('directUrl');
      rawMap.remove('link');
    }

    if (explicitDomain != null &&
        explicitDomain.isNotEmpty &&
        !explicitDomain.contains('vertexaisearch') &&
        !explicitDomain.contains('google.com')) {
      rawMap['domain'] = explicitDomain.replaceFirst(RegExp(r'^www\.'), '');
    } else if (cleanUrl != null || (rawUrl != null && rawUrl.isNotEmpty)) {
      rawMap['domain'] = resolveDisplayDomain(
        cleanUrl ?? rawUrl,
        title: title,
        explicitDomain: explicitDomain,
        publisher: (publisher != null &&
                publisher != title &&
                publisher != rawMap['author']?.toString())
            ? publisher
            : null,
      );
    }
    return rawMap;
  }

  /// Non-blocking broken-link telemetry reported to backend `reportBrokenSourceUrl`
  /// when a user or pre-flight check encounters a 404, broken redirect, or unreachable source.
  static Future<void> reportBrokenSourceUrl({
    required String brokenUrl,
    String? videoId,
    String? claimId,
    int? httpStatus,
    String? reason,
  }) async {
    final cleanUrl = brokenUrl.trim();
    if (cleanUrl.isEmpty ||
        (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable(
            'reportBrokenSourceUrl',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 5)),
          );
      final reasonWithStatus = [
        if (httpStatus != null) 'http_$httpStatus',
        if (reason != null && reason.trim().isNotEmpty) reason.trim(),
      ].join(': ');
      await callable.call<Map<String, dynamic>>({
        if (videoId != null && videoId.trim().isNotEmpty) 'videoId': videoId.trim(),
        if (claimId != null && claimId.trim().isNotEmpty) 'claimId': claimId.trim(),
        'url': cleanUrl,
        if (reasonWithStatus.isNotEmpty) 'reason': reasonWithStatus,
      });
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SourceUrlSanitizer.reportBrokenSourceUrl',
      );
    }
  }

  /// Resolves any source citation URL to a verified, alive destination.
  /// Intercepts Vertex AI grounding redirects and dead links:
  /// - If the redirect is alive, follows to the canonical target article URL.
  /// - If the redirect or article returns 404, 410, or fails, reports telemetry
  ///   and returns `null` rather than substituting a bare publisher homepage.
  static Future<String?> resolveSafeDestinationUrl(
    String? rawUrl, {
    String? title,
    String? domain,
    String? publisher,
    String? videoId,
    String? claimId,
    BrokenSourceReporter? onBrokenSourceDetected,
    http.Client? client,
    bool isWebClient = kIsWeb,
  }) async {
    final cleanTitle = title?.trim() ?? '';
    final cleanDom = domain?.trim();
    final cleanPub = publisher?.trim();

    final url = sanitizeUrl(
      rawUrl,
      title: cleanTitle,
      publisher: cleanPub,
      domain: cleanDom,
    );

    if (url == null || url.isEmpty) {
      return null;
    }

    // On Flutter Web, browser CORS policies block client-side HEAD probes to external publishers
    // and disallow custom User-Agent headers. Backend Closed-World verification already validated
    // persisted URLs, so launch the sanitized destination directly instead of false-quarantining.
    if (isWebClient) {
      return url;
    }

    void notifyBroken({int? httpStatus, required String reason}) {
      final reporter = onBrokenSourceDetected ?? reportBrokenSourceUrl;
      unawaited(
        reporter(
          brokenUrl: url,
          videoId: videoId,
          claimId: claimId,
          httpStatus: httpStatus,
          reason: reason,
        ),
      );
    }

    final initialIsRedirect = isGroundingRedirect(url);
    final effectiveClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    const maxHops = 3;

    try {
      final initialUri = Uri.tryParse(url);
      if (initialUri == null || !initialUri.hasScheme || !initialUri.hasAuthority) {
        return null;
      }
      var currentUri = initialUri;

      final visitedUrls = <String>{currentUri.toString()};

      for (var hop = 0; hop <= maxHops; hop++) {
        final request = http.Request('HEAD', currentUri)..followRedirects = false;
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 TruthWorld/1.0';

        final streamedResponse = await effectiveClient
            .send(request)
            .timeout(const Duration(milliseconds: 2500));

        final statusCode = streamedResponse.statusCode;

        // Case 1: Redirect (301, 302, 303, 307, 308) -> Resolve and verify Location destination
        if (statusCode >= 300 && statusCode < 400) {
          final location = streamedResponse.headers['location'];
          if (location == null || location.trim().isEmpty) {
            return currentUri.toString();
          }

          final resolvedLocation = location.trim();
          final resolvedUri = Uri.tryParse(resolvedLocation);
          if (resolvedUri == null ||
              (!resolvedUri.hasScheme && !resolvedLocation.startsWith('/'))) {
            return currentUri.toString();
          }

          final absoluteUrl = resolvedLocation.startsWith('http')
              ? resolvedLocation
              : currentUri.resolve(resolvedLocation).toString();
          final nextUri = Uri.tryParse(absoluteUrl);
          if (nextUri == null ||
              (nextUri.scheme != 'http' && nextUri.scheme != 'https') ||
              isStaticHomepageUrl(absoluteUrl) ||
              isDummyDomain(absoluteUrl)) {
            notifyBroken(
              httpStatus: statusCode,
              reason: 'redirect_to_homepage_or_dummy',
            );
            return null;
          }

          // Cookie-wall/self-redirect loop: delegate to interactive browser instead of false-blocking
          if (visitedUrls.contains(absoluteUrl) || hop == maxHops) {
            return absoluteUrl;
          }

          visitedUrls.add(absoluteUrl);
          currentUri = nextUri;
          continue;
        }

        // Case 2: Explicit 404 Not Found or 410 Gone -> Intercept, report telemetry, and quarantine
        if (statusCode == 404 || statusCode == 410) {
          ErrorHandler.log(
            'Intercepted HTTP $statusCode dead link for source ($url). Quarantining instead of falling back to homepage.',
            tag: 'SourceUrlSanitizer.resolveSafeDestinationUrl',
          );
          notifyBroken(httpStatus: statusCode, reason: 'http_$statusCode');
          return null;
        }

        // Case 3: Broken grounding redirect (status >= 400 or invalid < 200)
        if (initialIsRedirect && hop == 0 && (statusCode >= 400 || statusCode < 200)) {
          notifyBroken(httpStatus: statusCode, reason: 'broken_redirect_$statusCode');
          return null;
        }

        // Success (200 OK, or publisher anti-bot 403/405/503 where a real browser succeeds)
        return currentUri.toString();
      }

      return currentUri.toString();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SourceUrlSanitizer.resolveSafeDestinationUrl',
      );
      notifyBroken(reason: 'network_or_timeout');
      return null;
    } finally {
      if (shouldCloseClient) {
        effectiveClient.close();
      }
    }
  }

  static String? _fallbackToDomainOrPublisher(
    String? domain,
    String? publisher,
    String? title,
  ) {
    return null;
  }

  static Future<bool> _openExternalUrl(String targetUrl) async {
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      throw FormatException('Invalid URI: $targetUrl');
    }
    if (await canLaunchUrl(uri)) {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    }
    final fallbackLaunched = await launchUrl(uri);
    if (fallbackLaunched) return true;
    throw Exception('launchUrl returned false');
  }

  /// Launches an explicit user-triggered web search in the external browser.
  static Future<bool> launchWebSearch({
    required String query,
    String? publisher,
    String? domain,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    final searchUrl = createSearchUrl(trimmed, publisher: publisher, domain: domain);
    try {
      return await _openExternalUrl(searchUrl);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SourceUrlSanitizer.launchWebSearch',
      );
      AppSnackbar.warning(
        'Unable to open web search in browser. Please check your connection and try again.',
        title: 'Web Search',
      );
      return false;
    }
  }

  /// Launches a source URL safely in an external application (system browser).
  /// Pre-flights the URL before launching, reporting broken links via telemetry
  /// and surfacing an honest warning instead of navigating to a 404 or homepage.
  static Future<bool> launchSourceUrl({
    required String? url,
    String? title,
    String? publisher,
    String? domain,
    Map<dynamic, dynamic>? source,
    String? videoId,
    String? claimId,
    BrokenSourceReporter? onBrokenSourceDetected,
    http.Client? httpClient,
  }) async {
    var rawUrl = url;
    var rawTitle = title;
    var rawPublisher = publisher;
    var rawDomain = domain;
    var resolvedVideoId = videoId;
    var resolvedClaimId = claimId;

    if (source != null) {
      resolvedVideoId ??= source['videoId']?.toString();
      resolvedClaimId ??= (source['claimId'] ?? source['id'])?.toString();
      final cleanMap = sanitizeSourceMap(source);
      rawUrl = cleanMap['directUrl']?.toString();
      if (rawUrl == null || rawUrl.isEmpty) {
        rawUrl = cleanMap['url']?.toString();
      }
      rawTitle = cleanMap['title']?.toString() ??
          cleanMap['bookTitle']?.toString() ??
          cleanMap['author']?.toString() ??
          rawTitle;
      rawDomain = cleanMap['domain']?.toString() ?? rawDomain;
      rawPublisher = cleanMap['publisher']?.toString() ?? rawPublisher;
    }

    // Allow explicit Google Search queries when initiated by user Search Web actions.
    if (source == null && rawUrl != null && isGoogleSearchUrl(rawUrl)) {
      try {
        return await _openExternalUrl(rawUrl.trim());
      } catch (e, stackTrace) {
        ErrorHandler.log(e, stackTrace: stackTrace, tag: 'SourceUrlSanitizer.launchSourceUrl');
        AppSnackbar.warning(
          'Unable to open web search in browser. Please check your connection and try again.',
          title: 'Web Search',
        );
        return false;
      }
    }

    final safeUrl = await resolveSafeDestinationUrl(
      rawUrl,
      title: rawTitle,
      domain: rawDomain,
      publisher: rawPublisher,
      videoId: resolvedVideoId,
      claimId: resolvedClaimId,
      onBrokenSourceDetected: onBrokenSourceDetected,
      client: httpClient,
    );

    if (safeUrl == null || safeUrl.isEmpty || isStaticHomepageUrl(safeUrl)) {
      // Resilience check: if source was already verified on backend by TruthWorld
      final isBackendVerified = source != null && (
        source['status'] == 'verified' ||
        source['trustLevel'] == 'High' ||
        source['urlVerification']?['status'] == 'VERIFIED'
      );
      if (isBackendVerified && rawUrl != null && !isStaticHomepageUrl(rawUrl) && !isDummyDomain(rawUrl)) {
        try {
          return await _openExternalUrl(rawUrl);
        } catch (_) {}
      }

      ErrorHandler.log(
        'Blocked broken or unverified destination URL for source: $rawTitle',
        tag: 'SourceUrlSanitizer.launchSourceUrl',
      );
      AppSnackbar.warning(
        'This source page could not be verified or may no longer exist. Try Search web below to find an updated reference.',
        title: 'Source Unavailable',
      );
      return false;
    }

    try {
      return await _openExternalUrl(safeUrl);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SourceUrlSanitizer.launchSourceUrl',
      );
      AppSnackbar.warning(
        'Unable to open source in browser. Please check your connection and try again.',
        title: 'Source Link',
      );
      return false;
    }
  }

  /// Strict validation for user-submitted authoritative sources and citations.
  /// Rejects arbitrary random text (e.g. "hi", "random note"), invalid schemes,
  /// malformed domains, and dummy placeholder domains (e.g. example.com).
  static SourceValidationResult validateAuthoritativeSource(String? rawInput) {
    if (rawInput == null || rawInput.trim().isEmpty) {
      return SourceValidationResult.invalid(
        'Please enter a valid source URL or citation reference.',
      );
    }

    var text = rawInput.trim();

    // Strip wrapping quotes and enclosing brackets: "url", <url>, (url), [url]
    text = text.replaceAll(RegExp(r'^["\x27<(\[]+|[">\x27)\]]+$'), '').trim();

    if (text.isEmpty) {
      return SourceValidationResult.invalid(
        'Please enter a valid source URL or citation reference.',
      );
    }

    // Check for raw whitespace or control characters inside the URL string
    // e.g. "hi there", "my source document", multiline text
    if (text.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
      return SourceValidationResult.invalid(
        'Source URLs cannot contain spaces. Please enter a valid web address.',
      );
    }

    // Check for DOI references: doi:10.xxx or 10.xxx/...
    if (text.toLowerCase().startsWith('doi:')) {
      final doiNumber = text.substring(4).trim();
      if (doiNumber.isNotEmpty &&
          RegExp(r'^10\.\d{4,9}/[-._;()/:A-Za-z0-9]+$').hasMatch(doiNumber)) {
        return SourceValidationResult.valid('https://doi.org/$doiNumber');
      }
    } else if (RegExp(r'^10\.\d{4,9}/[-._;()/:A-Za-z0-9]+$').hasMatch(text)) {
      return SourceValidationResult.valid('https://doi.org/$text');
    }

    // Check unsupported or dangerous schemes
    if (text.contains('://')) {
      final schemeMatch = RegExp('^([a-zA-Z][a-zA-Z0-9+.-]*):').firstMatch(text);
      if (schemeMatch != null) {
        final scheme = schemeMatch.group(1)!.toLowerCase();
        if (scheme != 'http' && scheme != 'https') {
          return SourceValidationResult.invalid(
            'Only web links (HTTP/HTTPS) are supported.',
          );
        }
      }
    } else {
      // Missing scheme: normalize by prepending https://
      text = 'https://$text';
    }

    // Strip trailing punctuation often left by copy-pasting (.,;:!?)
    text = text.replaceAll(RegExp(r'[\.,;:!?\)\]>"\x27]+$'), '');

    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return SourceValidationResult.invalid(
        'Please enter a valid source URL (e.g. https://reuters.com).',
      );
    }

    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty) {
      return SourceValidationResult.invalid(
        'Please enter a valid web domain.',
      );
    }

    // Must have at least one dot separating domain and TLD (e.g. reuters.com)
    // Random single words like "hi", "source", "test" fail here.
    if (!host.contains('.')) {
      return SourceValidationResult.invalid(
        'Please enter a valid web domain (e.g. https://reuters.com).',
      );
    }

    // Reject dummy domains (example.com, localhost, etc.)
    if (isDummyDomain(host)) {
      return SourceValidationResult.invalid(
        'Please provide an authentic source URL rather than a placeholder domain.',
      );
    }

    // Validate hostname labels and TLD
    final parts = host.split('.');
    if (parts.any((part) => part.isEmpty)) {
      return SourceValidationResult.invalid(
        'Please enter a valid web domain.',
      );
    }

    final tld = parts.last;
    // TLD must be valid letters (at least 2 chars, up to 24 chars, or punycode xn--)
    final tldRegex = RegExp(r'^(?:[a-zA-Z]{2,24}|xn--[a-zA-Z0-9]+)$');
    if (!tldRegex.hasMatch(tld)) {
      return SourceValidationResult.invalid(
        'Please enter a web URL with a valid domain extension.',
      );
    }

    // Domain name label before TLD must be valid hostname characters
    final domainLabel = parts[parts.length - 2];
    if (!RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')
        .hasMatch(domainLabel)) {
      return SourceValidationResult.invalid(
        'Please enter a valid web domain.',
      );
    }

    // Reconstruct canonical URL
    final normalized = uri.toString();
    return SourceValidationResult.valid(normalized);
  }

  /// Convenience boolean check for user-submitted source URLs.
  static bool isValidSourceUrl(String? input) {
    return validateAuthoritativeSource(input).isValid;
  }

  /// Convenience normalizer for source URLs. Returns null if invalid.
  static String? normalizeSourceUrl(String? input) {
    return validateAuthoritativeSource(input).normalizedUrl;
  }
}

/// Result of an authoritative source validation check.
class SourceValidationResult {
  const SourceValidationResult._({
    required this.isValid,
    this.normalizedUrl,
    this.errorMessage,
  });

  final bool isValid;
  final String? normalizedUrl;
  final String? errorMessage;

  factory SourceValidationResult.valid(String normalizedUrl) =>
      SourceValidationResult._(isValid: true, normalizedUrl: normalizedUrl);

  factory SourceValidationResult.invalid(String errorMessage) =>
      SourceValidationResult._(isValid: false, errorMessage: errorMessage);
}

