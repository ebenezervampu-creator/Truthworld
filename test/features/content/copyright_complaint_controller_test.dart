import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/content/presentation/bindings/copyright_complaint_binding.dart';
import 'package:truthworld/features/content/presentation/controllers/copyright_complaint_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CopyrightComplaintController Tests', () {
    late CopyrightComplaintController controller;

    setUp(() {
      Get.reset();
      controller = CopyrightComplaintController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('Initializes with standard default state', () {
      expect(controller.claimantType.value, equals('Copyright Owner'));
      expect(controller.workType.value, equals('Video'));
      expect(controller.declGoodFaith.value, isFalse);
      expect(controller.declAccuracy.value, isFalse);
      expect(controller.declForwarding.value, isFalse);
      expect(controller.declLiability.value, isFalse);
      expect(controller.isSubmitting.value, isFalse);
      expect(controller.submittedComplaintId.value, isNull);
    });

    test('Text controllers are initialized and tracked', () {
      expect(controller.nameController, isNotNull);
      expect(controller.emailController, isNotNull);
      expect(controller.phoneController, isNotNull);
      expect(controller.addressController, isNotNull);
      expect(controller.workTitleController, isNotNull);
      expect(controller.infringingUrlController, isNotNull);
      expect(controller.signatureController, isNotNull);
    });

    test('State mutators update reactive properties correctly', () {
      controller.setClaimantType('Exclusive Licensee');
      expect(controller.claimantType.value, equals('Exclusive Licensee'));

      controller.setWorkType('Audio / Music / Sound Recording');
      expect(controller.workType.value, equals('Audio / Music / Sound Recording'));

      controller.setDeclGoodFaith(true);
      expect(controller.declGoodFaith.value, isTrue);

      controller.setDeclAccuracy(true);
      expect(controller.declAccuracy.value, isTrue);

      controller.setDeclForwarding(true);
      expect(controller.declForwarding.value, isTrue);

      controller.setDeclLiability(true);
      expect(controller.declLiability.value, isTrue);
    });

    test('CopyrightComplaintBinding registers controller lazily', () {
      Get.reset();
      final binding = CopyrightComplaintBinding();
      binding.dependencies();

      expect(Get.isPrepared<CopyrightComplaintController>(), isTrue);
      final resolvedController = Get.find<CopyrightComplaintController>();
      expect(resolvedController, isNotNull);
      expect(resolvedController.claimantType.value, equals('Copyright Owner'));
    });
  });
}
