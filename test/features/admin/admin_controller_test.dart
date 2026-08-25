import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';

class TestAdminController extends AdminController {
  bool refreshAllDataCalled = false;

  @override
  Future<void> refreshAllData() async {
    refreshAllDataCalled = true;
  }
}

void main() {
  group('AdminController Tests', () {
    late TestAdminController controller;

    setUp(() {
      controller = TestAdminController();
    });

    test('selectedTabIndex exists and initializes to 0', () {
      expect(controller.selectedTabIndex.value, equals(0));
    });

    test('selectedTabIndex can be updated', () {
      controller.selectedTabIndex.value = 2;
      expect(controller.selectedTabIndex.value, equals(2));
    });

    test('refreshData calls refreshAllData', () async {
      await controller.refreshData();
      expect(controller.refreshAllDataCalled, isTrue);
    });

    test('rxBypassAds initializes to false and can be updated', () {
      expect(controller.rxBypassAds.value, isFalse);
      controller.rxBypassAds.value = true;
      expect(controller.rxBypassAds.value, isTrue);
    });
  });
}
