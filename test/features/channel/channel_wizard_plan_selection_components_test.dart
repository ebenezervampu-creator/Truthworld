import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_selection_view.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Channel Wizard Plan Selection Components Tests', () {
    testWidgets('Graphics widgets instantiate and render without exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Standard3DGraphic(isDesktop: true),
                  Standard3DGraphic(isDesktop: false),
                  CustomRocket3DGraphic(isDesktop: true),
                  CustomRocket3DGraphic(isDesktop: false),
                  Dashboard3DGraphic(isDesktop: true),
                  Dashboard3DGraphic(isDesktop: false),
                  DashboardGraphic(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Standard3DGraphic), findsNWidgets(2));
      expect(find.byType(CustomRocket3DGraphic), findsNWidgets(2));
      expect(find.byType(Dashboard3DGraphic), findsNWidgets(2));
      expect(find.byType(DashboardGraphic), findsOneWidget);
    });

    testWidgets('StandardPlanCard renders and selects standard plan on tap', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelController());
      controller.selectedPlan.value = '';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 600,
                child: StandardPlanCard(
                  controller: controller,
                  isDarkMode: true,
                  isDesktop: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Standard Channel'), findsOneWidget);
      expect(find.text('Ideal for creators who are starting out'), findsOneWidget);

      await tester.tap(find.byType(StandardPlanCard));
      await tester.pump();

      expect(controller.selectedPlan.value, equals('standard'));
    });

    testWidgets('CustomPlanCard renders pricing tiers and updates selection on tap', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelController());
      controller.selectedPlan.value = '';
      controller.customPricingTier.value = r'$15';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 600,
                child: CustomPlanCard(
                  controller: controller,
                  isDarkMode: true,
                  isDesktop: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Channel'), findsOneWidget);
      expect(find.text(r'$15/mo'), findsOneWidget);

      // Tap card to select custom plan
      await tester.tap(find.byType(CustomPlanCard).first);
      await tester.pump();

      expect(controller.selectedPlan.value, equals('custom'));

      // Tap $30/mo tier chip
      final tier30 = find.text(r'$30/mo');
      if (tier30.evaluate().isNotEmpty) {
        await tester.tap(tier30.first);
        await tester.pump();
        expect(controller.customPricingTier.value, equals(r'$30'));
      }

      // Tap $100/mo tier chip
      final tier100 = find.text(r'$100/mo');
      expect(tier100, findsOneWidget);
      await tester.tap(tier100.first);
      await tester.pump();
      expect(controller.customPricingTier.value, equals(r'$100'));

      // Tap $200/mo tier chip
      final tier200 = find.text(r'$200/mo');
      expect(tier200, findsOneWidget);
      await tester.tap(tier200.first);
      await tester.pump();
      expect(controller.customPricingTier.value, equals(r'$200'));
    });

    testWidgets('CustomTierBreakdownTable displays breakdown for custom plan', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelController());
      controller.selectedPlan.value = 'standard';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 800,
                child: CustomTierBreakdownTable(
                  controller: controller,
                  isDesktop: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Hidden for standard plan
      expect(find.text('Custom Tiers Breakdown & Storage Comparison'), findsNothing);

      // Switch to custom plan
      controller.selectedPlan.value = 'custom';
      await tester.pump();

      expect(find.text('Custom Tiers Breakdown & Storage Comparison'), findsOneWidget);
      expect(find.textContaining('50 GB Cloud Storage'), findsOneWidget);
      expect(find.textContaining('100 GB Cloud Storage'), findsOneWidget);
      expect(find.textContaining('400 GB Storage'), findsOneWidget);
      expect(find.textContaining('800 GB Storage'), findsOneWidget);
    });

    testWidgets('WhyChoosePlanCard renders advantages and bullet points', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelController());
      controller.selectedPlan.value = 'custom';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 800,
                child: WhyChoosePlanCard(
                  controller: controller,
                  isDesktop: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Why Choose Custom Channel?'), findsOneWidget);
      expect(
        find.text('100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats'),
        findsOneWidget,
      );

      controller.selectedPlan.value = 'standard';
      await tester.pump();

      expect(find.text('Why Choose Standard Channel?'), findsOneWidget);
    });

    testWidgets('PlanNoticeCard renders policy notice correctly', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanNoticeCard(isDesktop: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.textContaining('upgrade or switch between Standard and Custom plans'), findsOneWidget);
    });

    testWidgets('PlanHighlightsCard renders feature items and ChecklistColumn', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelController());
      controller.selectedPlan.value = 'custom';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 800,
                child: PlanHighlightsCard(
                  controller: controller,
                  isDesktop: true,
                  isDarkMode: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Channel Plan Highlights'), findsOneWidget);
      expect(find.byType(ChecklistColumn), findsOneWidget);
    });

    testWidgets('PlanFooterAction renders proceed button and feature toggle', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelController());
      controller.selectedPlan.value = '';
      final isShowing = false.obs;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 1200,
                child: PlanFooterAction(
                  controller: controller,
                  isDesktop: true,
                  isShowingAllFeatures: isShowing,
                  onToggleShowAllFeatures: () => isShowing.value = !isShowing.value,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select Standard or Custom Plan'), findsOneWidget);
      expect(find.text('Show More / Compare All Features'), findsOneWidget);

      await tester.tap(find.text('Show More / Compare All Features'));
      await tester.pump();

      expect(isShowing.value, isTrue);
      expect(find.text('Hide All Features'), findsOneWidget);

      // Set custom plan and check button text
      controller.selectedPlan.value = 'custom';
      await tester.pump();

      expect(find.text('Continue with Custom Channel'), findsOneWidget);
    });

    testWidgets('ChannelWizardPlanSelectionView full coordinator renders cleanly', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelWizardPlanSelectionView(
              controller: controller,
              isDesktop: true,
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Select Channel Plan'), findsOneWidget);
      expect(find.byType(StandardPlanCard), findsOneWidget);
      expect(find.byType(CustomPlanCard), findsOneWidget);
      expect(find.byType(WhyChoosePlanCard), findsOneWidget);
      expect(find.byType(PlanNoticeCard), findsOneWidget);
      expect(find.byType(PlanFooterAction), findsOneWidget);
    });
  });
}
