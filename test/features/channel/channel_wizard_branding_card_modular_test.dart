import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_branding_card.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Channel Wizard Branding Card Modular Tests', () {
    testWidgets('ChannelBrandingModerationBadge renders statuses correctly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChannelBrandingModerationBadge(
                  status: 'PENDING',
                  reason: '',
                ),
                ChannelBrandingModerationBadge(
                  status: 'APPROVED',
                  reason: '',
                ),
                ChannelBrandingModerationBadge(
                  status: 'REJECTED',
                  reason: 'Too blurry',
                ),
                ChannelBrandingModerationBadge(
                  status: 'FLAGGED',
                  reason: 'Copyright notice',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Verifying...'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Rejected: Too blurry'), findsOneWidget);
      expect(find.text('Flagged: Copyright notice'), findsOneWidget);
    });

    testWidgets('ChannelBrandingAvatarDropzone renders empty state and recommendations',
        (tester) async {
      final channelCtrl = Get.put(ChannelController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelBrandingAvatarDropzone(
              controller: channelCtrl,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Drag & drop avatar here\nor click to upload'),
          findsOneWidget);
      expect(find.text('Recommended 800 x 800 px (Max 2MB)'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('ChannelBrandingBannerDropzone renders upload guidelines',
        (tester) async {
      final channelCtrl = Get.put(ChannelController());
      final previewMode = 0.obs;
      final showSafeArea = false.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelBrandingBannerDropzone(
              controller: channelCtrl,
              isDarkMode: true,
              bannerPreviewMode: previewMode,
              showBannerSafeArea: showSafeArea,
            ),
          ),
        ),
      );

      expect(find.text('Upload Channel Banner'), findsOneWidget);
      expect(find.text('Recommended: 2560 x 1440 px (16:9 canvas, Max 6MB)'),
          findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('ChannelWizardBrandingCard coordinator renders both banner and avatar sections',
        (tester) async {
      final channelCtrl = Get.put(ChannelController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelWizardBrandingCard(
              controller: channelCtrl,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('1. Channel Branding'), findsOneWidget);
      expect(find.text('Channel Banner'), findsOneWidget);
      expect(find.text('Channel Avatar'), findsOneWidget);
      expect(find.byType(ChannelBrandingBannerDropzone), findsOneWidget);
      expect(find.byType(ChannelBrandingAvatarDropzone), findsOneWidget);
    });
  });
}
