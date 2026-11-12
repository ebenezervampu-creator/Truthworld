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

    test('Never synthesizes domain homepage when raw URL is empty', () {
      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        '',
        title: 'CDC Vaccine Safety Statistics',
        publisher: 'CDC',
        domain: 'cdc.gov',
      );
      expect(sanitized, isNull);
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

    test('Strips synthetic Google search query URLs without substituting a homepage', () {
      final sourceMap = {
        'title': 'How Much Does It Cost to Go to Space in 2026? - Outer Space Trip',
        'url':
            'https://www.google.com/search?q=How%20Much%20Does%20It%20Cost%20to%20Go%20to%20Space%20in%202026%3F%20Outer%20Space%20Trip',
        'domain': 'outerspacetrip.com',
        'publisher': 'Outer Space Trip',
      };

      final sanitized = SourceUrlSanitizer.sanitizeSourceMap(sourceMap);

      expect(sanitized['url'], isNull);
      expect(sanitized['directUrl'], isNull);
      expect(sanitized['link'], isNull);
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
        if (request.url.host.contains('vertexaisearch')) {
          return http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {'location': canonicalArticleUrl},
          );
        }
        return http.StreamedResponse(
          const Stream.empty(),
          200,
        );
      });

      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        redirectUrl,
        domain: 'outerspacetrip.com',
        title: 'How Much Does It Cost to Go to Space in 2026? - Outer Space Trip',
        client: mockClient,
        isWebClient: false,
      );

      expect(safeUrl, equals(canonicalArticleUrl));
    });

    test('resolveSafeDestinationUrl quarantines HTTP 302 redirect when final destination returns HTTP 404', () async {
      const redirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/token404dest';
      const deadTargetUrl =
          'https://www.mayoclinic.org/healthy-lifestyle/deleted-page-404';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        if (request.url.host.contains('vertexaisearch')) {
          return http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {'location': deadTargetUrl},
          );
        }
        return http.StreamedResponse(
          const Stream.empty(),
          404,
        );
      });

      String? reportedUrl;
      int? reportedStatus;
      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        redirectUrl,
        domain: 'mayoclinic.org',
        client: mockClient,
        isWebClient: false,
        onBrokenSourceDetected: ({
          required String brokenUrl,
          String? videoId,
          String? claimId,
          int? httpStatus,
          String? reason,
        }) async {
          reportedUrl = brokenUrl;
          reportedStatus = httpStatus;
        },
      );

      expect(safeUrl, isNull);
      expect(reportedUrl, equals(redirectUrl));
      expect(reportedStatus, equals(404));
    });

    test('resolveSafeDestinationUrl skips browser CORS HEAD pre-flight on Web and returns sanitized URL directly', () async {
      const webVerifiedUrl =
          'https://www.reuters.com/world/verified-article';
      var httpCalled = false;

      final mockClient = MockClient.streaming((request, bodyStream) async {
        httpCalled = true;
        throw Exception('Browser CORS would block this request');
      });

      var reported = false;
      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        webVerifiedUrl,
        domain: 'reuters.com',
        client: mockClient,
        isWebClient: true,
        onBrokenSourceDetected: ({
          required String brokenUrl,
          String? videoId,
          String? claimId,
          int? httpStatus,
          String? reason,
        }) async {
          reported = true;
        },
      );

      expect(httpCalled, isFalse);
      expect(reported, isFalse);
      expect(safeUrl, equals(webVerifiedUrl));
    });

    test('resolveSafeDestinationUrl quarantines HTTP 404 from expired grounding redirect instead of returning homepage', () async {
      const deadRedirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/expired_token';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          404,
        );
      });

      String? reportedUrl;
      int? reportedStatus;
      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        deadRedirectUrl,
        domain: 'outerspacetrip.com',
        title: 'Space Travel Guide',
        videoId: 'vid_test_1',
        claimId: 'claim_18',
        onBrokenSourceDetected: ({
          required String brokenUrl,
          String? videoId,
          String? claimId,
          int? httpStatus,
          String? reason,
        }) async {
          reportedUrl = brokenUrl;
          reportedStatus = httpStatus;
        },
        client: mockClient,
      );

      expect(safeUrl, isNull);
      expect(reportedUrl, equals(deadRedirectUrl));
      expect(reportedStatus, equals(404));
    });

    test('resolveSafeDestinationUrl quarantines HTTP 404 on dead article link instead of falling back to domain root', () async {
      const deadArticleUrl =
          'https://reuters.com/world/deleted-broken-article-404';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          404,
        );
      });

      String? reportedUrl;
      int? reportedStatus;
      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        deadArticleUrl,
        domain: 'reuters.com',
        onBrokenSourceDetected: ({
          required String brokenUrl,
          String? videoId,
          String? claimId,
          int? httpStatus,
          String? reason,
        }) async {
          reportedUrl = brokenUrl;
          reportedStatus = httpStatus;
        },
        client: mockClient,
      );

      expect(safeUrl, isNull);
      expect(reportedUrl, equals(deadArticleUrl));
      expect(reportedStatus, equals(404));
    });

    test('resolveSafeDestinationUrl preserves HTTP 403 bot-blocked article URL for interactive browser launch', () async {
      const protectedUrl = 'https://www.reuters.com/world/protected-article';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          403,
        );
      });

      var reported = false;
      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        protectedUrl,
        domain: 'reuters.com',
        onBrokenSourceDetected: ({
          required String brokenUrl,
          String? videoId,
          String? claimId,
          int? httpStatus,
          String? reason,
        }) async {
          reported = true;
        },
        client: mockClient,
      );

      expect(safeUrl, equals(protectedUrl));
      expect(reported, isFalse);
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

    test('resolveFallbackUrl returns null instead of synthesizing homepages or search URLs', () {
      final nasaFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'NASA',
        title: 'Risks of Human Spaceflight - NASA',
      );
      expect(nasaFallback, isNull);

      final wionFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'WION',
        title: "Budget 2024: India's Department of Space - WION",
      );
      expect(wionFallback, isNull);

      final visualFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'Visual Capitalist',
        title: 'The Cost of Space Flight - Visual Capitalist',
      );
      expect(visualFallback, isNull);

      final genericFallback = SourceUrlSanitizer.resolveFallbackUrl(
        domain: 'Verified Source',
        title: r'How Much Does It Cost to Go to Space? $150K to $55M in 2026',
      );
      expect(genericFallback, isNull);
    });

    test('resolveSafeDestinationUrl quarantines dead redirect instead of falling back to NASA homepage', () async {
      const deadRedirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/expired_token';

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          const Stream.empty(),
          404,
        );
      });

      String? reportedUrl;
      final safeUrl = await SourceUrlSanitizer.resolveSafeDestinationUrl(
        deadRedirectUrl,
        domain: 'NASA',
        publisher: 'NASA',
        title: 'Risks of Human Spaceflight - NASA',
        onBrokenSourceDetected: ({
          required String brokenUrl,
          String? videoId,
          String? claimId,
          int? httpStatus,
          String? reason,
        }) async {
          reportedUrl = brokenUrl;
        },
        client: mockClient,
      );

      expect(safeUrl, isNull);
      expect(reportedUrl, equals(deadRedirectUrl));
    });

    test('sanitizeUrl rejects malformed single-label host like https://nasa instead of substituting a homepage', () {
      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        'https://nasa',
        title: 'Risks of Human Spaceflight - NASA',
        domain: 'NASA',
      );
      expect(sanitized, isNull);
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

    test('sanitizeUrl rejects dummy anchor "#" instead of fabricating a publisher homepage or search URL', () {
      final healed1 = SourceUrlSanitizer.sanitizeUrl(
        '#',
        title: 'Risks of Human Spaceflight - NASA',
        publisher: 'NASA',
      );
      expect(healed1, isNull);

      final healed2 = SourceUrlSanitizer.sanitizeUrl(
        '#',
        title: 'Space Tourism Trends',
        publisher: 'Visual Capitalist',
      );
      expect(healed2, isNull);

      final healed3 = SourceUrlSanitizer.sanitizeUrl(
        '#',
        title: 'Unknown Study Results',
      );
      expect(healed3, isNull);
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

    test('isStaticHomepageUrl accurately identifies static root homepages vs direct article links', () {
      // Static root homepages (must be detected)
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://en.wikipedia.org'), isTrue);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://en.wikipedia.org/'), isTrue);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://bbc.com'), isTrue);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://www.thehindu.com/'), isTrue);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://who.int/index.html'), isTrue);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://cdc.gov/home'), isTrue);
      expect(SourceUrlSanitizer.isStaticHomepageUrl(null), isTrue);
      expect(SourceUrlSanitizer.isStaticHomepageUrl(''), isTrue);

      // Direct article / document links (must NOT be treated as static homepages)
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://en.wikipedia.org/wiki/Apollo_11'), isFalse);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://www.thehindu.com/sci-tech/chandrayaan-3/article123.ece'), isFalse);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://doi.org/10.1038/s41586-020-2649-2'), isFalse);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://vertexaisearch.cloud.google.com/grounding-api-redirect/token123'), isFalse);
      expect(SourceUrlSanitizer.isStaticHomepageUrl('https://www.google.com/search?q=Apollo+11'), isFalse);
    });

    test('resolveDirectNavigationUrl converts static homepages into direct article navigations', () {
      // Wikipedia static root -> direct topic search
      final wikiDirect = SourceUrlSanitizer.resolveDirectNavigationUrl(
        url: 'https://en.wikipedia.org',
        title: 'Theory of Relativity - Wikipedia',
      );
      expect(wikiDirect, equals('https://en.wikipedia.org/wiki/Special:Search?search=Theory%20of%20Relativity'));

      // Bare news publisher -> targeted article search
      final newsDirect = SourceUrlSanitizer.resolveDirectNavigationUrl(
        url: 'https://thehindu.com',
        title: 'Chandrayaan-3 lands on the Moon',
        domain: 'thehindu.com',
      );
      expect(newsDirect, contains('google.com/search?q='));
      expect(newsDirect, contains('Chandrayaan-3'));
      expect(newsDirect, contains('thehindu.com'));

      // Direct article URL -> preserved 100% as-is without modification
      const directArticle = 'https://www.thehindu.com/sci-tech/chandrayaan-3/article123.ece';
      final untouched = SourceUrlSanitizer.resolveDirectNavigationUrl(
        url: directArticle,
        title: 'Chandrayaan-3 lands on the Moon',
      );
      expect(untouched, equals(directArticle));
    });
  });
}
