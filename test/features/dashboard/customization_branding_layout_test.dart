import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Channel Customization Branding Tab - Avatar Before Banner & Desktop Sizing', () {
    test('CustomizationController removeAvatar and removeBanner clear reactive state and set flags', () {
      final controller = CustomizationController(
        channelId: 'channel_test_1',
        ownerId: 'owner_test_1',
      );

      controller.avatarUrl.value = 'https://example.com/avatar.jpg';
      controller.bannerUrl.value = 'https://example.com/banner.jpg';
      controller.avatarStatus.value = 'APPROVED';
      controller.bannerStatus.value = 'APPROVED';

      expect(controller.avatarUrl.value, isNotEmpty);
      expect(controller.bannerUrl.value, isNotEmpty);
      expect(controller.hasRemovedAvatar.value, isFalse);
      expect(controller.hasRemovedBanner.value, isFalse);

      // Remove avatar
      controller.removeAvatar();
      expect(controller.avatarUrl.value, isEmpty);
      expect(controller.newAvatarBytes.value, isNull);
      expect(controller.hasRemovedAvatar.value, isTrue);

      // Remove banner
      controller.removeBanner();
      expect(controller.bannerUrl.value, isEmpty);
      expect(controller.newBannerBytes.value, isNull);
      expect(controller.hasRemovedBanner.value, isTrue);

      controller.onClose();
    });

    testWidgets(
      'ChannelCustomizationPage displays Channel Avatar BEFORE Channel Banner and uses Industry Standard Size on Desktop',
      (tester) async {
        // Desktop window: 1920x1080 dp
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const GetMaterialApp(
            home: ChannelCustomizationPage(
              channelId: 'desktop_test_ch',
              ownerId: 'desktop_test_owner',
              initialTabIndex: 0,
            ),
          ),
        );
        await tester.pump();

        // 1. Verify Avatar section and Banner section exist
        final avatarTitleFinder = find.text('Channel Avatar');
        final bannerTitleFinder = find.text('Channel Banner');

        expect(avatarTitleFinder, findsOneWidget);
        expect(bannerTitleFinder, findsOneWidget);

        // 2. Verify Channel Avatar is rendered BEFORE Channel Banner vertically
        final avatarTop = tester.getTopLeft(avatarTitleFinder).dy;
        final bannerTop = tester.getTopLeft(bannerTitleFinder).dy;
        expect(
          avatarTop,
          lessThan(bannerTop),
          reason: 'Channel Avatar must appear before Channel Banner in the view',
        );

        // 3. Verify Industry Standard Size on Desktop
        // Find ConstrainedBox widgets enforcing the 400px maxWidth on desktop banner
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(ConstrainedBox),
          ),
        );

        final bannerConstraint = constrainedBoxes.firstWhere(
          (box) => box.constraints.maxWidth == 400.0,
        );
        expect(bannerConstraint.constraints.maxWidth, 400.0);
        expect(bannerConstraint.constraints.minWidth, 300.0);

        // 4. Verify AspectRatio 16 / 9 is used within the constrained box
        final aspectRatios = tester.widgetList<AspectRatio>(
          find.descendant(
            of: find.byWidget(bannerConstraint),
            matching: find.byType(AspectRatio),
          ),
        );
        expect(aspectRatios.first.aspectRatio, closeTo(16 / 9, 0.01));

        // 5. Verify action buttons
        expect(find.text('Upload'), findsNWidgets(2)); // Avatar upload and Banner upload buttons
      },
    );
  });
}
