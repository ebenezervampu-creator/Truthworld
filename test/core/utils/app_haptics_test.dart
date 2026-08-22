import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  group('AppHaptics', () {
    test('methods complete without throw when no controller is registered', () async {
      await expectLater(AppHaptics.lightImpact(), completes);
      await expectLater(AppHaptics.mediumImpact(), completes);
      await expectLater(AppHaptics.heavyImpact(), completes);
      await expectLater(AppHaptics.selectionClick(), completes);
      await expectLater(AppHaptics.vibrate(), completes);
    });
  });
}
