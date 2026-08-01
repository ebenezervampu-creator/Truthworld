import 'package:get/get.dart';
import 'package:truthworld/features/library/presentation/controllers/library_controller.dart';

class LibraryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(LibraryController.new, fenix: true);
  }
}
