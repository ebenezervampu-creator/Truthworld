import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/channel_queue_tab.dart';

import '../../test_helpers/mock_firebase.dart';

class TestAdminController extends AdminController {
  @override
  // ignore: must_call_super
  void onInit() {
    // Avoid starting live Firestore network streams in unit/widget test environment
  }

  @override
  void ensureSubscriptionsStarted() {
    // Avoid starting live Firestore network streams in unit/widget test environment
  }

  @override
  Future<void> refreshAllData() async {}

  @override
  Future<void> fetchChannelEconomics(String channelId) async {
    if (!isSuperAdmin || channelId.isEmpty) {
      channelEconomics.value = null;
      return;
    }

    final channelMap = selectedChannel.value;
    if (channelMap != null) {
      final adsINR = (channelMap['adsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
      final premiumINR = (channelMap['premiumSubsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
      final membershipsINR = ((channelMap['membershipRevenueTotal'] ?? channelMap['membershipsRevenueTotal']) as num?)?.toDouble() ?? 0.0;
      final superchatsINR = (channelMap['superchatRevenueTotal'] as num?)?.toDouble() ?? 0.0;
      final grossINR = adsINR + premiumINR + membershipsINR + superchatsINR;
      final grossUSD = grossINR / 84.0;
      final isCustom = (channelMap['channelType'] ?? '').toString().toLowerCase() == 'custom' ||
          (channelMap['channelType'] ?? '').toString().toLowerCase() == 'pro';
      final infraConfig = channelMap['infraConfig'] is Map ? (channelMap['infraConfig'] as Map) : null;
      final flatFee = (infraConfig?['flatPlatformFee'] as num?)?.toDouble() ?? 15.0;
      final platformCutUSD = isCustom ? flatFee : (grossUSD * 0.30);
      final platformCutINR = isCustom ? (platformCutUSD * 84.0) : (grossINR * 0.30);
      final currentMonthInfra = (infraConfig?['currentMonthInfraCost'] as num?)?.toDouble() ?? 0.0;

      channelEconomics.value = {
        'channelId': channelId,
        'channelName': channelMap['name'] ?? channelMap['channelName'] ?? 'Truthworld Channel',
        'channelType': channelMap['channelType'] ?? 'standard',
        'revenue': {
          'grossINR': grossINR,
          'grossUSD': grossUSD,
          'creatorShareINR': isCustom ? grossINR : (grossINR * 0.70),
          'creatorShareUSD': isCustom ? grossUSD : (grossUSD * 0.70),
          'platformShareINR': platformCutINR,
          'platformShareUSD': platformCutUSD,
          'breakdown': {
            'adsINR': adsINR,
            'premiumINR': premiumINR,
            'membershipsINR': membershipsINR,
            'superchatsINR': superchatsINR,
          },
          'payouts': {
            'walletBalanceUSD': (channelMap['walletBalanceUSD'] as num?)?.toDouble() ?? 0.0,
            'clearedWithdrawableINR': (channelMap['clearedWithdrawableRevenueTotal'] as num?)?.toDouble() ?? 0.0,
            'pendingINR': (channelMap['pendingRevenueTotal'] as num?)?.toDouble() ?? 0.0,
            'withdrawnINR': (channelMap['withdrawnRevenueTotal'] as num?)?.toDouble() ?? 0.0,
          },
        },
        'spendings': {
          'totalInfraUSD': currentMonthInfra,
          'totalInfraINR': currentMonthInfra * 84.0,
          'currentMonthInfraCostUSD': currentMonthInfra,
          'breakdown': {
            'geminiAI': currentMonthInfra * 0.5,
            'cdnEgress': currentMonthInfra * 0.25,
            'transcription': currentMonthInfra * 0.1,
            'translationDubbing': currentMonthInfra * 0.1,
            'mediaTranscoding': 0.0,
            'compute': currentMonthInfra * 0.05,
            'firestoreOps': 0.0,
          },
          'creatorWalletSpendUSD': 0.0,
        },
        'economics': {
          'netPlatformContributionUSD': platformCutUSD - currentMonthInfra,
          'netPlatformContributionINR': platformCutINR - (currentMonthInfra * 84.0),
          'marginPercent': platformCutUSD > 0 ? (((platformCutUSD - currentMonthInfra) / platformCutUSD) * 100) : 0.0,
          'isProfitable': (platformCutUSD - currentMonthInfra) >= 0,
        },
        'transactions': [],
        'monthlyStatements': [],
      };
    }
    isLoadingChannelEconomics.value = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  late TestAdminController controller;

  setUp(() {
    Get.reset();
    controller = Get.put<AdminController>(TestAdminController()) as TestAdminController;
    controller.isAdmin.value = true;
    controller.currentAdminEmail.value = 'hello@truthworld.in';
    controller.currentAdminRole.value = 'Super Admin';
    controller.currentAdminRoles.assignAll(['Super Admin']);
  });

  tearDown(Get.reset);

  group('AdminRolesConfig.isSuperAdmin Permission Gates', () {
    test('Correctly grants Super Admin privileges to authorized roles and platform owners', () {
      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'admin@truthworld.in',
          currentAdminRole: 'Super Admin',
          currentAdminRoles: ['Super Admin'],
        ),
        isTrue,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'director@truthworld.in',
          currentAdminRole: 'Director',
          currentAdminRoles: ['Director'],
        ),
        isTrue,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'owner@truthworld.in',
          currentAdminRole: 'Owner',
          currentAdminRoles: ['Owner'],
        ),
        isTrue,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: true,
          currentAdminEmail: 'anyone@truthworld.in',
          currentAdminRole: 'Admin',
          currentAdminRoles: ['Admin'],
        ),
        isTrue,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'ebenezervampu4@gmail.com',
          currentAdminRole: 'Content Moderator',
          currentAdminRoles: ['Content Moderator'],
        ),
        isTrue,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'hello@truthworld.in',
          currentAdminRole: 'Content Moderator',
          currentAdminRoles: ['Content Moderator'],
        ),
        isTrue,
      );
    });

