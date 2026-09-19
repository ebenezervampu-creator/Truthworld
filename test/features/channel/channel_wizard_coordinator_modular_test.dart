import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Channel Wizard Coordinator & Modular Components Tests', () {
    test('ChannelWizardViewController initializes and manages tags', () {
      final channelCtrl = Get.put(ChannelController());
      final wizardCtrl = Get.put(ChannelWizardViewController());

      expect(wizardCtrl.channelController, channelCtrl);
      expect(wizardCtrl.tagList, isEmpty);

      // Add tags
      wizardCtrl.addTag('science');
      wizardCtrl.addTag('technology');
      expect(wizardCtrl.tagList.length, 2);
      expect(wizardCtrl.tagList, contains('science'));
      expect(wizardCtrl.tagList, contains('technology'));
      expect(channelCtrl.tags.text, 'science, technology');

      // Add duplicate tag - should not duplicate
      wizardCtrl.addTag('science');
      expect(wizardCtrl.tagList.length, 2);

      // Remove tag
      wizardCtrl.removeTag('science');
      expect(wizardCtrl.tagList.length, 1);
      expect(wizardCtrl.tagList, contains('technology'));
      expect(channelCtrl.tags.text, 'technology');
    });

    test('ChannelWizardViewController enforces 5-tag limit', () {
      Get.put(ChannelController());
      final wizardCtrl = Get.put(ChannelWizardViewController());

      wizardCtrl.addTag('t1');
      wizardCtrl.addTag('t2');
      wizardCtrl.addTag('t3');
      wizardCtrl.addTag('t4');
      wizardCtrl.addTag('t5');
      expect(wizardCtrl.tagList.length, 5);

      // 6th tag should be rejected
      wizardCtrl.addTag('t6');
      expect(wizardCtrl.tagList.length, 5);
    });

    test('ChannelWizardViewController manages social controllers dynamically', () {
      final channelCtrl = Get.put(ChannelController());
      final wizardCtrl = Get.put(ChannelWizardViewController());

      final twitterCtrl = wizardCtrl.getSocialController('twitter');
      expect(twitterCtrl, isNotNull);
      expect(wizardCtrl.socialControllers.containsKey('twitter'), isTrue);

      twitterCtrl.text = 'truthworld_official';
      expect(channelCtrl.socialLinks['twitter'], 'truthworld_official');

      twitterCtrl.text = '';
      expect(channelCtrl.socialLinks.containsKey('twitter'), isFalse);
    });

    testWidgets('ChannelWizardTopHeader renders title and action buttons',
        (tester) async {
      final channelCtrl = Get.put(ChannelController());
      final wizardCtrl = Get.put(ChannelWizardViewController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelWizardTopHeader(
              channelController: channelCtrl,
              wizardController: wizardCtrl,
              isDesktop: true,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Create Channel'), findsOneWidget);
      expect(find.text('Build your brand. Share your story with the world.'),
          findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('ChannelWizardAccordionCard expands and collapses on tap',
        (tester) async {
      final isExpanded = false.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelWizardAccordionCard(
              title: '3. Channel Type',
              isExpanded: isExpanded,
              isDarkMode: true,
              child: const Text('Accordion Content Area'),
            ),
          ),
        ),
      );

      expect(find.text('3. Channel Type'), findsOneWidget);
      expect(find.text('Accordion Content Area'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('3. Channel Type'));
      await tester.pumpAndSettle();

      expect(isExpanded.value, isTrue);
      expect(find.text('Accordion Content Area'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });

    testWidgets('ChannelScreen renders declaratively without setState',
        (tester) async {
      Get.put(ChannelController());

      await tester.pumpWidget(
        const MaterialApp(
          home: ChannelScreen(),
        ),
      );

      expect(find.byType(ChannelScreen), findsOneWidget);
      expect(find.byType(ChannelWizardTopHeader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChannelWizardTopHeader),
          matching: find.text('Create Channel'),
        ),
        findsOneWidget,
      );
    });
  });
}
