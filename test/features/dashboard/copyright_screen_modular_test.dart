import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);

  tearDown(Get.reset);

  group('CopyrightFormatters Unit Tests', () {
    test('formats Timestamp into MMM d, yyyy', () {
      final ts = Timestamp.fromDate(DateTime(2026, 4, 15));
      final formatted = CopyrightFormatters.formatDate(ts);
      expect(formatted, 'Apr 15, 2026');
    });

    test('formats DateTime into MMM d, yyyy', () {
      final dt = DateTime(2025, 12, 31);
      final formatted = CopyrightFormatters.formatDate(dt);
      expect(formatted, 'Dec 31, 2025');
    });

    test('returns Unknown Date for invalid or null object', () {
      expect(CopyrightFormatters.formatDate(null), 'Unknown Date');
      expect(CopyrightFormatters.formatDate('2026-01-01'), 'Unknown Date');
    });
  });

  group('CopyrightController Unit Tests', () {
    test('initializes with channel ID and creates tabController', () {
      final controller = CopyrightController(initialChannelId: 'channel_123');
      controller.onInit();

      expect(controller.channelId.value, 'channel_123');
      expect(controller.activeChannelId, 'channel_123');
      expect(controller.tabController.length, 2);

      controller.setChannelContext('channel_456');
      expect(controller.activeChannelId, 'channel_456');

      controller.onClose();
    });

    test('retry increments retryTrigger observable', () {
      final controller = CopyrightController();
      controller.onInit();

      expect(controller.retryTrigger.value, 0);
      controller.retry();
      expect(controller.retryTrigger.value, 1);

      controller.onClose();
    });

    test('returns empty stream when channel ID is empty', () async {
      final controller = CopyrightController();
      controller.onInit();

      final noticesStream = controller.noticesStream('');
      expect(await noticesStream.isEmpty, isTrue);

      final matchesStream = controller.matchedReuploadsStream('');
      expect(await matchesStream.isEmpty, isTrue);

      controller.onClose();
    });
  });

  group('Copyright UI Components Tests', () {
    testWidgets('ClaimsSummaryCard renders 0 claims correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClaimsSummaryCard(totalClaims: 0, isDarkMode: true),
          ),
        ),
      );

      expect(find.text('No copyright strikes'), findsOneWidget);
      expect(find.text('Your channel is in good standing.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('ClaimsSummaryCard renders active claims correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClaimsSummaryCard(totalClaims: 3, isDarkMode: false),
          ),
        ),
      );

      expect(find.text('3 Copyright claims'), findsOneWidget);
      expect(
        find.text('Review details to see how these affect your channel.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.copyright), findsOneWidget);
    });

    testWidgets('ClaimCard renders claim details correctly', (tester) async {
      final claimData = {
        'videoTitle': 'Sample Scientific Analysis',
        'noticeType': 'Audio Copyright Match',
        'claimant': 'Global Media Music',
        'impact': 'Monetized by claimant',
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 2)),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClaimCard(data: claimData, isDarkMode: true),
          ),
        ),
      );

      expect(find.text('Sample Scientific Analysis'), findsOneWidget);
      expect(find.text('Audio Copyright Match'), findsOneWidget);
      expect(find.text('Global Media Music'), findsOneWidget);
      expect(find.text('Monetized by claimant'), findsOneWidget);
      expect(find.text('Jun 2, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('ClaimDetailsBottomSheet displays claim metadata', (tester) async {
      final claimData = {
        'videoTitle': 'Documentary Ep 1',
        'noticeType': 'Video Fingerprint Match',
        'claimant': 'Archive Films LLC',
        'policy': 'Blocked in some regions',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClaimDetailsBottomSheet(data: claimData, isDarkMode: true),
          ),
        ),
      );

      expect(find.text('Claim Details'), findsOneWidget);
      expect(find.text('Documentary Ep 1'), findsOneWidget);
      expect(find.text('Video Fingerprint Match'), findsOneWidget);
      expect(find.text('Archive Films LLC'), findsOneWidget);
      expect(find.text('Blocked in some regions'), findsOneWidget);
    });

    testWidgets('MatchToolHeader renders title and description', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MatchToolHeader(isDarkMode: true),
          ),
        ),
      );

      expect(find.text('Automated Content Match Engine'), findsOneWidget);
      expect(
        find.text(
          'Scans Truthworld for re-uploaded videos matching your original content. Take direct action to request removal or contact uploaders.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.screen_search_desktop_rounded), findsOneWidget);
    });

    testWidgets('MatchVideoCard renders video info and action buttons', (tester) async {
      final controller = CopyrightController(initialChannelId: 'ch_orig');
      controller.onInit();

      final matchData = {
        'title': 'Stolen Clip Re-upload',
        'channelName': 'Pirate Channel',
        'matchPercentage': 98,
        'viewCount': 1250,
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 5, 20)),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchVideoCard(
              docId: 'doc_1',
              data: matchData,
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('98% MATCH'), findsOneWidget);
      expect(find.text('Stolen Clip Re-upload'), findsOneWidget);
      expect(
        find.text('Re-uploaded on channel: Pirate Channel • 1250 views'),
        findsOneWidget,
      );
      expect(find.text('Uploaded: May 20, 2026'), findsOneWidget);
      expect(find.text('Contact Uploader'), findsOneWidget);
      expect(find.text('Request Video Removal'), findsOneWidget);

      controller.onClose();
    });

    testWidgets('CopyrightEmptyState renders properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CopyrightEmptyState(isDarkMode: true),
          ),
        ),
      );

      expect(find.text('Channel content is claim-free'), findsOneWidget);
      expect(
        find.text('Keep up the great work creating original content!'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('CopyrightErrorState renders with retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopyrightErrorState(
              onRetry: () => retried = true,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to load copyright data'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('MatchToolEmptyState renders properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MatchToolEmptyState(isDarkMode: true),
          ),
        ),
      );

      expect(find.text('No unauthorized re-uploads detected'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
    });

    testWidgets('CopyrightScreen renders AppBar with both tabs', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: CopyrightScreen(channelId: 'test_ch'),
        ),
      );

      expect(find.text('Copyright & Content Protection'), findsOneWidget);
      expect(find.text('Claims & Notices'), findsOneWidget);
      expect(
        find.text('Copyright Match Tool (Re-upload Finder)'),
        findsOneWidget,
      );
    });
  });
}
