import 'package:get/get.dart';
import 'package:truthworld/features/content/presentation/controllers/copyright_complaint_controller.dart';

/// Binding for Copyright Complaint / DMCA Screen.
/// Registers [CopyrightComplaintController] as a lazy dependency.
class CopyrightComplaintBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CopyrightComplaintController>(
      CopyrightComplaintController.new,
    );
  }
}
