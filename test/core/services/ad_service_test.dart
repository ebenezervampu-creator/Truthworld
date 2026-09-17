import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ad/dialogs/report_ad_dialog.dart';
import 'package:truthworld/core/services/ad/models/ad_comment.dart';
import 'package:truthworld/core/services/ad/models/ad_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdComment Model Tests', () {
    test('AdComment creates properly and serializes to/from map', () {
      final now = DateTime.now();
      final comment = AdComment(
        id: 'c1',
        adId: 'ad1',
        userId: 'u1',
        userName: 'John Doe',
        userProfilePicUrl: 'https://example.com/avatar.png',
        text: 'Great product!',
        createdAt: now,
      );

      expect(comment.id, 'c1');
      expect(comment.adId, 'ad1');
      expect(comment.userName, 'John Doe');
      expect(comment.userProfilePicUrl, 'https://example.com/avatar.png');
      expect(comment.text, 'Great product!');

      final map = comment.toMap();
      expect(map['adId'], 'ad1');
      expect(map['userName'], 'John Doe');
      expect(map['text'], 'Great product!');

      final fromMap = AdComment.fromMap({
        'adId': 'ad1',
        'userId': 'u1',
        'userName': 'John Doe',
        'userProfilePicUrl': 'https://example.com/avatar.png',
        'text': 'Great product!',
        'createdAt': now.toIso8601String(),
      }, 'c1');

      expect(fromMap.id, 'c1');
      expect(fromMap.userName, 'John Doe');
      expect(fromMap.text, 'Great product!');
    });
  });

  group('AdItem Model Enhancements Tests', () {
    test('AdItem copyWith works seamlessly', () {
      const ad = AdItem(
        id: 'ad_100',
        userId: 'u_100',
        title: 'Tech Expo',
        description: 'Join the annual conference',
        advertiser: 'TechCorp',
        imageUrl: 'https://example.com/banner.jpg',
        ctaText: 'Register',
        ctaTarget: 'https://techcorp.com/register',
        gradientColors: [Colors.black, Colors.blueGrey],
        impressions: 10,
        clicks: 2,
      );

      final updated = ad.copyWith(
        impressions: 15,
        clicks: 5,
        status: 'paused',
      );

      expect(updated.id, 'ad_100');
      expect(updated.impressions, 15);
      expect(updated.clicks, 5);
      expect(updated.status, 'paused');
      expect(updated.title, 'Tech Expo');
    });
  });

  group('ReportAdDialog Modal Widget Tests', () {
    testWidgets('shows report options and cancels cleanly', (tester) async {
      const ad = AdItem(
        id: 'ad_test',
        userId: 'user_test',
        title: 'Test Ad',
        description: 'Test Description',
        advertiser: 'Test Advertiser',
        imageUrl: 'https://example.com/ad.png',
        ctaText: 'Click',
        ctaTarget: 'https://example.com',
        gradientColors: [Colors.black, Colors.white],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showReportAdDialogModal(
                    context: context,
                    ad: ad,
                    onReportAd: ({required ad, required reason, details = ''}) async {},
                  );
                },
                child: const Text('Open Report Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Report Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Report Advertisement'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Report Advertisement'), findsNothing);
    });
  });
}
