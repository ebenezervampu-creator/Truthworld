import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';

AdItem createTestAd({
  required String id,
  required String title,
  required String advertiser,
  String description = 'Quality tech and services',
  String ctaText = 'Learn More',
  String ctaTarget = 'https://example.com',
  String imageUrl = '',
  String? pinnedCommentText,
}) {
  return AdItem(
    id: id,
    userId: 'user_test_1',
    title: title,
    description: description,
    advertiser: advertiser,
    imageUrl: imageUrl,
    ctaText: ctaText,
    ctaTarget: ctaTarget,
    gradientColors: const [Color(0xFF1E1E1E), Color(0xFF272727)],
    pinnedCommentText: pinnedCommentText,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  group('AdCardController Tests', () {
    test('Hover state updates and notifies listeners', () {
      final controller = AdCardController();
      expect(controller.isHovered, isFalse);

      var updateCount = 0;
      controller.addListener(() => updateCount++);

      controller.setHovered(true);
      expect(controller.isHovered, isTrue);
      expect(updateCount, equals(1));

      // Redundant setHovered shouldn't trigger extra update
      controller.setHovered(true);
      expect(updateCount, equals(1));

      controller.setHovered(false);
      expect(controller.isHovered, isFalse);
      expect(updateCount, equals(2));
    });
  });

  group('Advertiser Avatar & Action Helper Tests', () {
    testWidgets('buildAdvertiserLogoAvatar renders fallback initial when logo empty', (tester) async {
      final ad = createTestAd(
        id: 'ad_101',
        title: 'Super Product',
        advertiser: 'Acme Corp',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildAdvertiserLogoAvatar(ad, radius: 20),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('AdOptionsMenuButton renders more_vert icon with white color', (tester) async {
      final ad = createTestAd(
        id: 'ad_102',
        title: 'Super Product 2',
        advertiser: 'Globex',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdOptionsMenuButton(ad: ad),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.more_vert_rounded);
      expect(iconFinder, findsOneWidget);

      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, equals(Colors.white));
    });
  });

  group('PinnedSponsorCommentCard Tests', () {
    testWidgets('Renders pinned sponsor header, advertiser, and comment copy', (tester) async {
      final ad = createTestAd(
        id: 'ad_103',
        title: 'TruthWorld Premium',
        advertiser: 'TruthWorld Sponsor',
        ctaText: 'Subscribe',
        pinnedCommentText: 'Thanks for tuning in! Exclusive 20% discount below.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinnedSponsorCommentCard(
              ad: ad,
              videoId: 'vid_123',
              isInModal: true,
            ),
          ),
        ),
      );

      expect(find.text('Pinned Sponsor'), findsOneWidget);
      expect(find.text('TruthWorld Sponsor'), findsOneWidget);
      expect(find.text('SPONSOR'), findsOneWidget);
      expect(find.text('Thanks for tuning in! Exclusive 20% discount below.'), findsOneWidget);
      expect(find.text('Subscribe →'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });
  });
}
