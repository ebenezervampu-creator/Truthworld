import 'package:flutter_test/flutter_test.dart';
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

    test('Converts Vertex AI Grounding redirects to reliable Google Search URLs', () {
      const redirectUrl =
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZlYQEujmlCWSRRX5WyWRzlZfKpA7v4JHbIXRIaQc9ZjbTLBZdKWFHKjoqAa2qPqdskZyRdwHwgL__Nd7MuTLJ3tKYC4dW3IMk';

      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        redirectUrl,
        title: 'Risks of Human Spaceflight - NASA',
        domain: 'nasa.gov',
        publisher: 'NASA',
      );

      expect(sanitized, isNotNull);
      expect(sanitized!.startsWith('https://www.google.com/search?q='), isTrue);
      expect(sanitized.contains('Risks'), isTrue);
      expect(sanitized.contains('Spaceflight'), isTrue);
      expect(sanitized.contains('NASA'), isTrue);
      // Ensures the 404-prone redirect URL is NEVER preserved
      expect(sanitized.contains('grounding-api-redirect'), isFalse);
    });

    test('Normalizes missing scheme and strips trailing punctuation', () {
      const messyUrl = 'nasa.gov/news/article.html).';
      final cleaned = SourceUrlSanitizer.sanitizeUrl(messyUrl);
      expect(cleaned, equals('https://nasa.gov/news/article.html'));

      const quotedUrl = '"https://en.wikipedia.org/wiki/Apollo_11"';
      final unquoted = SourceUrlSanitizer.sanitizeUrl(quotedUrl);
      expect(unquoted, equals('https://en.wikipedia.org/wiki/Apollo_11'));
    });

    test('Generates search URL when raw URL is empty but title is present', () {
      final sanitized = SourceUrlSanitizer.sanitizeUrl(
        '',
        title: 'CDC Vaccine Safety Statistics',
        publisher: 'CDC',
      );
      expect(sanitized, isNotNull);
      expect(sanitized!.startsWith('https://www.google.com/search?q='), isTrue);
      expect(sanitized.contains('CDC'), isTrue);
    });

    test('Returns null when both URL and title are missing or empty', () {
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

    test('Sanitizes full source map seamlessly', () {
      final sourceMap = {
        'title': 'Apollo 11 Mission Overview - NASA',
        'url':
            'https://vertexaisearch.cloud.google.com/grounding-api-redirect/token12345',
        'domain': 'vertexaisearch.cloud.google.com',
        'publisher': 'NASA',
      };

      final sanitized = SourceUrlSanitizer.sanitizeSourceMap(sourceMap);

      expect(sanitized['url'].toString().startsWith('https://www.google.com/search?q='), isTrue);
      expect(sanitized['url'].toString().contains('grounding-api-redirect'), isFalse);
      expect(sanitized['directUrl'].toString().startsWith('https://www.google.com/search?q='), isTrue);
      expect(sanitized['domain'], equals('NASA'));
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
  });
}
