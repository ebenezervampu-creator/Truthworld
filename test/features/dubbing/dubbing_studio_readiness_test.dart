import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_wallet.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_projects_hub.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_wallet_modal.dart';

import '../../test_helpers/mock_firebase.dart';

class _TestDubbingStudioController extends DubbingStudioController {
  @override
  Future<void> refreshWallet() async {}

  @override
  Future<void> loadUserChannelAndVideos() async {}

  @override
  Future<void> loadSavedProjects() async {}
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

  group('Dubbing Studio Readiness Tests', () {
    testWidgets('DubbingWalletModal shows USD tiers (\$5-\$100) and zero character-pack or trial copy', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = Get.put<DubbingStudioController>(_TestDubbingStudioController());
      ctrl.wallet.value = const DubbingWallet(userId: 'u1', balanceUsd: 12.50);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DubbingWalletModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$12.50'), findsOneWidget);
      expect(find.text('\$5'), findsOneWidget);
      expect(find.text('\$10'), findsOneWidget);
      expect(find.text('\$25'), findsOneWidget);
      expect(find.text('\$50'), findsOneWidget);
      expect(find.text('\$100'), findsOneWidget);
      expect(find.textContaining('1,000 Free Characters'), findsNothing);
      expect(find.textContaining('k chars'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DubbingProjectsHub removes Paste URL and enforces 1 GB / 250 MB upload copy', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = Get.put<DubbingStudioController>(_TestDubbingStudioController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DubbingProjectsHub()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paste URL'), findsNothing);
      expect(find.textContaining('1 GB video / 250 MB audio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('DubbingStudioController calculates USD fallback quote for uploaded media without channel', () {
      final ctrl = Get.put<DubbingStudioController>(_TestDubbingStudioController());
      ctrl.estimatedDurationSeconds.value = 120;
      ctrl.estimatedCharacterCount.value = 2000;
      ctrl.targetLanguages.assignAll(['te', 'hi']);
      ctrl.mode.value = DubbingMode.dubbing;

      expect(ctrl.calculatedCostUsd, closeTo(1.20, 0.001));

      ctrl.mode.value = DubbingMode.subtitlesOnly;
      expect(ctrl.calculatedCostUsd, closeTo(0.40, 0.001));
    });
  });
}
