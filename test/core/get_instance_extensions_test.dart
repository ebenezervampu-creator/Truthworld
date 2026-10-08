import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/get_instance_extensions.dart';

class _TestController extends GetxController {
  bool wasInitialized = false;
  @override
  void onInit() {
    super.onInit();
    wasInitialized = true;
  }
}

void main() {
  setUp(Get.reset);

  test('isInstantiated and findIfInstantiated return false/null before lazy resolution', () {
    expect(Get.isInstantiated<_TestController>(), isFalse);
    expect(Get.findIfInstantiated<_TestController>(), isNull);

    // Register lazily
    Get.lazyPut<_TestController>(_TestController.new);

    // Should still NOT be instantiated
    expect(Get.isInstantiated<_TestController>(), isFalse);
    expect(Get.findIfInstantiated<_TestController>(), isNull);

    // Force find
    final instance = Get.find<_TestController>();
    expect(instance.wasInitialized, isTrue);

    // Now it IS instantiated
    expect(Get.isInstantiated<_TestController>(), isTrue);
    expect(Get.findIfInstantiated<_TestController>(), equals(instance));
  });

  test('findIfInstantiated works with eager put', () {
    final direct = Get.put(_TestController());
    expect(Get.isInstantiated<_TestController>(), isTrue);
    expect(Get.findIfInstantiated<_TestController>(), equals(direct));
  });
}
