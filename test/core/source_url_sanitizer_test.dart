import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';

void main() {
  group('SourceUrlSanitizer Tests', () {
    test('Identifies Vertex AI Grounding redirects correctly', () {
      const redirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZlYQEujmlCWSRRX5WyWRzlZfKpA7v4JHbIXRIaQc9ZjbTLBZdKWFHKjoqAa2qPqdskZyRdwHwgL__Nd7MuTLJ3tKYC4dW3IMk';
      expect(SourceUrlSanitizer.isGroundingRedirect(redirectUrl), isTrue);

      const altRedirect =
          'https://www.google.com/grounding-api-redirect/token123';
      expect(SourceUrlSanitizer.isGroundingRedirect(altRedirect), isTrue);

      const regularUrl = 'https://www.nasa.gov/mission_pages/station';
      expect(SourceUrlSanitizer.isGroundingRedirect(regularUrl), isFalse);

      expect(SourceUrlSanitizer.isGroundingRedirect(null), isFalse);
      expect(SourceUrlSanitizer.isGroundingRedirect(''), isFalse);
    });

    test('Identifies dummy / placeholder domains', () {
      expect(SourceUrlSanitizer.isDummyDomain('https://example.com/test'), isTrue);
      expect(SourceUrlSanitizer.isDummyDomain('http://localhost:8080/api'), isTrue);
      expect(SourceUrlSanitizer.isDummyDomain('https://placeholder.com/doc'), isTrue);
      expect(SourceUrlSanitizer.isDummyDomain('https://www.reuters.com/world'), isFalse);
    });

    test('Preserves Vertex AI Grounding redirects for direct browser navigation', () {
      const redirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZlYQEujmlCWSRRX5WyWRzlZfKpA7v4JHbIXRIaQc9ZjbTLBZdKWFHKjoqAa2qPqdskZyRdwHwgL__Nd7MuTLJ3tKYC4dW3IMk';

      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        redirectUrl,
        title: 'Risks of Human Spaceflight - NASA',
        domain: 'nasa.gov',
        publisher: 'NASA',
      );

      expect(sanitized, isNotNull);
      expect(sanitized, equals(redirectUrl));
      expect(sanitized!.contains('grounding-api-redirect'), isTrue);
    });

    test('Normalizes missing scheme and strips trailing punctuation', () {
      const messyUrl = 'nasa.gov/news/article.html).';
      final cleaned = SourceUrlSanitizer.sanitizeUrl(messyUrl);
      expect(cleaned, equals('https://nasa.gov/news/article.html'));

      const quotedUrl = '"https://en.wikipedia.org/wiki/Apollo_11"';
      final unquoted = SourceUrlSanitizer.sanitizeUrl(quotedUrl);
      expect(unquoted, equals('https://en.wikipedia.org/wiki/Apollo_11'));
    });

    test('Falls back to domain when raw URL is empty but domain is present', () {
      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        '',
        title: 'CDC Vaccine Safety Statistics',
        publisher: 'CDC',
        domain: 'cdc.gov',
      );
      expect(sanitized, equals('https://cdc.gov'));
    });

    test('Returns null when both URL and domain are missing or empty', () {
      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        null,
      );
      expect(sanitized, isNull);
    });

    test('Resolves human-readable display domain correctly', () {
      final domain1 = SourceUrlSanitizer.resolveDisplayDomain(
        'https://vertexaisearch.cloud.google.com/grounding-api-redirect/token',
        title: 'Artemis Program - NASA',
        publisher: 'NASA',
      );
      expect(domain1, equals('NASA'));

      final domain2 = SourceUrlSanitizer.resolveDisplayDomain(
        'https://www.nature.com/articles/s41586-024',
        title: 'Quantum computing advances',
      );
      expect(domain2, equals('nature.com'));
    });

    test('Validates sources accurately to exclude broken/empty entries', () {
      expect(
        SourceUrlSanitizer.isValidSource({
          'title': 'World Health Organization Bulletin',
          'url': 'https://www.who.int/bulletin',
        }),
        isTrue,
      );

      // Dummy domain without real title should be invalid
      expect(
        SourceUrlSanitizer.isValidSource({
          'title': 'Reference Source',
          'url': 'https://example.com',
        }),
        isFalse,
      );

      // Empty map or null should be invalid
      expect(SourceUrlSanitizer.isValidSource({}), isFalse);
      expect(SourceUrlSanitizer.isValidSource(null), isFalse);
    });

    test('Sanitizes full source map seamlessly and preserves grounding links', () {
      final sourceMap = {
        'title': 'Apollo 11 Mission Overview - NASA',
        'url':
            'https://vertexaisearch.cloud.google.com/grounding-api-redirect/token12345',
        'domain': 'vertexaisearch.cloud.google.com',
        'publisher': 'NASA',
      };

      final sanitized = SourceUrlSanitizer.sanitizeSourceMap(sourceMap);

      expect(sanitized['url'], equals('https://vertexaisearch.cloud.google.com/grounding-api-redirect/token12345'));
      expect(sanitized['directUrl'], equals('https://vertexaisearch.cloud.google.com/grounding-api-redirect/token12345'));
      expect(sanitized['domain'], equals('NASA'));
    });

    test('Recovers authentic destination if URL was previously saved as a Google search query', () {
      final sourceMap = {
        'title': 'How Much Does It Cost to Go to Space in 2026? - Outer Space Trip',
        'url':
            'https://www.google.com/search?q=How%20Much%20Does%20It%20Cost%20to%20Go%20to%20Space%20in%202026%3F%20Outer%20Space%20Trip',
        'domain': 'outerspacetrip.com',
        'publisher': 'Outer Space Trip',
      };

      final sanitized = SourceUrlSanitizer.sanitizeSourceMap(sourceMap);

      expect(sanitized['url'], equals('https://outerspacetrip.com'));
      expect(sanitized['url'].toString().contains('google.com/search'), isFalse);
    });

    test('Strictly rejects random text as authoritative sources', () {
      // Single random words (the exact user reported issue "hi")
      expect(SourceUrlSanitizer.isValidSourceUrl('hi'), isFalse);
      expect(SourceUrlSanitizer.validateAuthoritativeSource('hi').isValid, isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('hello'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('asdfgh'), isFalse);

      // Random sentences / phrases with spaces
      expect(SourceUrlSanitizer.isValidSourceUrl('hello world'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('just a note about this video'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('reuters news today'), isFalse);

      // Empty or whitespace
      expect(SourceUrlSanitizer.isValidSourceUrl(null), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl(''), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('   '), isFalse);
    });

    test('Rejects dummy placeholder domains and unsupported protocols', () {
      // Dummy domains
      expect(SourceUrlSanitizer.isValidSourceUrl('https://example.com'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('https://example.com/source-document'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('example.com/doc'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('http://localhost:3000'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('https://placeholder.com/doc'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('https://fake.com/article'), isFalse);

      // Unsupported protocols
      expect(SourceUrlSanitizer.isValidSourceUrl('ftp://files.org/pub'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('javascript:alert(1)'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('file:///etc/passwd'), isFalse);

      // Malformed hostnames
      expect(SourceUrlSanitizer.isValidSourceUrl('https://..com'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('https://test.'), isFalse);
      expect(SourceUrlSanitizer.isValidSourceUrl('https://not-a-domain'), isFalse);
    });

    test('Accepts and normalizes authentic authoritative sources and DOIs', () {
      // Full HTTPS URL
      final res1 = SourceUrlSanitizer.validateAuthoritativeSource('https://reuters.com/world/article-123');
      expect(res1.isValid, isTrue);
      expect(res1.normalizedUrl, equals('https://reuters.com/world/article-123'));

      // Domain without scheme (auto-prepends https://)
      final res2 = SourceUrlSanitizer.validateAuthoritativeSource('nature.com/articles/s41586-024');
      expect(res2.isValid, isTrue);
      expect(res2.normalizedUrl, equals('https://nature.com/articles/s41586-024'));

      // www subdomain
      final res3 = SourceUrlSanitizer.validateAuthoritativeSource('www.bbc.com/news');
      expect(res3.isValid, isTrue);
      expect(res3.normalizedUrl, equals('https://www.bbc.com/news'));

      // Wikipedia
      final res4 = SourceUrlSanitizer.validateAuthoritativeSource('https://en.wikipedia.org/wiki/Epistemology');
      expect(res4.isValid, isTrue);

      // Quoted URL stripped cleanly
      final res5 = SourceUrlSanitizer.validateAuthoritativeSource('"https://who.int/news/item/1"');
      expect(res5.isValid, isTrue);
      expect(res5.normalizedUrl, equals('https://who.int/news/item/1'));

      // DOI prefix
      final res6 = SourceUrlSanitizer.validateAuthoritativeSource('doi:10.1038/s41586-020-2649-2');
      expect(res6.isValid, isTrue);
      expect(res6.normalizedUrl, equals('https://doi.org/10.1038/s41586-020-2649-2'));

      // Bare DOI
      final res7 = SourceUrlSanitizer.validateAuthoritativeSource('10.1038/s41586-020-2649-2');
      expect(res7.isValid, isTrue);
      expect(res7.normalizedUrl, equals('https://doi.org/10.1038/s41586-020-2649-2'));
    });

    test('resolveSafeDestinationUrl follows HTTP 302 redirect from grounding link to canonical article', () async {
      const redirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/token123';
      const canonicalArticleUrl =
          'https://outerspacetrip.com/how-much-does-it-cost-to-go-to-space-in-2026/';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          302,
          headers: {'location': canonicalArticleUrl},
        );
      });

      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        redirectUrl,
        domain: 'outerspacetrip.com',
        title: 'How Much Does It Cost to Go to Space in 2026? - Outer Space Trip',
        client: mockClient,
      );

      expect(safeUrl, equals(canonicalArticleUrl));
    });

    test('resolveSafeDestinationUrl intercepts HTTP 404 from expired grounding redirect and falls back to domain', () async {
      const deadRedirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/expired_token';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          404,
        );
      });

      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        deadRedirectUrl,
        domain: 'outerspacetrip.com',
        title: 'Space Travel Guide',
        client: mockClient,
      );

      expect(safeUrl, equals('https://outerspacetrip.com'));
      expect(safeUrl!.contains('vertexaisearch'), isFalse);
    });

    test('resolveSafeDestinationUrl intercepts HTTP 404 on dead article link and falls back to domain root', () async {
      const deadArticleUrl =
          'https://reuters.com/world/deleted-broken-article-404';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          404,
        );
      });

      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        deadArticleUrl,
        domain: 'reuters.com',
        client: mockClient,
      );

      expect(safeUrl, equals('https://reuters.com'));
    });

    test('resolveSafeDestinationUrl preserves alive 200 URLs', () async {
      const liveUrl = 'https://nasa.gov/mission_pages/station';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          200,
        );
      });

      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        liveUrl,
        domain: 'nasa.gov',
        client: mockClient,
      );

      expect(safeUrl, equals(liveUrl));
    });

    test('resolveCanonicalDomain correctly resolves publisher names to authoritative FQDNs', () {
      expect(SourceUrlSanitizer.resolveCanonicalDomain('NASA'), equals('nasa.gov'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('WION'), equals('wionews.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('Visual Capitalist'), equals('visualcapitalist.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('MDPI'), equals('mdpi.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('HeroX'), equals('herox.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('Wikipedia'), equals('wikipedia.org'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('outerspacetrip.com'), equals('outerspacetrip.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('Verified Source'), isNull);
      expect(SourceUrlSanitizer.resolveCanonicalDomain('hi'), isNull);
    });

    test('isValidDomain correctly distinguishes valid FQDNs from plain entity names', () {
      expect(SourceUrlSanitizer.isValidDomain('nasa.gov'), isTrue);
      expect(SourceUrlSanitizer.isValidDomain('visualcapitalist.com'), isTrue);
      expect(SourceUrlSanitizer.isValidDomain('wionews.com'), isTrue);
      expect(SourceUrlSanitizer.isValidDomain('en.wikipedia.org'), isTrue);

      // Invalid hostnames that would produce DNS NXDOMAIN errors
      expect(SourceUrlSanitizer.isValidDomain('nasa'), isFalse);
      expect(SourceUrlSanitizer.isValidDomain('wion'), isFalse);
      expect(SourceUrlSanitizer.isValidDomain('Visual Capitalist'), isFalse);
      expect(SourceUrlSanitizer.isValidDomain('Verified Source'), isFalse);
      expect(SourceUrlSanitizer.isDummyDomain('example.com'), isTrue);
    });

    test('resolveFallbackUrl never produces broken non-FQDN URLs like https://nasa', () {
      final nasaFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'NASA',
        title: 'Risks of Human Spaceflight - NASA',
      );
      expect(nasaFallback, equals('https://nasa.gov'));
      expect(nasaFallback, isNot(equals('https://NASA')));
      expect(nasaFallback, isNot(equals('https://nasa')));

      final wionFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'WION',
        title: "Budget 2024: India's Department of Space - WION",
      );
      expect(wionFallback, equals('https://wionews.com'));
      expect(wionFallback, isNot(equals('https://WION')));

      final visualFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'Visual Capitalist',
        title: 'The Cost of Space Flight - Visual Capitalist',
      );
      expect(visualFallback, equals('https://visualcapitalist.com'));
      expect(visualFallback, isNot(contains('https://Visual')));

      // Unknown publisher with title falls back to 100% reliable Google search URL
      final genericFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'Verified Source',
        title: r'How Much Does It Cost to Go to Space? $150K to $55M in 2026',
      );
      expect(genericFallback, contains('google.com/search?q='));
      expect(genericFallback, isNot(contains('Verified')));
    });

    test('resolveSafeDestinationUrl intercepts dead redirect and safely falls back to canonical domain for NASA', () async {
      const deadRedirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/expired_token';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          404,
        );
      });

      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        deadRedirectUrl,
        domain: 'NASA',
        publisher: 'NASA',
        title: 'Risks of Human Spaceflight - NASA',
        client: mockClient,
      );

      // Must resolve to https://nasa.gov and NEVER https://nasa!
      expect(safeUrl, equals('https://nasa.gov'));
      expect(safeUrl, isNot(equals('https://nasa')));
    });

    test('sanitizeUrl repairs malformed host like https://nasa to https://nasa.gov', () {
      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        'https://nasa',
        title: 'Risks of Human Spaceflight - NASA',
        domain: 'NASA',
      );
      expect(sanitized, equals('https://nasa.gov'));
    });

    test('isBlankOrDummyUrl correctly identifies empty, dummy anchors, and invalid schemas', () {
      expect(SourceUrlSanitizer.isBlankOrDummyUrl(null), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl(''), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('   '), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('#'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('/'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('about:blank'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('null'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('undefined'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('none'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('n/a'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('http://#'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('https://#'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('javascript:void(0)'), isTrue);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('https://example.com'), isFalse);
      expect(SourceUrlSanitizer.isBlankOrDummyUrl('https://nasa.gov'), isFalse);
    });

    test('sanitizeUrl safely heals dummy anchor "#" using publisher or title', () {
      final healed1 = SourceUrlSanitizer.sanitizeUrl(
        '#',
        title: 'Risks of Human Spaceflight - NASA',
        publisher: 'NASA',
      );
      expect(healed1, equals('https://nasa.gov'));

      final healed2 = SourceUrlSanitizer.sanitizeUrl(
        '#',
        title: 'Space Tourism Trends',
        publisher: 'Visual Capitalist',
      );
      expect(healed2, equals('https://visualcapitalist.com'));

      final healed3 = SourceUrlSanitizer.sanitizeUrl(
        '#',
        title: 'Unknown Study Results',
      );
      expect(healed3, contains('google.com/search?q='));
    });

    test('resolveCanonicalDomain covers newly added global publishers', () {
      expect(SourceUrlSanitizer.resolveCanonicalDomain('ISRO'), equals('isro.gov.in'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('ESA'), equals('esa.int'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('SpaceX'), equals('spacex.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('The Lancet'), equals('thelancet.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('NEJM'), equals('nejm.org'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('Nature'), equals('nature.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('Science'), equals('science.org'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('Bloomberg'), equals('bloomberg.com'));
      expect(SourceUrlSanitizer.resolveCanonicalDomain('CERN'), equals('cern.ch'));
    });
  });
}
