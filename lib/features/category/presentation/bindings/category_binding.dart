import 'package:get/get.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';

/// Binding for the Category browsing feature.
class CategoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(CategoryController.new);
  }
}
