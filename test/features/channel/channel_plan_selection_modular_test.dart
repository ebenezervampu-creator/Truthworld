import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_plan_selection_screen.dart';
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

  group('ChannelPlanSelectionController Tests', () {
    test('initializes with null selection and valid animation', () {
      final controller = Get.put(ChannelPlanSelectionController());
      expect(controller.selectedPlan.value, isNull);
      expect(controller.hoveredPlan.value, isNull);
      expect(controller.fadeAnim, isNotNull);
      expect(controller.animController.duration, const Duration(milliseconds: 800));

      controller.selectedPlan.value = ChannelPlanType.standard;
      expect(controller.selectedPlan.value, ChannelPlanType.standard);

      controller.hoveredPlan.value = ChannelPlanType.custom;
      expect(controller.hoveredPlan.value, ChannelPlanType.custom);
    });

    test('proceedToChannelCreation returns early when no plan is selected', () async {
      final controller = Get.put(ChannelPlanSelectionController());
      controller.selectedPlan.value = null;
      await controller.proceedToChannelCreation();
      // Verifies no exception occurs when selectedPlan is null
      expect(controller.selectedPlan.value, isNull);
    });
  });

  group('ChannelPlanCard Widget Tests', () {
    testWidgets('renders Standard Plan card with details and handles tap', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelPlanSelectionController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelPlanCard(
              controller: controller,
              type: ChannelPlanType.standard,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('Standard Plan'), findsOneWidget);
      expect(find.text('YouTube-style Model'), findsOneWidget);
      expect(find.text('70% Creator Ad & Premium Revenue'), findsOneWidget);
      expect(find.text('How Standard Channel Works:'), findsOneWidget);

      await tester.tap(find.text('Standard Plan'));
      await tester.pumpAndSettle();

      expect(controller.selectedPlan.value, ChannelPlanType.standard);
    });

    testWidgets('renders Custom Plan card with details and handles tap', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(ChannelPlanSelectionController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelPlanCard(
              controller: controller,
              type: ChannelPlanType.custom,
              isDark: true,
            ),
          ),
        ),
      );

      expect(find.text('Custom Plan'), findsOneWidget);
      expect(find.text('Maximum Revenue'), findsOneWidget);
      expect(find.text('100% Creator Ad & Premium Revenue'), findsOneWidget);
      expect(find.text('How Custom Channel Works:'), findsOneWidget);

      await tester.tap(find.text('Custom Plan'));
      await tester.pumpAndSettle();

      expect(controller.selectedPlan.value, ChannelPlanType.custom);
    });
  });

  group('ChannelTypeSelectorModal & Controller Tests', () {
    test('ChannelTypeSelectorController reacts to plan selection', () {
      final controller = ChannelTypeSelectorController();
      expect(controller.selectedPlan.value, ChannelPlanType.standard);

      controller.selectPlan(ChannelPlanType.custom);
      expect(controller.selectedPlan.value, ChannelPlanType.custom);
    });

    testWidgets('renders modal and switches selection dynamically', (tester) async {
      ChannelPlanType? resultPlan;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChannelTypeSelectorModal(
              onSelect: (selected) {
                resultPlan = selected;
              },
            ),
          ),
        ),
      );

      expect(find.text('Select Channel Type'), findsOneWidget);
      expect(find.text('Standard Channel'), findsOneWidget);
      expect(find.text('Custom Channel'), findsOneWidget);
      expect(find.text('Standard Channel Benefits'), findsOneWidget);
      expect(find.text('Continue with Standard Channel'), findsOneWidget);

      // Tap Custom Channel
      await tester.tap(find.text('Custom Channel'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Channel Benefits'), findsOneWidget);
      expect(find.text('Continue with Custom Channel'), findsOneWidget);

      // Tap Continue
      await tester.tap(find.text('Continue with Custom Channel'));
      await tester.pumpAndSettle();

      expect(resultPlan, ChannelPlanType.custom);
    });
  });
}
