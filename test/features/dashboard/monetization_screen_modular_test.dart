import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_components.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  final standardChannel = Channel(
    id: 'channel_std_1',
    name: 'Truth Standard',
    nameLowercase: 'truth standard',
    handle: '@standard',
    handleLowercase: '@standard',
    description: 'Standard channel description',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_1',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final customChannel = Channel(
    id: 'channel_cust_1',
    name: 'Truth Custom',
    nameLowercase: 'truth custom',
    handle: '@custom',
    handleLowercase: '@custom',
    description: 'Custom channel description',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_2',
    channelType: ChannelType.custom,
    pendingChannelType: ChannelType.standard,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final sampleVideo = Video(
    id: 'vid_101',
    channelId: 'channel_std_1',
    channelName: 'Truth Standard',
    ownerId: 'owner_1',
    category: 'News',
    tags: const ['news', 'report'],
    title: 'Investigative Report #1',
    description: 'First video report',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: '',
    duration: 1200,
    viewCount: 4500,
    totalWatchTimeSeconds: 43200, // 12 hours (eligible >= 10h)
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final samplePendingVideo = Video(
    id: 'vid_102',
    channelId: 'channel_std_1',
    channelName: 'Truth Standard',
    ownerId: 'owner_1',
    category: 'News',
    tags: const ['news', 'report'],
    title: 'Investigative Report #2',
    description: 'Second video report',
    videoUrl: 'https://example.com/video2.mp4',
    thumbnailUrl: '',
    duration: 600,
    viewCount: 800,
    totalWatchTimeSeconds: 14400, // 4 hours (< 10h)
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createTestWidget(Widget child) {
    return GetMaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('MonetizationCardContainer & Section Title', () {
    testWidgets('renders card container with child and custom padding', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const MonetizationCardContainer(
            child: Text('Card Content Inside'),
          ),
        ),
      );

      expect(find.text('Card Content Inside'), findsOneWidget);
    });

    testWidgets('renders section title with vertical accent indicator', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const MonetizationSectionTitle(
            title: 'Section Header Title',
            trailing: Icon(Icons.star, key: Key('trailing_icon')),
          ),
        ),
      );

      expect(find.text('Section Header Title'), findsOneWidget);
      expect(find.byKey(const Key('trailing_icon')), findsOneWidget);
    });
  });

  group('MonetizationHeaderSection & ChannelTypeBadge', () {
    testWidgets('renders standard channel badge and description', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          MonetizationHeaderSection(channel: standardChannel),
        ),
      );

      expect(find.text('Channel Monetization'), findsOneWidget);
      expect(find.text('STANDARD CHANNEL'), findsOneWidget);
      expect(find.text('Day 1 Creator Monetization Program'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('renders custom channel badge and description', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          MonetizationHeaderSection(channel: customChannel),
        ),
      );

      expect(find.text('Channel Monetization'), findsOneWidget);
      expect(find.text('CUSTOM CHANNEL'), findsOneWidget);
      expect(find.text('Custom Channel Infrastructure & Direct Earnings'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });
  });

  group('ChannelTypeCard & Detail Tiles', () {
    testWidgets('renders standard channel quotas and upgrade button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          ChannelTypeCard(channel: standardChannel),
        ),
      );

      expect(find.text('Channel Type & Infrastructure Tier'), findsOneWidget);
      expect(find.text('Upload Limit'), findsOneWidget);
      expect(find.text('10 Mins / Day'), findsWidgets);
      expect(find.text('1k Views & 10h Gate'), findsOneWidget);
      expect(find.text('Explore / Switch Channel Type'), findsOneWidget);
    });

    testWidgets('renders custom channel quotas, pending banner, and manage button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          ChannelTypeCard(channel: customChannel),
        ),
      );

      expect(find.text('Unlimited Videos'), findsOneWidget);
      expect(find.text('Up to 24 Hours'), findsOneWidget);
      expect(find.text('1k Views & 10h Gate'), findsOneWidget);
      expect(find.text('Manage Custom Infra & Tier Settings'), findsOneWidget);
      expect(find.textContaining('Scheduled to switch to STANDARD CHANNEL'), findsOneWidget);
    });
  });

  group('PolicyNoticeCard & PartnerEligibilitySection', () {
    testWidgets('renders standard policy notice card with 10h cash out rule', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const PolicyNoticeCard(isCustom: false),
        ),
      );

      expect(find.text('Instant Revenue from Day 1'), findsOneWidget);
      expect(find.textContaining('10 hours of watch time'), findsOneWidget);
    });

    testWidgets('renders custom policy notice card with instant cash payout', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const PolicyNoticeCard(isCustom: true),
        ),
      );

      expect(find.text('Instant Revenue from Day 1'), findsOneWidget);
    });

    testWidgets('renders partner eligibility status tiles', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const PartnerEligibilitySection(isCustom: false),
        ),
      );

      expect(find.text('Partner Eligibility Status'), findsOneWidget);
      expect(find.text('Subscriber Gate'), findsOneWidget);
      expect(find.text('0 Required'), findsOneWidget);
      expect(find.text('Cash Out Gate'), findsOneWidget);
      expect(find.text('1k Views & 10h'), findsOneWidget);
      expect(find.text('AI Features'), findsOneWidget);
      expect(find.text('Instant Use'), findsOneWidget);
    });
  });

  group('RevenueMetricRow & AiFeatureOptionTile', () {
    testWidgets('renders revenue metric row with formatted values', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const RevenueMetricRow(
            period: 'Total Estimated Revenue',
            amount: '₹1,500.00',
            isHighlight: true,
            subtitle: 'Verified Day 1 Earnings',
            badgeColor: Colors.green,
          ),
        ),
      );

      expect(find.text('Total Estimated Revenue'), findsOneWidget);
      expect(find.text('₹1,500.00'), findsOneWidget);
      expect(find.text('Verified Day 1 Earnings'), findsOneWidget);
    });

    testWidgets('AiFeatureOptionTile renders details and responds to taps', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestWidget(
          AiFeatureOptionTile(
            icon: Icons.fact_check_rounded,
            title: 'Fact-Checking',
            description: 'AI claim verification',
            costText: r'$2.00 • Instant from balance',
            onSelect: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Fact-Checking'), findsOneWidget);
      expect(find.text('AI claim verification'), findsOneWidget);
      expect(find.text(r'$2.00 • Instant from balance'), findsOneWidget);

      await tester.tap(find.text('Fact-Checking'));
      expect(tapped, isTrue);
    });
  });

  group('PerVideoWithdrawalSection & VideoWithdrawalRow', () {
    testWidgets('displays empty state when controller has no videos', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(DashboardController(channelId: 'empty_channel'));
      controller.recentVideos.clear();

      await tester.pumpWidget(
        createTestWidget(
          PerVideoWithdrawalSection(controller: controller),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Video Cash-Out Eligibility (1,000 Views & 10 Hours)'), findsOneWidget);
      expect(find.textContaining('No uploaded videos found yet'), findsOneWidget);
    });

    testWidgets('displays video withdrawal progress and cash-out readiness', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(DashboardController(channelId: 'channel_with_videos'));
      controller.recentVideos.assignAll([sampleVideo, samplePendingVideo]);

      await tester.pumpWidget(
        createTestWidget(
          PerVideoWithdrawalSection(controller: controller),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Investigative Report #1'), findsOneWidget);
      expect(find.text('Cash-Out Ready'), findsOneWidget);
      expect(find.text('Investigative Report #2'), findsOneWidget);
      expect(find.textContaining('Locked'), findsOneWidget);
      expect(find.text('Use for AI Tools'), findsNWidgets(2));
    });
  });

  group('RevenueWithdrawalSummaryCard', () {
    testWidgets('renders revenue breakdown and AI tools action button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(DashboardController(channelId: 'summary_channel'));
      controller.channelStats['revenue'] = '₹2,450.00';
      controller.rxTotalRevenue.value = 2450.0;
      controller.rxMembershipsRevenue.value = 450.0;
      controller.rxSuperchatRevenue.value = 200.0;
      controller.rxAdsRevenue.value = 1000.0;
      controller.rxWatchTimeRevenue.value = 800.0;
      controller.recentVideos.assignAll([sampleVideo]);

      await tester.pumpWidget(
        createTestWidget(
          RevenueWithdrawalSummaryCard(controller: controller),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Revenue & Withdrawal Summary'), findsOneWidget);
      expect(find.text('Total Estimated Revenue'), findsOneWidget);
      expect(find.text('Available for Cash Withdrawal'), findsOneWidget);
      expect(find.text('Locked for Cash Out (Awaiting 1k Views & 10h)'), findsOneWidget);
      expect(find.text('Usable Balance for AI Features'), findsOneWidget);
      expect(find.text('Use Balance for AI Subtitles & Dubbing'), findsOneWidget);
    });
  });

  group('ChannelWalletCard', () {
    testWidgets('renders channel wallet balance, breakdown, and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final walletChannel = Channel(
        id: 'ch_wallet_test',
        name: 'Wallet Channel',
        nameLowercase: 'wallet channel',
        handle: '@wallet_channel',
        handleLowercase: '@wallet_channel',
        description: 'Test channel with wallet',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_w',
        walletBalanceUSD: 35.0,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      final controller = Get.put(DashboardController(channelId: 'ch_wallet_test'));

      await tester.pumpWidget(
        createTestWidget(
          ChannelWalletCard(channel: walletChannel, controller: controller),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Channel Wallet'), findsOneWidget);
      expect(find.text('STANDARD WALLET'), findsOneWidget);
      expect(find.text('Total Spendable Balance'), findsOneWidget);
      expect(find.text('Deposited Funds'), findsOneWidget);
      expect(find.text('Add Money'), findsOneWidget);
      expect(find.text('Spend on Features'), findsOneWidget);
      expect(find.text('Recent Wallet Activity'), findsOneWidget);
    });
  });
}
