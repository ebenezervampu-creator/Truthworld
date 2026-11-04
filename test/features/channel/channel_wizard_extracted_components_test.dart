import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/painters/channel_banner_painters.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_plan_badge_item.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_input_fields.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_language_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_links_visibility_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_agreements_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_type_category_cards.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Channel Wizard Extracted Components Tests', () {
    testWidgets('PlanBadgeItem renders text and check icon correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanBadgeItem(text: '70% Revenue Share'),
          ),
        ),
      );

      expect(find.text('70% Revenue Share'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    test('DashedBorderPainter instantiates and configures correctly', () {
      final painter = DashedBorderPainter(
        color: Colors.red,
        strokeWidth: 2.0,
        gap: 5.0,
        dash: 7.0,
        borderRadius: 10.0,
      );

      expect(painter.color, Colors.red);
      expect(painter.strokeWidth, 2.0);
      expect(painter.gap, 5.0);
      expect(painter.dash, 7.0);
      expect(painter.borderRadius, 10.0);
      expect(painter.shouldRepaint(painter), isFalse);
    });

    test('YouTubeBannerSafeAreaPainter and YouTubeDesktopSafeAreaPainter instantiate', () {
      const bannerPainter = YouTubeBannerSafeAreaPainter();
      const desktopPainter = YouTubeDesktopSafeAreaPainter();

      expect(bannerPainter.shouldRepaint(bannerPainter), isFalse);
      expect(desktopPainter.shouldRepaint(desktopPainter), isFalse);
    });

    testWidgets('ChannelWizardFieldLabel renders label and optional asterisk', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChannelWizardFieldLabel('Channel Name', isRequired: true),
                ChannelWizardFieldLabel('Tags', isRequired: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Channel Name'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('ChannelWizardInputField renders text form field with character limit', (tester) async {
      final controller = TextEditingController(text: 'Hello');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelWizardInputField(
              controller: controller,
              hintText: 'Enter text',
              maxLength: 50,
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('5/50'), findsOneWidget);
    });

    testWidgets('ChannelWizardTypeCard renders channel entity types', (tester) async {
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelWizardTypeCard(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('3. Channel Type'), findsOneWidget);
      expect(find.text('Select Channel Type'), findsOneWidget);
    });

    testWidgets('ChannelWizardVisibilityCard renders visibility options', (tester) async {
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelWizardVisibilityCard(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('6. Channel Visibility'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
    });

    testWidgets('ChannelWizardPlanCard renders channel plan options', (tester) async {
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelWizardPlanCard(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('9. Channel Plan'), findsOneWidget);
    });

    testWidgets('ChannelWizardAgreementsCard renders Create Channel button with high-contrast styling', (tester) async {
      final controller = Get.put(ChannelController());
      var submitted = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelWizardAgreementsCard(
              controller: controller,
              isDarkMode: true,
              onSubmit: () {
                submitted = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('10. Agreements'), findsOneWidget);
      expect(find.text('Create Channel'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
      expect(iconWidget.color, Colors.black);

      final textWidget = tester.widget<Text>(find.text('Create Channel'));
      expect(textWidget.style?.color, Colors.black);

      await tester.tap(find.text('Create Channel'));
      await tester.pump();
      expect(submitted, isTrue);
    });

    testWidgets('ChannelWizardLanguageCard renders language card and selects any language directly', (tester) async {
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChannelWizardLanguageCard(
                controller: controller,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('8. Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // Open language picker modal
      final dropdownIcon = find.byIcon(Icons.keyboard_arrow_down);
      expect(dropdownIcon, findsOneWidget);
      await tester.tap(dropdownIcon);
      await tester.pumpAndSettle();

      // Mandarin Chinese should be visible in the list without "Invite Only" lock
      final mandarinChinese = find.text('Mandarin Chinese');
      expect(mandarinChinese, findsOneWidget);
      expect(find.text('Invite Only'), findsNothing);

      // Tap Mandarin Chinese to select it directly (no invite-only dialog)
      await tester.tap(mandarinChinese);
      await tester.pumpAndSettle();

      // Verify controller language updated to 'zh' and language card reflects selection
      expect(controller.language.value, 'zh');
      expect(find.text('Mandarin Chinese (中文)'), findsOneWidget);
      expect(find.text('Mandarin Chinese is Invite-Only'), findsNothing);
    });
  });
}

