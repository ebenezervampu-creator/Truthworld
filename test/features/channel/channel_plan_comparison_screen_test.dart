import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_comparison/plan_comparison_barrel.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Channel Plan Comparison Data & Model Tests', () {
    test('contains comprehensive comparison sections', () {
      expect(ChannelPlanComparisonData.sections.length, 4);

      final sectionTitles =
          ChannelPlanComparisonData.sections.map((s) => s.title).toList();
      expect(sectionTitles, contains('Revenue Share & Monetization'));
      expect(sectionTitles, contains('Upload Limits & Video Specs'));
      expect(sectionTitles, contains('Hosting & Infrastructure Costs'));
      expect(sectionTitles, contains('AI Verification & Creator Perks'));
    });

    test('validates comparison feature contents for standard and custom', () {
      final revSection = ChannelPlanComparisonData.sections.first;
      final adFeature = revSection.features
          .firstWhere((f) => f.title == 'Ad Revenue Share');
      expect(adFeature.standardValue, contains('70%'));
      expect(adFeature.customValue, contains('100%'));
      expect(adFeature.customWins, isTrue);

      final uploadSection = ChannelPlanComparisonData.sections[1];
      final dailyUpload = uploadSection.features
          .firstWhere((f) => f.title == 'Daily Upload Allowance');
      expect(dailyUpload.standardValue, contains('10 Minutes'));
      expect(dailyUpload.customValue, contains('Unlimited'));

      final hostingSection = ChannelPlanComparisonData.sections[2];
      final monthlyCost = hostingSection.features
          .firstWhere((f) => f.title == 'Monthly Subscription Cost');
      expect(monthlyCost.standardValue, contains(r'$0'));
      expect(monthlyCost.customValue, contains(r'$15'));
      expect(monthlyCost.standardWins, isTrue);
    });

    test('ChannelPlanComparisonController handles selection reactive updates', () {
      final controller =
          Get.put(ChannelPlanComparisonController(initialPlan: 'standard'));
      expect(controller.selectedPlan.value, 'standard');

      controller.selectPlan('custom');
      expect(controller.selectedPlan.value, 'custom');

      controller.selectPlan('standard');
      expect(controller.selectedPlan.value, 'standard');
    });
  });

  group('ChannelPlanComparisonScreen Widget Tests', () {
    testWidgets('renders screen with header, cards, and comparison matrix', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ChannelPlanComparisonScreen(initialPlan: 'standard'),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('Compare Channel Plans'), findsOneWidget);
      expect(find.text('Standard vs Custom Channel'), findsOneWidget);
      expect(find.text('Detailed Feature Comparison'), findsOneWidget);
      expect(find.text('Which Channel Type is Right for You?'), findsOneWidget);

      // Check standard and custom overview cards
      expect(find.text('Standard Channel'), findsWidgets);
      expect(find.text('Custom Channel'), findsWidgets);
      expect(find.text('100% FREE FOREVER'), findsOneWidget);
      expect(find.text('MAX REVENUE • 100% KEEP'), findsOneWidget);

      // Check feature text from matrix
      expect(find.text('Ad Revenue Share'), findsOneWidget);
      expect(find.text('Daily Upload Allowance'), findsOneWidget);
      expect(find.text('Cloud Storage'), findsOneWidget);

      // Tap on Custom card button
      final chooseCustomBtn = find.text('Choose Custom Channel');
      expect(chooseCustomBtn, findsOneWidget);
      await tester.tap(chooseCustomBtn);
      await tester.pumpAndSettle();

      // Verify custom is now selected in the bottom action bar
      expect(find.text('Continue with Custom'), findsOneWidget);
    });
  });
}
