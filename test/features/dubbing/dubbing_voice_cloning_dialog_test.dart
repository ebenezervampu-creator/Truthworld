import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_voice_cloning_dialog.dart';

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

  group('DubbingVoiceCloningDialog Build & Assertion Tests', () {
    testWidgets('Builds cleanly without Material shape/borderRadius assertion failure', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Get.put<DubbingStudioController>(TestDubbingStudioController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DubbingVoiceCloningDialog(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DubbingVoiceCloningDialog), findsOneWidget);
      expect(find.text('AUDIO SEPARATION & MIXING'), findsOneWidget);
      expect(find.text('Isolate Vocals (Remove Background Noise)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
