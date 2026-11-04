import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/deep_link/deep_link_url_parser.dart';
import 'package:truthworld/core/services/deep_link/parsed_truthworld_url.dart';

void main() {
  group('Surface 7 Platform Security & Deep Link Verification', () {
    test('sanitizes custom schemes truthworld:// into authoritative domain', () {
      final parsed = DeepLinkUrlParser.parseUrl('truthworld://watch?v=video_xyz123');
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('video_xyz123'));
    });

    test('sanitizes studio custom schemes truthworldstudio:// into studio route', () {
      final parsed = DeepLinkUrlParser.parseUrl('truthworldstudio://analytics');
      expect(parsed.type, equals(TruthworldUrlType.studio));
    });

    test('flags arbitrary external domains as TruthworldUrlType.external', () {
      final parsed = DeepLinkUrlParser.parseUrl('https://evil-phishing-site.com/watch?v=fake');
      expect(parsed.type, equals(TruthworldUrlType.external));
    });

    test('prevents reserved routes from being treated as creator channel handles', () {
      expect(DeepLinkUrlParser.reservedRoutes.contains('studio'), isTrue);
      expect(DeepLinkUrlParser.reservedRoutes.contains('admin'), isTrue);
      expect(DeepLinkUrlParser.reservedRoutes.contains('checkout'), isTrue);
      expect(DeepLinkUrlParser.reservedRoutes.contains('payment-result'), isTrue);
      expect(DeepLinkUrlParser.reservedRoutes.contains('settings'), isTrue);
    });
  });
}
