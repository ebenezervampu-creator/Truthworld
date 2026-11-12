import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  final unmonetizedChannel = Channel(
    id: 'ch_unmonetized_1',
    name: 'Truth Creator',
    nameLowercase: 'truth creator',
    handle: '@truthcreator',
    handleLowercase: '@truthcreator',
    description: 'Channel seeking monetization',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_unmon',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final reviewChannel = Channel(
    id: 'ch_review_1',
    name: 'Truth Creator In Review',
    nameLowercase: 'truth creator in review',
    handle: '@truthreview',
    handleLowercase: '@truthreview',
    description: 'Channel pending admin approval',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_review',
    status: ChannelStatus.underReview,
    monetizationStatus: 'underReview',
    monetizationApplication: {
      'status': 'pending',
      'qualifiedVideoTitle': 'Verified Deep Dive',
      'applicantName': 'Alice Truth',
      'bankName': 'HDFC Bank',
      'accountNumberMasked': '•••• 1234',
    },
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final monetizedChannel = Channel(
    id: 'ch_monetized_1',
    name: 'Truth Partner',
    nameLowercase: 'truth partner',
    handle: '@truthpartner',
    handleLowercase: '@truthpartner',
    description: 'Channel with active monetization',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_partner',
    isMonetized: true,
    monetizationTier: MonetizationTier.eligible,
    monetizationStatus: 'approved',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final qualifiedVideo = Video(
    id: 'vid_qual_1',
    channelId: 'ch_unmonetized_1',
    channelName: 'Truth Creator',
    ownerId: 'owner_unmon',
    category: 'News',
    tags: const ['news', 'factcheck'],
    title: 'Top Verified Investigative Report',
    description: 'Deep investigative report',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: '',
    duration: 1800,
    viewCount: 2500, // >= 1000 views
    totalWatchTimeSeconds: 43200, // 12 hours >= 10h (36,000s)
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final underThresholdVideo = Video(
    id: 'vid_under_1',
    channelId: 'ch_unmonetized_1',
    channelName: 'Truth Creator',
    ownerId: 'owner_unmon',
    category: 'News',
    tags: const ['news'],
    title: 'Preliminary Report',
    description: 'Short report',
    videoUrl: 'https://example.com/video2.mp4',
    thumbnailUrl: '',
    duration: 600,
    viewCount: 650, // < 1000 views
    totalWatchTimeSeconds: 18000, // 5 hours < 10h
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createTestWidget(Widget child) {
    return GetMaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('Monetization Gate & Header Join Action', () {
    testWidgets('renders Join button when channel is not monetized and not under review', (tester) async {
      var joinTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          MonetizationHeaderSection(
            channel: unmonetizedChannel,
            isMonetized: false,
            onJoinTap: () => joinTapped = true,
          ),
        ),
      );

      expect(find.text('Truth Creator'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
      expect(find.byKey(const Key('join_monetization_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('join_monetization_button')));
      expect(joinTapped, isTrue);
    });

    testWidgets('renders UNDER REVIEW badge when application is pending admin approval', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          MonetizationHeaderSection(
            channel: reviewChannel,
            isMonetized: false,
          ),
        ),
      );

      expect(find.text('UNDER REVIEW'), findsOneWidget);
    });

    testWidgets('renders ACTIVE badge when channel monetization is active', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          MonetizationHeaderSection(
            channel: monetizedChannel,
            isMonetized: true,
          ),
        ),
      );

      expect(find.text('ACTIVE'), findsOneWidget);
    });
  });

  group('MonetizationRequirementModal', () {
    testWidgets('displays 1k views & 10h gate criteria and highest video progress', (tester) async {
      final controller = Get.put(DashboardController(channelId: 'ch_unmonetized_1', autoInitialize: false));
      controller.currentChannel.value = unmonetizedChannel;
      controller.recentVideos.assignAll([underThresholdVideo]);

      await tester.pumpWidget(
        createTestWidget(
          MonetizationRequirementModal(controller: controller),
        ),
      );

      expect(find.text('Monetization Program Gate'), findsOneWidget);
      expect(find.text('1,000 Views & 30 Hours Watch Time Required'), findsOneWidget);
      expect(find.textContaining('Preliminary Report'), findsOneWidget);
      expect(find.textContaining('650 / 1,000 views'), findsOneWidget);
      expect(find.textContaining('5.0 / 30.0 hrs'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);
      expect(find.text('View All Videos'), findsOneWidget);
    });
  });

  group('MonetizationJoinHeroCard & ApplicationUnderReviewCard', () {
    testWidgets('MonetizationJoinHeroCard displays program perks and Join Now button', (tester) async {
      var joinPressed = false;
      final controller = Get.put(DashboardController(channelId: 'ch_unmonetized_1', autoInitialize: false));

      await tester.pumpWidget(
        createTestWidget(
          MonetizationJoinHeroCard(
            channel: unmonetizedChannel,
            controller: controller,
            onJoinPressed: () => joinPressed = true,
          ),
        ),
      );

      expect(find.text('TruthWorld Partner Program'), findsOneWidget);
      expect(find.textContaining('1k Views & 10 Hours Gate'), findsOneWidget);
      expect(find.textContaining('Zero Subscriber Barrier'), findsOneWidget);
      expect(find.text('Join Monetization Program'), findsOneWidget);

      await tester.tap(find.text('Join Monetization Program'));
      expect(joinPressed, isTrue);
    });

    testWidgets('MonetizationApplicationUnderReviewCard renders submission summary', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          MonetizationApplicationUnderReviewCard(channel: reviewChannel),
        ),
      );

      expect(find.text('Application Under Review'), findsOneWidget);
      expect(find.text('UNDER REVIEW'), findsOneWidget);
      expect(find.textContaining('Verified Deep Dive'), findsOneWidget);
      expect(find.textContaining('Alice Truth'), findsOneWidget);
      expect(find.textContaining('HDFC Bank •••• 1234'), findsOneWidget);
    });
  });

  group('MonetizationApplicationPage', () {
    testWidgets('renders qualification milestone banner, KYC form, and bank account form', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        GetMaterialApp(
          home: MonetizationApplicationPage(
            channel: unmonetizedChannel,
            qualifiedVideo: qualifiedVideo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monetization Application'), findsOneWidget);
      expect(find.text('THRESHOLD MET'), findsOneWidget);
      expect(find.text('Top Verified Investigative Report'), findsOneWidget);
      expect(find.text('2500 views'), findsOneWidget);
      expect(find.text('Creator Identity & Verification (KYC)'), findsOneWidget);
      expect(find.text('Direct Payout Bank Account'), findsOneWidget);
      expect(find.text('Submit Application for Admin Review'), findsOneWidget);
    });
  });

  group('MonetizationScreen Tab Separation & Premature Bank / KYC Prevention', () {
    testWidgets('does NOT ask bank account details and KYC when channel is not monetized', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(DashboardController(channelId: 'ch_unmonetized_1', autoInitialize: false));
      controller.currentChannel.value = unmonetizedChannel;
      controller.recentVideos.assignAll([underThresholdVideo]);

      final revController = RevenueAnalyticsController.to;
      revController.selectedEarningsTab.value = 0;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MonetizationScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Hero card with Join button should be visible
      expect(find.text('Join Monetization Program'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);

      // Premature bank and KYC form headers MUST NOT be present on this unmonetized screen!
      expect(find.text('Direct Bank Account Arrangement'), findsNothing);
      expect(find.text('Creator Identity Verification (KYC)'), findsNothing);
    });

    testWidgets('displays under review card instead of premature form when application is pending', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(DashboardController(channelId: 'ch_review_1', autoInitialize: false));
      controller.currentChannel.value = reviewChannel;

      final revController = RevenueAnalyticsController.to;
      revController.selectedEarningsTab.value = 0;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MonetizationScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Under review card should be present
      expect(find.text('Application Under Review'), findsWidgets);
      expect(find.text('UNDER REVIEW'), findsWidgets);

      // Premature bank and KYC form headers MUST NOT be present
      expect(find.text('Direct Bank Account Arrangement'), findsNothing);
      expect(find.text('Creator Identity Verification (KYC)'), findsNothing);
    });

    testWidgets('displays bank account card and KYC status card only after channel is monetized', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(DashboardController(channelId: 'ch_monetized_1', autoInitialize: false));
      controller.currentChannel.value = monetizedChannel;

      final revController = RevenueAnalyticsController.to;
      revController.selectedEarningsTab.value = 0;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MonetizationScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Header shows ACTIVE
      expect(find.text('ACTIVE'), findsOneWidget);

      // Monetized channel sees bank account and KYC management cards
      expect(find.text('Direct Bank Account Arrangement'), findsOneWidget);
      expect(find.text('Creator Identity Verification (KYC)'), findsOneWidget);
    });
  });
}
