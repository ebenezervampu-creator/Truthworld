import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart';
import '../../pages/page_test_harness.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('DownloadsPage Clean Layout Tests', () {
    testWidgets('DownloadsPage renders with SafeArea and without AI auto_awesome icon',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const DownloadsPage(),
        onBeforePump: () {
          Get.put<DownloadsController>(DownloadsController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DownloadsPage), findsOneWidget);

      // Verify SafeArea is present in DownloadsPage
      expect(find.descendant(of: find.byType(DownloadsPage), matching: find.byType(SafeArea)), findsWidgets);

      // Verify no auto_awesome AI icon exists
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // Verify 'Downloads' title exists
      expect(find.text('Downloads'), findsOneWidget);
    });
  });
}
