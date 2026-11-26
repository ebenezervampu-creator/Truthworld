import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_wallet.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/dubbing_studio_screen.dart';

import '../../test_helpers/mock_firebase.dart';

class TestDubbingStudioController extends DubbingStudioController {
  bool signOutCalled = false;

  @override
  Future<void> refreshWallet() async {}

  @override
  Future<void> loadUserChannelAndVideos() async {}

  @override
  Future<void> loadSavedProjects() async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    await super.signOut();
  }
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

  group('DubbingStudio Avatar Popup & Sign Out Tests', () {
    testWidgets('Tapping avatar shows popup button with Dubbing Wallet and Sign Out options', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = Get.put<AuthService>(AuthService(), permanent: true);
      authService.setAuthenticatedForTesting(isAuthenticated: true, uid: 'test_creator_uid');
      authService.userDisplayName.value = 'Creator Name';

      final controller = Get.put<DubbingStudioController>(TestDubbingStudioController());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DubbingStudioScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the avatar PopupMenuButton exists
      final popupFinder = find.byType(PopupMenuButton<String>);
      expect(popupFinder, findsOneWidget);

      // Verify avatar displays first letter of user name
      expect(find.text('C'), findsOneWidget);

      // Tap avatar to open popup menu
      await tester.tap(popupFinder);
      await tester.pumpAndSettle();

      // Check popup menu contents
      expect(find.text('Dubbing Wallet'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Tap Sign Out option
      await tester.tap(find.text('Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      expect((controller as TestDubbingStudioController).signOutCalled, isTrue);
    });

    test('DubbingStudioController signOut resets userChannel and wallet', () async {
      final authService = Get.put<AuthService>(AuthService(), permanent: true);
      authService.setAuthenticatedForTesting(isAuthenticated: true, uid: 'test_creator_uid');
      authService.userDisplayName.value = 'Creator Name';

      final controller = Get.put<DubbingStudioController>(TestDubbingStudioController());
      controller.wallet.value = const DubbingWallet(userId: 'test_creator_uid', balanceCredits: 5000);

      await controller.signOut();

      expect(controller.userChannel.value, isNull);
      expect(controller.channelVideos, isEmpty);
      expect(controller.wallet.value?.balanceCredits, equals(0));
    });
  });
}