    test('Correctly rejects non-Super Admin roles and unauthorized emails', () {
      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'mod@truthworld.in',
          currentAdminRole: 'Content Moderator',
          currentAdminRoles: ['Content Moderator'],
        ),
        isFalse,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'reviewer@truthworld.in',
          currentAdminRole: 'Trust & Safety Reviewer',
          currentAdminRoles: ['Trust & Safety Reviewer'],
        ),
        isFalse,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'community@truthworld.in',
          currentAdminRole: 'Community Manager',
          currentAdminRoles: ['Community Manager'],
        ),
        isFalse,
      );

      expect(
        AdminRolesConfig.isSuperAdmin(
          isAdmin: false,
          isPrimaryOwner: false,
          currentAdminEmail: 'ebenezervampu4@gmail.com',
          currentAdminRole: 'Super Admin',
          currentAdminRoles: ['Super Admin'],
        ),
        isFalse,
      );
    });
  });

  group('AdminController Channel Unit Economics Logic', () {
    test('isSuperAdmin getter dynamically tracks controller.currentAdminRole', () {
      controller.isAdmin.value = true;
      controller.currentAdminEmail.value = 'staff@truthworld.in';

      controller.currentAdminRole.value = 'Super Admin';
      controller.currentAdminRoles.assignAll(['Super Admin']);
      expect(controller.isSuperAdmin, isTrue);

      controller.currentAdminRole.value = 'Director';
      controller.currentAdminRoles.assignAll(['Director']);
      expect(controller.isSuperAdmin, isTrue);

      controller.currentAdminRole.value = 'Content Moderator';
      controller.currentAdminRoles.assignAll(['Content Moderator']);
      expect(controller.isSuperAdmin, isFalse);

      controller.currentAdminRole.value = 'Trust & Safety Reviewer';
      controller.currentAdminRoles.assignAll(['Trust & Safety Reviewer']);
      expect(controller.isSuperAdmin, isFalse);
    });

    test('fetchChannelEconomics creates instant optimistic 70/30 snapshot for standard channels', () async {
      final channelData = {
        'id': 'ch_test_1',
        'name': 'Standard News Channel',
        'channelType': 'standard',
        'adsRevenueTotal': 8400.0, // 8400 INR = 100 USD
        'premiumSubsRevenueTotal': 4200.0, // 4200 INR = 50 USD
        'membershipRevenueTotal': 2100.0, // 2100 INR = 25 USD
        'superchatRevenueTotal': 2100.0, // 2100 INR = 25 USD
        'infraConfig': {
          'currentMonthInfraCost': 15.0,
        },
      };

      controller.selectedChannel.value = channelData;
      await controller.fetchChannelEconomics('ch_test_1');

      final econ = controller.channelEconomics.value;
      expect(econ, isNotNull);
      expect(econ!['channelId'], 'ch_test_1');
      expect(econ['channelType'], 'standard');

      final revenue = econ['revenue'] as Map<String, dynamic>;
      expect(revenue['grossINR'], 16800.0);
      expect(revenue['grossUSD'], 200.0);
      // Standard channel: 70% creator share, 30% platform cut
      expect(revenue['creatorShareINR'], 11760.0);
      expect(revenue['creatorShareUSD'], 140.0);
      expect(revenue['platformShareINR'], 5040.0);
      expect(revenue['platformShareUSD'], 60.0);

      final spendings = econ['spendings'] as Map<String, dynamic>;
      expect(spendings['totalInfraUSD'], 15.0);
      expect(spendings['totalInfraINR'], 1260.0); // 15 * 84

      final economics = econ['economics'] as Map<String, dynamic>;
      // Net Platform Contribution: 60 - 15 = 45 USD
      expect(economics['netPlatformContributionUSD'], 45.0);
      expect(economics['isProfitable'], isTrue);
    });

    test('fetchChannelEconomics creates flat SaaS fee snapshot for custom/pro channels', () async {
      final channelData = {
        'id': 'ch_pro_1',
        'name': 'Pro Investigative Lab',
        'channelType': 'pro',
        'adsRevenueTotal': 840.0, // 840 INR = 10 USD
        'premiumSubsRevenueTotal': 0.0,
        'infraConfig': {
          'flatPlatformFee': 25.0, // Truthworld SaaS platform fee = $25
          'currentMonthInfraCost': 30.0, // Infra cost = $30
        },
      };

      controller.selectedChannel.value = channelData;
      await controller.fetchChannelEconomics('ch_pro_1');

      final econ = controller.channelEconomics.value;
      expect(econ, isNotNull);
      expect(econ!['channelType'], 'pro');

      final revenue = econ['revenue'] as Map<String, dynamic>;
      // Pro channel: creator keeps 100% of revenue
      expect(revenue['creatorShareINR'], 840.0);
      expect(revenue['creatorShareUSD'], 10.0);
      // Platform share is flat SaaS fee ($25)
      expect(revenue['platformShareUSD'], 25.0);
      expect(revenue['platformShareINR'], 2100.0); // 25 * 84

      final spendings = econ['spendings'] as Map<String, dynamic>;
      expect(spendings['totalInfraUSD'], 30.0);

      final economics = econ['economics'] as Map<String, dynamic>;
      // Net platform contribution: 25 - 30 = -5 USD
      expect(economics['netPlatformContributionUSD'], -5.0);
      expect(economics['isProfitable'], isFalse);
    });

    test('clearSelectedItems resets channelEconomics observable to null', () {
      controller.channelEconomics.value = {'test': 'data'};
      expect(controller.channelEconomics.value, isNotNull);

      controller.clearSelectedItems();
      expect(controller.channelEconomics.value, isNull);
    });
  });

  group('ChannelQueueTab Widget Tests (Super Admin vs Other Roles)', () {
    final sampleChannel = {
      'id': 'ch_widget_test',
      'name': 'TruthWorld Widget Channel',
      'channelType': 'standard',
      'status': 'active',
      'moderationReason': 'Gateway check complete',
      'adsRevenueTotal': 16800.0,
      'premiumSubsRevenueTotal': 8400.0,
      'membershipRevenueTotal': 0.0,
      'superchatRevenueTotal': 0.0,
      'infraConfig': {
        'currentMonthInfraCost': 20.0,
      },
    };

    testWidgets('Renders Channel Financial & Unit Economics Card when user is Super Admin', (tester) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      controller.currentAdminEmail.value = 'hello@truthworld.in';
      controller.currentAdminRole.value = 'Super Admin';
      controller.currentAdminRoles.assignAll(['Super Admin']);
      controller.channels.assignAll([sampleChannel]);
      controller.selectedChannel.value = sampleChannel;
      await controller.fetchChannelEconomics('ch_widget_test');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ChannelQueueTab(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that Channel Financial Economics & Spendings card is visible
      expect(find.text('Channel Financial Economics & Spendings'), findsOneWidget);
      expect(find.text('SUPER ADMIN ONLY'), findsOneWidget);

      // Verify KPI Tiles
      expect(find.text('GROSS REVENUE'), findsOneWidget);
      expect(find.text('PLATFORM SHARE CUT'), findsOneWidget);
      expect(find.text('OUR SPENDINGS (INFRA)'), findsOneWidget);
      expect(find.text('NET PLATFORM MARGIN'), findsOneWidget);

      // Verify Revenue Streams Breakdown
      expect(find.text('Revenue Streams Breakdown'), findsOneWidget);
      expect(find.text('Platform Spendings & Cloud Infra'), findsOneWidget);
    });

    testWidgets('Hides Channel Financial & Unit Economics Card completely when user is Content Moderator', (tester) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      controller.currentAdminEmail.value = 'mod@truthworld.in';
      controller.currentAdminRole.value = 'Content Moderator';
      controller.currentAdminRoles.assignAll(['Content Moderator']);
      controller.channels.assignAll([sampleChannel]);
      controller.selectedChannel.value = sampleChannel;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ChannelQueueTab(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that Channel Financial Economics card is NOT present anywhere
      expect(find.text('Channel Financial Economics & Spendings'), findsNothing);
      expect(find.text('SUPER ADMIN ONLY'), findsNothing);
      expect(find.text('GROSS REVENUE'), findsNothing);
      expect(find.text('NET PLATFORM MARGIN'), findsNothing);
      expect(find.text('Revenue Streams Breakdown'), findsNothing);
    });
  });
}
