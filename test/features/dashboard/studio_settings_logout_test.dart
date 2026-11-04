import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('StudioSettingsController Robustness & Crash Protection Tests', () {
    test('clearSettings resets state and uninitialized _userRef safely without crashing', () {
      final controller = StudioSettingsController();
      controller.clearSettings();

      expect(controller.userData.isEmpty, isTrue);
      expect(controller.isLoadingData.value, isFalse);
    });

    test('toggleNoAdsForMembers and updateField gracefully warn and do not crash when signed out', () async {
      final controller = StudioSettingsController();
      controller.clearSettings();

      // Calling toggle or update when user is null should not throw LateInitializationError
      await controller.toggleNoAdsForMembers(true);
      await controller.updateField('channelHandle', '@test_handle');

      expect(controller.isLoggingOut.value, isFalse);
    });
  });
}
