import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/channel_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_channel_discount_dialog.dart';

import '../../test_helpers/mock_firebase.dart';

class TestSuperAdminController extends AdminController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void ensureSubscriptionsStarted() {}

  @override
  Future<void> refreshAllData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  group('Super Admin Channel Privileges Tests', () {
    testWidgets('ChannelQueueTab renders Super Admin Channel Privileges Card with discounts, credits, and upload limit', (tester) async {
      final controller = Get.put(TestSuperAdminController());
      controller.isAdmin.value = true;
      controller.currentAdminEmail.value = 'hello@truthworld.in';
      controller.currentAdminRole.value = 'Super Admin';
      controller.currentAdminRoles.assignAll(['Super Admin']);

      final sampleChannel = {
        'id': 'chan_super_vip_1',
        'channelId': 'chan_super_vip_1',
        'name': 'Telugu Science Hub',
        'handle': 'teluguscience',
        'status': 'active',
        'avatarUrl': '',
        'bannerImageUrl': '',
        'dubbingDiscountType': 'free',
        'dubbingDiscountPercent': 100.0,
        'subtitlesDiscountType': '50%',
        'subtitlesDiscountPercent': 50.0,
        'freeDubbingCredits': 25000,
        'customDailyVideoDurationSeconds': 3600, // 60 min
        'hasCustomQuota': true,
      };

      controller.channels.assignAll([sampleChannel]);
      controller.selectedChannel.value = sampleChannel;
      controller.channelFilterTab.value = 'all';

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelQueueTab(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify badges in channel list item
      expect(find.text('Telugu Science Hub'), findsWidgets);
      expect(find.text('100% Free Dubbing'), findsWidgets);
      expect(find.text('+25,000 chars'), findsWidgets);
      expect(find.text('60 min/day'), findsWidgets);

      // Verify Super Admin Privileges inspector card
      expect(find.text('Super Admin Channel Privileges (Discounts & Credits)'), findsOneWidget);
      expect(find.text('SUPER ADMIN ONLY'), findsWidgets);
      expect(find.text('Configure Super Admin Privileges'), findsOneWidget);
      expect(find.text('+10,000 Free Credits'), findsOneWidget);
      expect(find.text('Upload Limit (60m)'), findsOneWidget);
    });

    test('Optimistic state update for grantChannelDubbingCredits and updateChannelSuperAdminPrivileges', () async {
      final controller = Get.put(TestSuperAdminController());
      controller.isAdmin.value = true;
      controller.currentAdminEmail.value = 'hello@truthworld.in';
      controller.currentAdminRole.value = 'Super Admin';
      controller.currentAdminRoles.assignAll(['Super Admin']);

      final sampleChannel = {
        'id': 'chan_test_grant',
        'name': 'News Today',
        'handle': 'newstoday',
        'status': 'active',
        'freeDubbingCredits': 5000,
        'customDailyVideoDurationSeconds': 600,
      };

      controller.channels.assignAll([sampleChannel]);
      controller.selectedChannel.value = sampleChannel;

      // Update privileges optimistically
      await controller.updateChannelSuperAdminPrivileges(
        channelId: 'chan_test_grant',
        dubbingDiscountType: '50%',
        dubbingDiscountPercent: 50.0,
        subtitlesDiscountType: 'free',
        subtitlesDiscountPercent: 100.0,
        dailyUploadDurationMinutes: 120,
        freeCreditsToGrant: 20000,
        reason: 'VIP Onboarding Grant',
      );

      final updated = controller.channels.firstWhere((c) => c['id'] == 'chan_test_grant');
      expect(updated['dubbingDiscountType'], equals('50%'));
      expect(updated['dubbingDiscountPercent'], equals(50.0));
      expect(updated['subtitlesDiscountType'], equals('free'));
      expect(updated['freeDubbingCredits'], equals(25000)); // 5,000 + 20,000
      expect(updated['customDailyVideoDurationSeconds'], equals(7200)); // 120 * 60
      expect(updated['customDailyUploadLimitMinutes'], equals(120));
    });

    testWidgets('showAdminChannelDiscountDialog renders discounts, credits, and upload duration sections', (tester) async {
      final controller = Get.put(TestSuperAdminController());
      controller.isAdmin.value = true;
      controller.currentAdminEmail.value = 'hello@truthworld.in';
      controller.currentAdminRole.value = 'Super Admin';
      controller.currentAdminRoles.assignAll(['Super Admin']);

      final sampleChannel = {
        'id': 'chan_dialog_test',
        'name': 'Global Explainer',
        'handle': 'globalexplainer',
        'dubbingDiscountType': 'none',
        'dubbingDiscountPercent': 0.0,
        'subtitlesDiscountType': 'none',
        'subtitlesDiscountPercent': 0.0,
        'freeDubbingCredits': 10000,
        'customDailyVideoDurationSeconds': 1800,
      };

      controller.channels.assignAll([sampleChannel]);
      controller.selectedChannel.value = sampleChannel;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showAdminChannelDiscountDialog(
                  context: ctx,
                  controller: controller,
                  channel: sampleChannel,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check dialog sections
      expect(find.text('Channel Super Admin Privileges'), findsOneWidget);
      expect(find.text('1. AI Dubbing & Subtitles Discounts'), findsOneWidget);
      expect(find.text('2. Grant Free Dubbing Studio Credits'), findsOneWidget);
      expect(find.text('3. Channel Daily Upload Limit Duration'), findsOneWidget);
      expect(find.text('Apply Super Admin Privileges'), findsOneWidget);
    });
  });
}
