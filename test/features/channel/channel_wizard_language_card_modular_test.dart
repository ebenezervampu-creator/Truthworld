import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_language_card.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('ChannelWizardLanguageCard Modular Tests', () {
    test('worldLanguagesDescending contains 104 ranked languages', () {
      expect(ChannelWizardLanguageCard.worldLanguagesDescending.length, 104);
      expect(ChannelWizardLanguageCard.worldLanguagesDescending.first['code'], 'en');
      expect(ChannelWizardLanguageCard.worldLanguagesDescending.first['name'], 'English');
      expect(ChannelWizardLanguageCard.worldLanguagesDescending.first['rank'], 1);
    });

    testWidgets('ChannelWizardLanguageCard renders header and content with contentOnly=false', (tester) async {
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelWizardLanguageCard(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('8. Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('ChannelWizardLanguageCard renders without card header when contentOnly=true', (tester) async {
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelWizardLanguageCard(
              controller: controller,
              isDarkMode: true,
              contentOnly: true,
            ),
          ),
        ),
      );

      expect(find.text('8. Language'), findsNothing);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('ChannelLanguageContent can be tapped to open language picker and view languages', (tester) async {
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelLanguageContent(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('English'), findsOneWidget);
      final pickerTrigger = find.byIcon(Icons.keyboard_arrow_down);
      await tester.tap(pickerTrigger);
      await tester.pumpAndSettle();

      expect(find.text('Channel Language'), findsOneWidget);
      expect(find.text('Mandarin Chinese'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);
    });
  });
}
