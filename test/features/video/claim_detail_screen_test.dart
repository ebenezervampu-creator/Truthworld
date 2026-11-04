import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/claim_detail_screen.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/claim_sources_bottom_sheet.dart';

import '../../test_helpers/mock_firebase.dart';

class FakeConnectivityService extends GetxService implements ConnectivityService {
  @override
  ConnectivityResult get connectionStatus => ConnectivityResult.wifi;
  @override
  bool get isConnected => true;
  @override
  bool get isWifi => true;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  Stream<ConnectivityResult> get onConnectivityRestored => const Stream.empty();
  @override
  Future<ConnectivityService> init() async => this;
}

class _MockAuthService extends GetxService implements AuthService {
  @override
  String get uid => 'user_test_123';
  @override
  Channel? get userChannel => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<AuthService>(_MockAuthService());
    Get.put<ConnectivityService>(FakeConnectivityService());
  });

  tearDown(Get.reset);

  final testVideo = Video(
    id: 'test_claim_vid_1',
    ownerId: 'owner_truth_1',
    channelId: 'channel_truth_1',
    channelName: 'Health & Science Desk',
    title: 'The Truth About Daily Egg Consumption Guidelines',
    description: 'Empirical fact check of dietary egg recommendations.',
    videoUrl: 'https://example.com/egg_video.mp4',
    thumbnailUrl: 'https://example.com/egg_thumb.jpg',
    duration: 320,
    viewCount: 1250,
    tags: const ['health', 'diet'],
    category: 'Health',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    isFactChecked: true,
  );

  final testClaim = <String, dynamic>{
    'claim': 'The Indian Council of Medical Research recommends 180 eggs annually.',
    'status': 'disputed',
    'verdict': 'disputed',
    'startMs': 311000, // 05:11
    'response':
        'ICMR has at times referenced 180 eggs annually in national per capita targets, but it is not a current explicit medical limit.',
    'sources': [
      {
        'title': 'Dietary Guidelines for Indians, 2020',
        'publisher': 'Ministry of Health and Family Welfare',
        'domain': 'mohfw.gov.in',
        'url': 'https://mohfw.gov.in/guidelines/2020',
        'publishedAt': 'January 01, 2023',
      },
      {
        'title': 'Nutrient Requirements and Recommended Dietary Allowances for Indians',
        'publisher': 'ICMR',
        'domain': 'icmr.gov.in',
        'url': 'https://icmr.gov.in/nutrient-requirements',
        'publishedAt': 'January 01, 2020',
      },
      {
        'title': 'Eggs: A nutritious food',
        'publisher': 'Food and Agriculture Organization',
        'domain': 'fao.org',
        'url': 'https://fao.org/nutrition/eggs',
        'publishedAt': 'June 24, 2021',
      },
      {
        'title': 'ICMR recommends 180 eggs, people eat just...',
        'publisher': 'DNA India',
        'domain': 'dnaindia.com',
        'url': 'https://dnaindia.com/health/180-eggs',
        'publishedAt': 'August 12, 2018',
      },
      {
        'title': 'Are eggs good for you? Benefits, nutrition, ...',
        'publisher': 'BBC',
        'domain': 'bbc.com',
        'url': 'https://bbc.com/future/article/are-eggs-good-for-you',
        'publishedAt': 'March 15, 2022',
      },
    ],
  };

  group('SourceAvatarService Unit Tests', () {
    test('cleans raw domain and URLs accurately', () {
      expect(SourceAvatarService.cleanDomain('https://www.mohfw.gov.in/page'), equals('mohfw.gov.in'));
      expect(SourceAvatarService.cleanDomain('icmr.gov.in'), equals('icmr.gov.in'));
      expect(SourceAvatarService.cleanDomain('http://fao.org/data'), equals('fao.org'));
    });

    test('resolves authoritative institutional emblems for primary health bodies', () {
      final mohfw = SourceAvatarService.resolveAvatarUrl(domain: 'mohfw.gov.in');
      expect(mohfw, contains('Emblem_of_India'));

      final icmr = SourceAvatarService.resolveAvatarUrl(domain: 'icmr.gov.in');
      expect(icmr, contains('Indian_Council_of_Medical_Research_Logo'));

      final fao = SourceAvatarService.resolveAvatarUrl(domain: 'fao.org');
      expect(fao, contains('FAO_logo'));

      final bbc = SourceAvatarService.resolveAvatarUrl(domain: 'bbc.com');
      expect(bbc, contains('BBC'));
    });

    test('falls back to Google high-res 128px favicon service for unknown domains', () {
      final unknown = SourceAvatarService.resolveAvatarUrl(domain: 'example-journal.org');
      expect(unknown, equals('https://www.google.com/s2/favicons?domain=example-journal.org&sz=128'));
    });
  });

  group('ClaimDetailScreen Widget Tests', () {
    testWidgets('renders claim index, verdict pill, timestamp pill, and statement', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        GetMaterialApp(
          home: ClaimDetailScreen(
            claim: testClaim,
            video: testVideo,
            allSources: testClaim['sources'] as List<dynamic>,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Top Claim statement
      expect(find.text('The Indian Council of Medical Research recommends 180 eggs annually.'), findsOneWidget);

      // Claim #1 header & index badge
      expect(find.text('Claim #1'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // Verdict pill "DISPUTED"
      expect(find.text('DISPUTED'), findsOneWidget);

      // Timestamp pill "05:11"
      expect(find.text('05:11'), findsOneWidget);

      // Truth Intelligence Breakdown Card
      expect(find.text('Truth Intelligence Breakdown'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);

      // Sources Card
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('View all 5 sources'), findsOneWidget);

      // Top 3 Sources Titles rendered
      expect(find.text('Dietary Guidelines for Indians, 2020'), findsOneWidget);
      expect(find.text('Nutrient Requirements and Recommended Dietary Allowances for Indians'), findsOneWidget);
      expect(find.text('Eggs: A nutritious food'), findsOneWidget);

      // Fixed bottom action bar
      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('Search web'), findsOneWidget);
      expect(find.text('Provide source'), findsOneWidget);
    });

    testWidgets('tapping "View all X sources" opens ClaimSourcesBottomSheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        GetMaterialApp(
          home: ClaimDetailScreen(
            claim: testClaim,
            video: testVideo,
            allSources: testClaim['sources'] as List<dynamic>,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final viewAllBtn = find.text('View all 5 sources');
      expect(viewAllBtn, findsOneWidget);

      await tester.tap(viewAllBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Sources Bottom Sheet is now visible
      expect(find.byType(ClaimSourcesBottomSheet), findsOneWidget);

      // Check top sources are present in sheet
      expect(find.text('Ministry of Health and Family Welfare'), findsOneWidget);
      expect(find.text('ICMR'), findsOneWidget);
      expect(find.text('Food and Agriculture Organization'), findsOneWidget);

      // Scroll to remaining sources in the list
      await tester.scrollUntilVisible(
        find.text('DNA India'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('DNA India'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('BBC'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('BBC'), findsOneWidget);

      // Check bottom action buttons inside sheet
      expect(find.text('Search web'), findsWidgets);
      expect(find.text('Provide source'), findsWidgets);
    });

    testWidgets('renders desktop two-column widescreen layout on desktop (width >= 1024)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 850));

      await tester.pumpWidget(
        GetMaterialApp(
          home: ClaimDetailScreen(
            claim: testClaim,
            video: testVideo,
            allSources: testClaim['sources'] as List<dynamic>,
            allClaims: [testClaim, testClaim],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Statement
      expect(find.text('The Indian Council of Medical Research recommends 180 eggs annually.'), findsOneWidget);

      // Claim #1 header & index badge
      expect(find.text('Claim #1'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // Verdict pill "DISPUTED"
      expect(find.text('DISPUTED'), findsOneWidget);

      // Timestamp pill "05:11"
      expect(find.text('05:11'), findsOneWidget);

      // Truth Intelligence Breakdown Card
      expect(find.text('Truth Intelligence Breakdown'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);

      // Desktop Sources Sidebar Panel (Sources rendered directly in sidebar, not via modal)
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('5'), findsWidgets);
      expect(find.text('Showing all 5 sources'), findsOneWidget);

      // Sources directly visible on screen
      expect(find.text('Dietary Guidelines for Indians, 2020'), findsOneWidget);
      expect(find.text('Nutrient Requirements and Recommended Dietary Allowances for Indians'), findsOneWidget);

      // Action buttons on desktop
      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('Search web'), findsOneWidget);
      expect(find.text('Provide source'), findsOneWidget);

      // Claim navigation buttons ("1 of 2")
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Bottom sheet is NOT open on desktop
      expect(find.byType(ClaimSourcesBottomSheet), findsNothing);
    });

    testWidgets('renders bottom action bar on narrow screen (360px) without RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        GetMaterialApp(
          home: ClaimDetailScreen(
            claim: testClaim,
            video: testVideo,
            allSources: testClaim['sources'] as List<dynamic>,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('Search web'), findsOneWidget);
      expect(find.text('Provide source'), findsOneWidget);
    });

    testWidgets('renders bottom action bar on ultra-compact screen (320px) without RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(
        GetMaterialApp(
          home: ClaimDetailScreen(
            claim: testClaim,
            video: testVideo,
            allSources: testClaim['sources'] as List<dynamic>,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('Search web'), findsOneWidget);
      expect(find.text('Provide source'), findsOneWidget);
    });
  });
}
