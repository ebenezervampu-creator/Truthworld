import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_pricing_calculator_card.dart';

import '../../test_helpers/mock_firebase.dart';

class TestDubbingStudioController extends DubbingStudioController {
  @override
  Future<void> refreshWallet() async {}

  @override
  Future<void> loadUserChannelAndVideos() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('DubbingPricingCalculatorCard Layout & Overflow Tests', () {
    testWidgets('Renders without overflow on standard narrow mobile width (360px)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put<DubbingStudioController>(TestDubbingStudioController());
      controller.mode.value = DubbingMode.dubbing;
      controller.publishToTruthworld.value = false;
      controller.estimatedCharacterCount.value = 5000;
      controller.targetLanguages.assignAll(['es', 'fr', 'de']);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DubbingPricingCalculatorCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DubbingPricingCalculatorCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders without overflow in constrained card width (w <= 142.5px)', (tester) async {
      final controller = Get.put<DubbingStudioController>(TestDubbingStudioController());
      controller.mode.value = DubbingMode.dubbing;
      controller.publishToTruthworld.value = false;
      controller.estimatedCharacterCount.value = 8500;
      controller.targetLanguages.assignAll(['es', 'fr']);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: DubbingPricingCalculatorCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DubbingPricingCalculatorCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
