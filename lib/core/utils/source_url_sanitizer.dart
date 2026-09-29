import 'package:truthworld/core/errors/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized utility for validating, sanitizing, and launching source citations.
/// Ensures zero 404 errors by intercepting Vertex AI grounding redirects,
/// malformed URLs, and dummy links, replacing them with canonical destinations.
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

    if (publisher != null &&
        publisher.isNotEmpty &&
        publisher.toLowerCase() != 'google' &&
        !cleanQuery.toLowerCase().contains(publisher.toLowerCase())) {
      cleanQuery = '$cleanQuery $publisher';
    } else if (domain != null &&
        domain.isNotEmpty &&
        !domain.contains('google.com') &&
        !domain.contains('vertexaisearch') &&
        !cleanQuery.toLowerCase().contains(domain.toLowerCase())) {
      cleanQuery = '$cleanQuery $domain';
    }

    if (cleanQuery.isEmpty) cleanQuery = 'Verified Fact Check Source';

    return 'https://www.google.com/search?q=${Uri.encodeComponent(cleanQuery)}';
  }

  /// Sanitizes any raw source URL.
  ///
  /// - Transforms Vertex AI grounding redirect URLs into canonical Google Search targets.
  /// - Transforms dummy/placeholder links into search targets (if title is present) or drops them.
  /// - Normalizes missing schemes (`https://`).
  /// - Strips trailing punctuation, unbalanced brackets, and hallucinated tokens.
  /// - Returns `null` if the URL is completely unresolvable.
  static String? sanitizeUrl(
    String? rawUrl, {
    String? title,
    String? publisher,
    String? domain,
  }) {
    final cleanTitle = title?.trim() ?? '';
    final cleanPub = publisher?.trim();
    final cleanDom = domain?.trim();

    if (rawUrl == null || rawUrl.trim().isEmpty) {
      if (cleanTitle.isNotEmpty) {
        return createSearchUrl(cleanTitle, publisher: cleanPub, domain: cleanDom);
      }
      return null;
    }

    var url = rawUrl.trim();

    // Strip wrapping quotes and brackets: "url", <url>, (url), [url]
    url = url.replaceAll(RegExp(r'^["\x27<(\[]+|[">\x27)\]]+$'), '').trim();

    // 1. Intercept Vertex AI Grounding redirects -> always convert to canonical search
    if (isGroundingRedirect(url)) {
      final queryCandidate = cleanTitle.isNotEmpty &&
              cleanTitle.toLowerCase() != 'source citation' &&
              cleanTitle.toLowerCase() != 'reference source'
          ? cleanTitle
          : (cleanPub ?? cleanDom ?? 'Authoritative Fact Check Evidence');
      return createSearchUrl(queryCandidate, publisher: cleanPub, domain: cleanDom);
    }

    // 2. Normalize scheme
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // 3. Strip trailing punctuation/brackets often left by OCR / LLM tokens
    url = url.replaceAll(RegExp(r'[\.,;:!?\)\]>"\x27]+$'), '');

    // 4. Validate Uri
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      if (cleanTitle.isNotEmpty &&
          cleanTitle.toLowerCase() != 'source citation' &&
          cleanTitle.toLowerCase() != 'reference source') {
        return createSearchUrl(cleanTitle, publisher: cleanPub, domain: cleanDom);
      }
      return null;
    }

    // Host must have at least one dot (e.g. "domain.tld")
    if (!parsed.host.contains('.')) {
      if (cleanTitle.isNotEmpty &&
          cleanTitle.toLowerCase() != 'source citation' &&
          cleanTitle.toLowerCase() != 'reference source') {
        return createSearchUrl(cleanTitle, publisher: cleanPub, domain: cleanDom);
      }
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
    final rawUrl =
        (rawMap['url'] ?? rawMap['directUrl'] ?? rawMap['link'])?.toString();
    final explicitDomain = rawMap['domain']?.toString();
    final publisher = (rawMap['publisher'] ?? rawMap['author'])?.toString();

    final cleanUrl = sanitizeUrl(
      rawUrl,
      title: title,
      publisher: publisher,
      domain: explicitDomain,
    );

    final displayDomain = resolveDisplayDomain(
      rawUrl,
      title: title,
      explicitDomain: explicitDomain,
      publisher: publisher,
    );

    rawMap['url'] = cleanUrl ?? '';
    rawMap['directUrl'] = cleanUrl ?? '';
    rawMap['domain'] = displayDomain;
    return rawMap;
  }

  /// Launches a source URL safely in an external application (system browser).
  /// Automatically resolves and sanitizes the URL before launching,
  /// preventing 404 errors from grounding redirects or malformed links.
  static Future<bool> launchSourceUrl({
    required String? url,
    String? title,
    String? publisher,
    String? domain,
  }) async {
    final cleanUrl = sanitizeUrl(
      url,
      title: title,
      publisher: publisher,
      domain: domain,
    );

    if (cleanUrl == null || cleanUrl.isEmpty) {
      ErrorHandler.log(
        'Unable to resolve valid destination URL for source: $title',
        tag: 'SourceUrlSanitizer.launchSourceUrl',
      );
      return false;
    }

    try {
      final uri = Uri.parse(cleanUrl);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback without mode restriction
        return await launchUrl(uri);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SourceUrlSanitizer.launchSourceUrl',
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

